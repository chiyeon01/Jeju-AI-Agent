// ─────────────────────────────────────────────
// API 클라이언트 — 화면은 이 파일의 함수만 사용합니다.
// config.useMock=true 이면 목업 응답, false 이면 백엔드(config.apiBaseUrl)를 호출합니다.
// 엔드포인트·응답 형식은 「제주잇다 BE 연동 명세」 PDF 와 같습니다.
// ─────────────────────────────────────────────
import { config } from '../config.js';
import { PLACES, REGIONS, WEATHER, scoreAnswers } from '../mock/tourist.js';
import { DEMO_ACCOUNTS, DEMO_PASSWORD } from '../mock/auth.js';
import { STORE, SCORE_TREND, INDICATORS, WEEKLY_REPORT, REVIEW_TOPICS, RECENT_REVIEWS, OWNER_QA } from '../mock/owner.js';
import {
  REGION_HEALTH, EVENT_SAMPLES, SOURCES, DERIVED, QUALITY, ACCOUNTS, ACCESS_LOG, MASKING, BACKUPS, RETENTION,
} from '../mock/console.js';

export const isMock = config.useMock;
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

// ── 토큰 저장 ───────────────────────────────
const KEY = 'itda-auth';
export function loadSession() {
  try { return JSON.parse(localStorage.getItem(KEY)) || null; } catch { return null; }
}
function saveSession(s) {
  try { s ? localStorage.setItem(KEY, JSON.stringify(s)) : localStorage.removeItem(KEY); } catch { /* 저장 불가 환경 */ }
}

/** 로그인이 풀렸을 때(리프레시 실패) 호출할 함수. AuthProvider 가 등록합니다. */
let onUnauthorized = () => {};
export function setUnauthorizedHandler(fn) { onUnauthorized = fn; }

export class ApiError extends Error {
  constructor(status, code, message) { super(message); this.status = status; this.code = code; }
}

async function request(method, path, body, retry = true) {
  const s = loadSession();
  const res = await fetch(`${config.apiBaseUrl}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(s?.accessToken ? { Authorization: `Bearer ${s.accessToken}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (res.status === 401 && retry && s?.refreshToken && !path.startsWith('/auth/')) {
    // 액세스 토큰 만료 → 리프레시 후 한 번 더 시도
    const r = await fetch(`${config.apiBaseUrl}/auth/refresh`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ refreshToken: s.refreshToken }),
    });
    if (r.ok) {
      const t = await r.json();
      saveSession({ ...s, ...t });
      return request(method, path, body, false);
    }
    saveSession(null);
    onUnauthorized();
  }
  if (!res.ok) {
    let err = {};
    try { err = (await res.json()).error || {}; } catch { /* 본문 없음 */ }
    throw new ApiError(res.status, err.code || 'HTTP_ERROR', err.message || `서버 응답 오류 (${res.status})`);
  }
  return res.status === 204 ? null : res.json();
}
const get = (p) => request('GET', p);
const post = (p, b) => request('POST', p, b ?? {});
const patch = (p, b) => request('PATCH', p, b ?? {});

// ── 인증 ───────────────────────────────────
/** POST /auth/login → { accessToken, refreshToken, user } */
export async function login(email, password) {
  let session;
  if (!isMock) {
    session = await post('/auth/login', { email, password });
  } else {
    await wait(400);
    const u = DEMO_ACCOUNTS.find((a) => a.email === email.trim().toLowerCase());
    if (!u || password !== DEMO_PASSWORD) throw new ApiError(401, 'INVALID_CREDENTIALS', '이메일 또는 비밀번호가 맞지 않아요.');
    session = { accessToken: 'mock-access', refreshToken: 'mock-refresh', user: u };
  }
  saveSession(session);
  return session.user;
}

/** POST /auth/signup → { user } (상권 주인은 관리자 승인 전까지 status=PENDING) */
export async function signup(form) {
  if (!isMock) return (await post('/auth/signup', form)).user;
  await wait(500);
  if (DEMO_ACCOUNTS.some((a) => a.email === form.email)) throw new ApiError(409, 'EMAIL_TAKEN', '이미 가입된 이메일이에요.');
  return { id: 'new', email: form.email, name: form.name, role: form.role, status: form.role === 'MERCHANT' ? 'PENDING' : 'ACTIVE' };
}

/** GET /auth/me */
export async function fetchMe() {
  if (!isMock) return get('/auth/me');
  return loadSession()?.user ?? null;
}

/** POST /auth/logout */
export async function logout() {
  const s = loadSession();
  if (!isMock && s?.refreshToken) { try { await post('/auth/logout', { refreshToken: s.refreshToken }); } catch { /* 무시 */ } }
  saveSession(null);
}

// ── 관광객 ─────────────────────────────────
/** GET /regions */
export async function getRegions() {
  if (!isMock) return get('/regions');
  return REGIONS;
}

/** 위경도에서 가장 가까운 지역. 실제 서비스는 GET /regions/nearest?lat=&lon= */
export async function nearestRegion(lat, lon) {
  if (!isMock) return get(`/regions/nearest?lat=${lat}&lon=${lon}`);
  return [...REGIONS].sort((a, b) => km(a, { lat, lon }) - km(b, { lat, lon }))[0];
}

/** POST /tourist/profile — 성향 분석 Agent */
export async function analyzeProfile(answers, extra) {
  if (!isMock) return post('/tourist/profile', { answers, ...extra });
  await wait(500);
  return { ...scoreAnswers(answers), ...extra };
}

function km(a, b) {
  const R = 6371, rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad, dLon = (b.lon - a.lon) * rad;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

/** POST /tourist/course — 코스 플래너 Agent */
export async function planCourse({ profile, origin, weather, startTime = '15:00', removeCount = 0, seafood = false }) {
  if (!isMock) {
    return post('/tourist/course', { profile, regionId: origin.id, startTime, hours: profile.hours, weather, options: { seafood, removeCount } });
  }
  await wait(600);
  const rain = weather === 'rain';
  const near = [...PLACES].sort((a, b) => km(a, origin) - km(b, origin));
  const pick = (kinds, used, pred = () => true) => near.find((p) => kinds.includes(p.kind) && !used.has(p.id) && pred(p));
  const order = rain ? [['cafe'], ['indoor'], ['indoor', 'cafe'], ['food']] : [['cafe'], ['spot'], ['sunset'], ['food']];
  const used = new Set();
  const stops = [];
  for (const kinds of order) {
    const pred = kinds.includes('food') && seafood ? (p) => p.seafood : rain ? (p) => p.indoor : () => true;
    const p = pick(kinds, used, pred) || pick(kinds, used);
    if (p) { used.add(p.id); stops.push(p); }
  }
  const trimmed = stops.slice(0, Math.max(2, stops.length - removeCount));
  let [h, m] = startTime.split(':').map(Number);
  let t = h * 60 + m;
  const fmt = (x) => `${String(Math.floor(x / 60)).padStart(2, '0')}:${String(x % 60).padStart(2, '0')}`;
  return {
    weather: { code: weather, ...WEATHER[weather] },
    stops: trimmed.map((p, i) => {
      // 직선거리(km) × 1.3(도로 보정) ÷ 평균 35km/h + 주차·도보 4분
      const move = i === 0 ? 0 : Math.max(5, Math.round((km(p, trimmed[i - 1]) * 1.3 / 35) * 60 + 4));
      t += move;
      const at = fmt(t);
      t += p.stay;
      return { ...p, at, move };
    }),
  };
}

/** POST /tourist/course/chat */
export async function chatCourse(message) {
  if (!isMock) return post('/tourist/course/chat', { message });
  await wait(500);
  if (/해산물|회|바다 음식/.test(message)) return { reply: '저녁을 해산물 식당으로 바꿨어요.', patch: { seafood: true } };
  if (/줄여|빼|1곳/.test(message)) return { reply: '마지막 장소 하나를 뺐어요.', patch: { removeCount: 1 } };
  if (/비|실내/.test(message)) return { reply: '실내 위주 코스로 바꿨어요.', patch: { weather: 'rain' } };
  return { reply: '시연 화면에서는 "해산물로 바꿔줘", "1곳 줄여줘", "실내로 바꿔줘"를 알아들어요.', patch: null };
}

/** POST /tourist/reviews */
export async function submitReviews(reviews) {
  if (!isMock) return post('/tourist/reviews', { reviews });
  await wait(500);
  return { accepted: reviews.length };
}

// ── 상권 주인 ──────────────────────────────
/** 대시보드에 필요한 값을 한 번에 가져옵니다 (백엔드에서는 엔드포인트 6개) */
export async function getOwnerDashboard() {
  if (!isMock) {
    const [store, score, trend, indicators, report, topics, reviews] = await Promise.all([
      get('/owner/store'), get('/owner/score'), get('/owner/score/trend?weeks=12'), get('/owner/indicators'),
      get('/owner/report/weekly'), get('/owner/reviews/topics'), get('/owner/reviews?limit=4'),
    ]);
    return { store, score, trend, indicators, report, topics, reviews };
  }
  await wait(400);
  return {
    store: { id: STORE.id, name: STORE.name, category: STORE.category, dong: STORE.dong },
    score: { score: STORE.score, delta: STORE.scoreDelta, percentile: STORE.percentile, peers: STORE.peers, basis: STORE.basis },
    trend: { values: SCORE_TREND, labels: SCORE_TREND.map((_, i) => (i === SCORE_TREND.length - 1 ? '이번 주' : `${SCORE_TREND.length - 1 - i}주 전`)) },
    indicators: INDICATORS,
    report: WEEKLY_REPORT,
    topics: REVIEW_TOPICS,
    reviews: RECENT_REVIEWS,
  };
}

export const OWNER_SUGGESTED_QUESTIONS = Object.keys(OWNER_QA);

/** POST /owner/ask — 상권 분석 Agent */
export async function askOwnerAgent(question) {
  if (!isMock) return post('/owner/ask', { question });
  await wait(600);
  return { answer: OWNER_QA[question] || '시연 화면에서는 예시 질문에만 답해요. 백엔드를 연결하면 상권 분석 Agent가 근거와 함께 답합니다.' };
}

/** POST /owner/actions */
export async function registerAction(action) {
  if (!isMock) return post('/owner/actions', action);
  await wait(300);
  return { id: Date.now(), ...action, status: 'MEASURING' };
}

// ── 관리자 (Main PC 콘솔) ───────────────────
/** GET /admin/overview + GET /admin/regions/health */
export async function getAdminOverview() {
  if (!isMock) {
    const [overview, health] = await Promise.all([get('/admin/overview'), get('/admin/regions/health')]);
    return { overview, health };
  }
  await wait(300);
  return {
    overview: { visits: 9770, reviews: 1129, courses: 3412, eventsPerSec: 42 },
    health: REGIONS.map((r) => ({ regionId: r.id, name: r.name, lat: r.lat, lon: r.lon, ...REGION_HEALTH[r.id] })),
  };
}

/** GET /admin/sources · /admin/derived · /admin/quality */
export async function getAdminData() {
  if (!isMock) {
    const [sources, derived, quality] = await Promise.all([get('/admin/sources'), get('/admin/derived'), get('/admin/quality')]);
    return { sources, derived, quality };
  }
  await wait(300);
  return { sources: SOURCES, derived: DERIVED, quality: QUALITY };
}

/** GET /admin/users · /admin/access-logs · /admin/masking-rules */
export async function getAdminSecurity() {
  if (!isMock) {
    const [users, logs, masking] = await Promise.all([get('/admin/users'), get('/admin/access-logs'), get('/admin/masking-rules')]);
    return { users, logs, masking };
  }
  await wait(300);
  return { users: ACCOUNTS, logs: ACCESS_LOG, masking: MASKING };
}

/** PATCH /admin/users/{id} — 상권 주인 승인, 정지 등 */
export async function updateUser(id, body) {
  if (!isMock) return patch(`/admin/users/${id}`, body);
  await wait(300);
  return { id, ...body };
}

/** GET /admin/backups · /admin/retention */
export async function getAdminBackups() {
  if (!isMock) {
    const [backups, retention] = await Promise.all([get('/admin/backups'), get('/admin/retention')]);
    return { backups, retention };
  }
  await wait(300);
  return { backups: BACKUPS, retention: RETENTION };
}

/** POST /admin/backups */
export async function requestBackup() {
  if (!isMock) return post('/admin/backups');
  await wait(300);
  return { message: '수동 스냅샷 요청을 보냈어요. (목업)' };
}

/** POST /admin/backups/{id}/restore */
export async function restoreBackup(id) {
  if (!isMock) return post(`/admin/backups/${encodeURIComponent(id)}/restore`);
  await wait(300);
  return { message: `${id} 스냅샷 복구는 관리자 2인 승인이 필요해요. (목업)` };
}

/**
 * 실시간 이벤트 구독. WS {eventStreamUrl}?token=... 로 { type, text, at } 를 받습니다.
 * 돌려준 함수를 부르면 구독을 끊습니다.
 */
export function subscribeEvents(onEvent) {
  if (!isMock && config.eventStreamUrl) {
    const token = loadSession()?.accessToken ?? '';
    const ws = new WebSocket(`${config.eventStreamUrl}?token=${encodeURIComponent(token)}`);
    ws.onmessage = (m) => { try { onEvent(JSON.parse(m.data)); } catch { /* 형식 오류 무시 */ } };
    return () => ws.close();
  }
  const pad = (n) => String(n).padStart(2, '0');
  const t = setInterval(() => {
    const [type, text] = EVENT_SAMPLES[Math.floor(Math.random() * EVENT_SAMPLES.length)];
    const d = new Date();
    onEvent({ type, text, at: `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}` });
  }, 2600);
  return () => clearInterval(t);
}
