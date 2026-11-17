// ─────────────────────────────────────────────
// 코스 플래너 (GPT)
//  - planCourseAI : 성향 + 실시간 날씨 + 출발 지역 → GPT 가 후보 장소 중에서 코스를 짭니다
//  - chatCourseAI : 지금 코스 + 대화 기록 + 사용자 말 → GPT 가 코스를 고칩니다
// 프롬프트 문장은 src/prompts/*.md 에 있습니다.
// GPT 가 고르는 건 장소 id 와 이유뿐이고, 도착 시각·이동 시간은 여기서 계산합니다.
// GPT 를 쓸 수 없으면 null 을 돌려주고, 화면은 기존 planCourse / chatCourse 로 대신합니다.
// ─────────────────────────────────────────────
import { PLACES, KIND_LABEL, WEATHER } from '../mock/tourist.js';
import { render } from '../prompts/index.js';
import { chatJson, gptAvailable } from './gpt.js';
import { applyHub } from './hub.js';

const byId = (list) => Object.fromEntries(list.map((p) => [p.id, p]));
const CANDIDATE_LIMIT = 18;

export function km(a, b) {
  const R = 6371, rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad, dLon = (b.lon - a.lon) * rad;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

// 직선거리(km) × 1.3(도로 보정) ÷ 평균 35km/h + 주차·도보 4분 (백엔드 geo.travel_minutes 와 같은 식)
const moveMinutes = (a, b) => Math.max(5, Math.round(((km(a, b) * 1.3) / 35) * 60 + 4));
const fmt = (x) => `${String(Math.floor(x / 60) % 24).padStart(2, '0')}:${String(x % 60).padStart(2, '0')}`;

/** 장소 목록에 도착 시각·이동 시간을 붙입니다. why 가 있으면 첫 번째 근거로 보여 줍니다 */
export function schedule(stops, startTime = '15:00') {
  const [h, m] = startTime.split(':').map(Number);
  let t = h * 60 + m;
  return stops.map((s, i) => {
    const move = i === 0 ? 0 : moveMinutes(stops[i - 1], s);
    t += move;
    const at = fmt(t);
    t += s.stay;
    const reasons = s.why ? [['AI', s.why], ...s.reasons.filter(([src]) => src !== 'AI')] : s.reasons;
    return { ...s, reasons, at, move };
  });
}

// 출발지에서 가까운 순 + 비가 오면 실내를 앞쪽에. 종류별로 고르게 섞어 GPT 가 고를 거리를 줍니다
// places 는 허브 값(혼잡도·방문객)을 붙인 장소 목록입니다
function candidates(places, origin, rain, keepIds = []) {
  const all = byId(places);
  const near = [...places].sort((a, b) => km(a, origin) - km(b, origin));
  const out = new Map(keepIds.filter((id) => all[id]).map((id) => [id, all[id]]));
  const byKind = {};
  for (const p of near) (byKind[p.kind] ??= []).push(p);
  const kinds = Object.keys(byKind);
  for (let i = 0; out.size < CANDIDATE_LIMIT && i < 10; i++) {
    for (const k of kinds) {
      const p = byKind[k][i];
      if (p && out.size < CANDIDATE_LIMIT) out.set(p.id, p);
    }
  }
  if (rain) for (const p of near.filter((x) => x.indoor).slice(0, 6)) out.set(p.id, p);
  return [...out.values()];
}

// 허브 값은 숫자 대신 등급(낮음/보통/높음, 최상위/상위/보통/한산)만 GPT 에 보냅니다
function candidateTable(list, origin) {
  return list.map((p) => `| ${p.id} | ${p.name} | ${KIND_LABEL[p.kind]} | ${p.indoor ? '실내' : '야외'} | ${p.rating} | ${p.stay} | ${km(p, origin).toFixed(1)} | ${p.seafood ? '예' : '-'} | ${p.hub?.crowd ?? '-'} | ${p.hub?.popularity ?? '-'} | ${p.reasons.filter(([s, , tag]) => s !== 'AI' && tag !== 'hub').map(([s, r]) => `${s}: ${r}`).join(' / ')} |`).join('\n');
}

function profileText(p) {
  if (!p) return '- 아직 성향 테스트를 하지 않았어요';
  return [
    `- 유형: ${p.name} (${p.code})`,
    p.desc && `- 설명: ${p.desc}`,
    p.tags?.length && `- 태그: ${p.tags.join(' ')}`,
    p.scores && `- 축 점수(음수=왼쪽, 양수=오른쪽): 활동성 ${p.scores.act ?? 0}, 공간 ${p.scores.space ?? 0}, 취향 ${p.scores.taste ?? 0}, 스타일 ${p.scores.style ?? 0}`,
    `- 동행: ${p.companion ?? '모름'} · 이동수단: ${p.transport ?? '모름'}${p.budget ? ` · 예산: ${p.budget}` : ''}`,
  ].filter(Boolean).join('\n');
}

/** 화면이 쓰는 날씨(코드 + 실시간 값)를 GPT 용 한 줄로 */
export function weatherText(code, live) {
  const indoor = code === 'rain' && live?.code !== 'rain' ? ' · 여행자가 실내 위주로 바꿔 달라고 했어요' : '';
  if (live) {
    return `${live.label} ${live.temp}°C, 습도 ${live.humidity ?? '?'}%, 풍속 ${live.wind ?? '?'}m/s, 1시간 강수 ${live.rain1h ?? 0}mm (${live.source} 실시간)${indoor}`;
  }
  return `실시간 날씨를 불러오지 못했어요. 날씨를 단정하지 말고 실내·야외를 섞어 줘${indoor}`;
}

function kstNow() {
  const d = new Date(Date.now() + 9 * 3600 * 1000);
  const p = (n) => String(n).padStart(2, '0');
  return { today: `${d.getUTCFullYear()}-${p(d.getUTCMonth() + 1)}-${p(d.getUTCDate())}`, now: `${p(d.getUTCHours())}:${p(d.getUTCMinutes())}` };
}

const VARIATIONS = [
  '이번에는 덜 알려진 곳을 하나 넣어 봐', '이번에는 평점이 높은 곳 위주로', '이번에는 이동 거리를 최대한 짧게',
  '이번에는 사진 찍기 좋은 곳을 하나 더', '이번에는 현지인이 갈 법한 곳을 섞어서', '이번에는 마지막을 인상적인 곳으로',
];
const pickVariation = () => VARIATIONS[Math.floor(Math.random() * VARIATIONS.length)];

function hubText(hub) {
  const parts = [];
  if (hub?.crowd) parts.push(`지역 혼잡도는 ${hub.crowd.date} 유동인구 기준`);
  if (hub?.sights) parts.push(`관광지 인기도는 ${hub.sights.start} 방문객 수 기준`);
  return parts.length ? `${parts.join(', ')} (제주데이터허브)` : '제주데이터허브 값을 불러오지 못했어요. 혼잡도·인기도 칸은 비어 있어요';
}

function contextText({ profile, origin, weather, live, hub, startTime, list }) {
  const { today, now } = kstNow();
  return render('context', {
    hub: hubText(hub),
    today, now,
    origin: `${origin.name} (위도 ${origin.lat}, 경도 ${origin.lon})`,
    start_time: startTime,
    hours: profile?.hours ? `${profile.hours}시간` : '정하지 않음',
    weather: weatherText(weather, live),
    profile: profileText(profile),
    candidates: candidateTable(list, origin),
  });
}

// GPT 가 준 stops 를 검증: 후보에 있는 id 만, 중복 없이
function toStops(raw, list) {
  const allowed = new Set(list.map((p) => p.id));
  const PLACES_BY_ID = byId(list);
  const seen = new Set();
  const out = [];
  for (const s of Array.isArray(raw) ? raw : []) {
    const id = String(s?.id ?? '').trim();
    if (!allowed.has(id) || seen.has(id)) continue;
    seen.add(id);
    out.push({ ...PLACES_BY_ID[id], why: String(s?.why ?? '').trim() || undefined });
  }
  return out;
}

const fitHours = (stops, startTime, hours) => {
  if (!hours) return stops;
  const timed = schedule(stops, startTime);
  const [h, m] = startTime.split(':').map(Number);
  const end = h * 60 + m + hours * 60;
  const keep = timed.filter((s, i) => {
    const [sh, sm] = s.at.split(':').map(Number);
    let t = sh * 60 + sm;
    if (t < h * 60 + m) t += 24 * 60;
    return i < 2 || t + s.stay <= end;
  });
  return stops.slice(0, keep.length);
};

/** 처음 코스. GPT 를 못 쓰면 null */
export async function planCourseAI({ profile, origin, weather, live, hub, startTime = '15:00' }) {
  if (!(await gptAvailable())) return null;
  try {
    const list = candidates(applyHub(PLACES, hub), origin, weather === 'rain');
    const system = render('course_plan', { context: contextText({ profile, origin, weather, live, hub, startTime, list }), variation: pickVariation() });
    const res = await chatJson(system, '오늘 코스를 짜 줘.', { purpose: 'course_plan', temperature: 0.9 });
    const stops = fitHours(toStops(res.stops, list), startTime, profile?.hours);
    if (stops.length < 2) throw new Error('GPT 가 고른 장소가 2곳보다 적어요');
    return { weather: { code: weather, ...WEATHER[weather] }, stops: schedule(stops, startTime), summary: String(res.summary ?? '').trim(), source: 'gpt' };
  } catch (e) {
    console.warn('[planner] GPT 코스 실패, 기존 방식으로 대신합니다:', e.message);
    return null;
  }
}

const courseText = (course) => (course?.stops ?? [])
  .map((s, i) => `${i + 1}. ${s.at} ${s.name} (id ${s.id}, ${KIND_LABEL[s.kind]}, ${s.stay}분)`).join('\n') || '(아직 없음)';

const historyText = (history) => history.slice(-10)
  .map((m) => `${m.from === 'me' ? '여행자' : '플래너'}: ${m.text}`).join('\n') || '(없음)';

/** 대화로 코스 고치기. 결과 { reply, course|null }. GPT 를 못 쓰면 null */
export async function chatCourseAI({ message, history, course, profile, origin, weather, live, hub, startTime = '15:00' }) {
  if (!(await gptAvailable())) return null;
  try {
    const list = candidates(applyHub(PLACES, hub), origin, weather === 'rain', (course?.stops ?? []).map((s) => s.id));
    const system = render('course_chat', {
      context: contextText({ profile, origin, weather, live, hub, startTime, list }),
      course: courseText(course),
      history: historyText(history),
    });
    const res = await chatJson(system, message, { purpose: 'course_chat', temperature: 0.7 });
    const reply = String(res.reply ?? '').trim();
    if (!reply) throw new Error('GPT 답이 비어 있어요');
    if (res.action !== 'update') return { reply, course: null };
    const start = /^\d{1,2}:\d{2}$/.test(res.start_time ?? '') ? res.start_time : startTime;
    // 지금 코스의 이유(why)는 GPT 가 다시 주지 않으면 그대로 둡니다
    const prevWhy = Object.fromEntries((course?.stops ?? []).map((s) => [s.id, s.reasons?.find(([src]) => src === 'AI')?.[1]]));
    const stops = toStops(res.stops, list).map((s) => ({ ...s, why: s.why ?? prevWhy[s.id] }));
    if (stops.length < 1) return { reply, course: null };
    return { reply, course: { ...course, weather: course?.weather ?? { code: weather, ...WEATHER[weather] }, stops: schedule(stops, start), source: 'gpt' }, startTime: start };
  } catch (e) {
    console.warn('[planner] GPT 대화 실패, 기존 방식으로 대신합니다:', e.message);
    return null;
  }
}
