// ─────────────────────────────────────────────
// API 클라이언트
// VITE_USE_MOCK=true 이면 목업 데이터를 돌려주고,
// false 이면 FastAPI 백엔드(VITE_API_BASE_URL)를 호출합니다.
// 화면 컴포넌트는 이 파일의 함수만 사용하므로 백엔드 연동 시 여기만 바꾸면 됩니다.
// ─────────────────────────────────────────────
import { PLACES, scoreAnswers } from '../mock/tourist.js';
import { OWNER_QA } from '../mock/owner.js';
import { KM_PER_PX } from '../mock/jejuGeo.js';

const USE_MOCK = (import.meta.env.VITE_USE_MOCK ?? 'true') !== 'false';
const BASE = import.meta.env.VITE_API_BASE_URL || '/api';

const wait = (ms) => new Promise((r) => setTimeout(r, ms));

async function http(path, body) {
  const res = await fetch(`${BASE}${path}`, {
    method: body ? 'POST' : 'GET',
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) throw new Error(`서버 응답 오류 (${res.status})`);
  return res.json();
}

/** 성향 분석 Agent: POST /tourist/profile */
export async function analyzeProfile(answers, extra) {
  if (!USE_MOCK) return http('/tourist/profile', { answers, ...extra });
  await wait(500);
  return { ...scoreAnswers(answers), ...extra };
}

const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);

/** 코스 플래너 Agent: POST /tourist/course */
export async function planCourse({ profile, origin, weather, startTime = '15:00', removeCount = 0, seafood = false }) {
  if (!USE_MOCK) return http('/tourist/course', { profile, origin, weather, startTime });
  await wait(700);
  const rain = weather === 'rain';
  const near = [...PLACES].sort((a, b) => dist(a, origin) - dist(b, origin));
  const pick = (kinds, used, pred = () => true) =>
    near.find((p) => kinds.includes(p.kind) && !used.has(p.id) && pred(p));

  const order = rain ? [['cafe'], ['indoor'], ['indoor', 'cafe'], ['food']] : [['cafe'], ['spot'], ['sunset'], ['food']];
  const used = new Set();
  const stops = [];
  for (const kinds of order) {
    const pred = kinds.includes('food') && seafood ? (p) => p.seafood : rain ? (p) => p.indoor : () => true;
    const p = pick(kinds, used, pred) || pick(kinds, used);
    if (p) { used.add(p.id); stops.push(p); }
  }
  const trimmed = stops.slice(0, Math.max(2, stops.length - removeCount));

  // 시간표 생성 (장소 체류시간 + 이동시간)
  let [h, m] = startTime.split(':').map(Number);
  let t = h * 60 + m;
  const fmt = (x) => `${String(Math.floor(x / 60)).padStart(2, '0')}:${String(x % 60).padStart(2, '0')}`;
  return {
    weather,
    stops: trimmed.map((p, i) => {
      // 직선거리(km) × 1.3(도로 보정) ÷ 평균 35km/h + 주차·도보 4분
      const km = i === 0 ? 0 : dist(p, trimmed[i - 1]) * KM_PER_PX * 1.3;
      const move = i === 0 ? 0 : Math.max(5, Math.round((km / 35) * 60 + 4));
      t += move;
      const at = fmt(t);
      t += p.stay;
      return { ...p, at, move };
    }),
  };
}

/** 코스 수정 대화: POST /tourist/course/chat */
export async function chatCourse(message) {
  if (!USE_MOCK) return http('/tourist/course/chat', { message });
  await wait(600);
  if (/해산물|회|바다 음식/.test(message)) return { reply: '저녁을 해산물 식당으로 바꿨어요. 최근 외식업 메뉴 매출에서 해산물 비중이 높은 곳 위주로 골랐어요.', patch: { seafood: true } };
  if (/줄여|빼|하나 빼|1곳/.test(message)) return { reply: '마지막 장소 하나를 뺐어요. 이동 시간이 줄어 여유가 생겼어요.', patch: { removeCount: 1 } };
  if (/비|실내/.test(message)) return { reply: '실내 위주 코스로 바꿨어요.', patch: { weather: 'rain' } };
  return { reply: '시연 화면에서는 "저녁은 해산물로 바꿔줘", "1곳 줄여줘", "실내로 바꿔줘"를 알아들어요. 백엔드를 연결하면 Claude 기반 코스 플래너 Agent가 답합니다.', patch: null };
}

/** 방문 후 평가: POST /tourist/review → 실시간 파이프라인 이벤트 */
export async function submitReviews(reviews) {
  if (!USE_MOCK) return http('/tourist/reviews', { reviews });
  await wait(600);
  return { ok: true, accepted: reviews.length };
}

/** 상권 Agent 질의: POST /owner/ask */
export async function askOwnerAgent(question) {
  if (!USE_MOCK) return http('/owner/ask', { question });
  await wait(700);
  return {
    answer:
      OWNER_QA[question] ||
      '시연 화면에서는 아래 예시 질문에 답해요. 백엔드를 연결하면 상권 분석 Agent가 SQL로 지표를 계산한 뒤 근거와 함께 답합니다.',
  };
}

/** 사장님 개선 조치 등록: POST /owner/actions */
export async function registerAction(action) {
  if (!USE_MOCK) return http('/owner/actions', action);
  await wait(400);
  return { ok: true };
}

export const isMock = USE_MOCK;
