// ─────────────────────────────────────────────
// 백엔드 대화 API(/tourist/course/chat)가 못 하는 코스 수정을 화면에서 직접 처리합니다.
// 백엔드는 "해산물로 / 줄이기 / 실내로" 세 가지만 바꿀 수 있어서,
// "코스를 더 늘려줘", "카페 하나 더 넣어줘" 같은 요청은 여기서 장소를 골라 넣습니다.
// 장소 후보는 백엔드와 같은 장소 목록(mock/tourist.js PLACES)이고, 허브 근거도 붙입니다.
// ─────────────────────────────────────────────
import { PLACES, KIND_LABEL } from '../mock/tourist.js';
import { km, schedule } from './planner.js';
import { applyHub } from './hub.js';

export const MAX_STOPS = 7;

const KIND_WORDS = [
  ['cafe', /카페|커피|디저트|브런치|빵/],
  ['sunset', /노을|일몰|석양|해\s*질/],
  ['food', /식당|맛집|밥|저녁|점심|먹을|먹고|음식/],
  ['indoor', /실내\s*체험|체험|박물관|전시|공방/],
  ['spot', /산책|해변|바다|관광|오름|걷|명소|구경/],
];

const NUM_WORDS = { 한: 1, 하나: 1, 두: 2, 둘: 2, 세: 3, 셋: 3 };

/** "늘려줘 / 추가 / 하나 더 / 넣어줘" 류인지. 해산물·줄이기·실내 전환은 백엔드가 처리하므로 제외 */
export function isAddRequest(message) {
  const m = message.replace(/\s+/g, ' ');
  if (/해산물|회로|바다\s*음식|줄여|빼|실내로\s*바꿔/.test(m)) return false;
  return /늘려|늘리|추가|더\s*넣|넣어|하나\s*더|한\s*곳\s*더|\d+\s*곳\s*더|더\s*가고|더\s*많이|더\s*추천/.test(m);
}

function wantedCount(message) {
  const n = message.match(/(\d+)\s*(곳|개|군데)/);
  if (n) return Math.max(1, Math.min(3, Number(n[1])));
  const w = message.match(/(한|하나|두|둘|세|셋)\s*(곳|개|군데)?/);
  return w && /곳|개|군데|더/.test(message) ? NUM_WORDS[w[1]] ?? 1 : 1;
}

function wantedKind(message) {
  return KIND_WORDS.find(([, re]) => re.test(message))?.[0] ?? null;
}

const fmtEnd = (stops) => {
  const last = stops[stops.length - 1];
  if (!last) return null;
  const [h, m] = last.at.split(':').map(Number);
  const t = h * 60 + m + last.stay;
  return `${String(Math.floor(t / 60) % 24).padStart(2, '0')}:${String(t % 60).padStart(2, '0')}`;
};

// 하루 흐름: 낮(카페·산책·실내) → 노을 → 저녁 식사
const PHASE = { cafe: 0, spot: 0, indoor: 0, sunset: 1, food: 2 };

// 노을 명소 도착이 늦어지면 한 번 알려 줍니다 (제주 일몰은 계절에 따라 17~20시)
function lateSunset(stops) {
  const s = stops.find((x) => x.kind === 'sunset');
  if (!s) return '';
  const [h, m] = s.at.split(':').map(Number);
  return h * 60 + m >= 19 * 60 ? ` 다만 '${s.name}' 도착이 ${s.at}라 해가 진 뒤일 수 있어요. 하나 빼고 싶으면 "1곳 줄여줘"라고 해 주세요.` : '';
}

/** 장소를 시간 흐름에 맞는 자리에 끼워 넣습니다 (예: 카페는 노을·저녁 앞에) */
export function insertPlaces(stops, places) {
  const out = [...stops];
  for (const p of places) {
    if (out.some((s) => s.id === p.id)) continue;
    const at = out.findIndex((s) => (PHASE[s.kind] ?? 0) > (PHASE[p.kind] ?? 0));
    out.splice(at < 0 ? out.length : at, 0, p);
  }
  return out;
}

/** 지금 코스에 넣을 장소 고르기: 원하는 종류 → 없으면 코스에 적은 종류, 비면 실내, 앞 장소와 가까운 곳 */
function pickPlaces(stops, { count, kind, rain, hub }) {
  const all = applyHub(PLACES, hub);
  const used = new Set(stops.map((s) => s.id));
  const picked = [];
  for (let i = 0; i < count; i++) {
    const cur = insertPlaces(stops, picked);
    const kindCount = (k) => cur.filter((s) => s.kind === k).length;
    // 넣을 자리 바로 앞 장소에서 가까운 곳 (자리는 종류마다 다름)
    const anchorFor = (p) => {
      const at = cur.findIndex((s) => (PHASE[s.kind] ?? 0) > (PHASE[p.kind] ?? 0));
      return cur[(at < 0 ? cur.length : at) - 1] ?? cur[0];
    };
    // 종류를 말하지 않았으면: 저녁 식사가 없을 때는 식당부터, 있으면 코스에 적은 종류(식당 제외)
    const k = kind ?? (kindCount('food') === 0 ? 'food' : null);
    const pool = all.filter((p) => !used.has(p.id) && !picked.some((x) => x.id === p.id))
      .filter((p) => (k ? p.kind === k : p.kind !== 'food'))
      .filter((p) => !rain || p.indoor || kind);
    if (!pool.length) break;
    const score = (p) => (anchorFor(p) ? km(anchorFor(p), p) : 0) + (k ? 0 : kindCount(p.kind) * 4) - p.rating * 2;
    picked.push([...pool].sort((a, b) => score(a) - score(b))[0]);
  }
  return picked;
}

/**
 * "코스를 더 늘려줘" 같은 요청을 처리합니다. 해당 요청이 아니면 null.
 * 결과 { reply, course, added: [장소 id] }
 */
export function addToCourse(message, course, { startTime, rain = false, hub = null } = {}) {
  if (!course || !isAddRequest(message)) return null;
  const room = MAX_STOPS - course.stops.length;
  if (room <= 0) {
    return { reply: `지금 ${course.stops.length}곳이라 더 넣으면 하루에 다 돌기 어려워요. 하나를 빼고 바꿔 볼까요?`, course: null, added: [] };
  }
  const kind = wantedKind(message);
  const picked = pickPlaces(course.stops, { count: Math.min(room, wantedCount(message)), kind, rain, hub })
    .map((p) => ({ ...p, reasons: [['요청', '대화로 추가한 장소예요'], ...p.reasons] }));
  if (!picked.length) {
    return { reply: `${kind ? `${KIND_LABEL[kind]} 중에는 ` : ''}더 넣을 만한 곳을 찾지 못했어요. 다른 종류로 말해 주세요.`, course: null, added: [] };
  }
  const stops = schedule(insertPlaces(course.stops, picked), startTime);
  const end = fmtEnd(stops);
  const names = picked.map((p) => `'${p.name}'`).join(', ');
  return {
    reply: `${names} 추가했어요. 이제 ${stops.length}곳을 도는 코스이고, ${end}쯤 끝나요.${lateSunset(stops)}`,
    course: { ...course, stops },
    added: picked.map((p) => p.id),
  };
}

/** 백엔드가 코스를 다시 짠 뒤에도 대화로 추가한 장소를 유지합니다 */
export function keepAdded(stops, addedIds, startTime) {
  if (!addedIds?.length) return stops;
  const byId = Object.fromEntries(PLACES.map((p) => [p.id, p]));
  const extra = addedIds.map((id) => byId[id]).filter(Boolean)
    .map((p) => ({ ...p, reasons: [['요청', '대화로 추가한 장소예요'], ...p.reasons] }));
  const merged = insertPlaces(stops, extra).slice(0, MAX_STOPS);
  return schedule(merged, startTime);
}
