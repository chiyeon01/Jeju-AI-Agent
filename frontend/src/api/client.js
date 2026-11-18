// ─────────────────────────────────────────────
// API 클라이언트 — 화면은 이 파일의 함수만 사용합니다.
// config.useMock=true 이면 목업 응답, false 이면 백엔드(config.apiBaseUrl)를 호출합니다.
// 엔드포인트·응답 형식은 「제주잇다 BE 연동 명세」 PDF 와 같습니다.
// ─────────────────────────────────────────────
import { config } from '../config.js';
import { PLACES, REGIONS, WEATHER, scoreAnswers } from '../mock/tourist.js';
import { DEMO_ACCOUNTS, DEMO_PASSWORD, TEST_ACCOUNTS } from '../mock/auth.js';
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
    const em = email.trim().toLowerCase();
    const local = mockAccounts().find((a) => a.email === em);
    const demo = DEMO_ACCOUNTS.find((a) => a.email === em);
    const test = TEST_ACCOUNTS.find((a) => a.email === em && password === em.split('@')[0]);
    const u = local && local.password === password ? local.user : demo && password === DEMO_PASSWORD ? demo : test || null;
    if (!u) throw new ApiError(401, 'INVALID_CREDENTIALS', '이메일 또는 비밀번호가 맞지 않아요.');
    if (u.status === 'PENDING') throw new ApiError(403, 'ACCOUNT_PENDING', '관리자 승인 후 이용할 수 있어요.');
    session = { accessToken: 'mock-access', refreshToken: 'mock-refresh', user: u };
  }
  saveSession(session);
  return session.user;
}

/** POST /auth/signup → { user } (상권 주인은 관리자 승인 전까지 status=PENDING) */
export async function signup(form) {
  if (!isMock) return (await post('/auth/signup', form)).user;
  await wait(500);
  const list = mockAccounts();
  if (DEMO_ACCOUNTS.some((a) => a.email === form.email) || list.some((a) => a.email === form.email)) {
    throw new ApiError(409, 'EMAIL_TAKEN', '이미 가입된 이메일이에요.');
  }
  const user = { id: `u-${Date.now()}`, email: form.email, name: form.name, role: form.role, status: form.role === 'MERCHANT' ? 'PENDING' : 'ACTIVE' };
  try { localStorage.setItem(MOCK_ACCOUNTS, JSON.stringify([...list, { email: form.email, password: form.password, user }])); } catch { /* 저장 불가 */ }
  return user;
}

// 목업 모드에서 회원가입한 계정 (이 브라우저에만 저장, 백엔드 모드에서는 쓰지 않음)
const MOCK_ACCOUNTS = 'jeju-mock-accounts';
function mockAccounts() {
  try { return JSON.parse(localStorage.getItem(MOCK_ACCOUNTS) || '[]'); } catch { return []; }
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

/** GET /map/places?region= — 지역의 장소 (평점은 관광객 실제 별점이 반영된 값) */
export async function getPlaces(region) {
  if (!isMock) return get(`/map/places${region ? `?region=${encodeURIComponent(region)}` : ''}`);
  return PLACES.filter((p) => !region || p.region === region);
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

// 시작·끝 시각 → 백엔드 hours (예전 서버는 endTime 을 모르므로 함께 보냅니다)
const toMin = (hhmm) => { const [h, m] = String(hhmm || '0:0').split(':').map(Number); return h * 60 + m; };
export function tripHours(startTime, endTime) {
  if (!endTime) return undefined;
  let d = toMin(endTime) - toMin(startTime);
  if (d <= 0) d += 24 * 60;
  return Math.max(1, Math.min(12, Math.ceil(d / 60)));
}

function courseBody({ profile, origin, weather, startTime, removeCount = 0, seafood = false }) {
  const endTime = profile.endTime;
  return {
    profile, regionId: origin.id, startTime, ...(endTime ? { endTime } : {}),
    hours: tripHours(startTime, endTime) ?? profile.hours, weather, options: { seafood, removeCount },
  };
}

/** POST /tourist/course — 코스 플래너 Agent */
export async function planCourse(args) {
  if (!isMock) return post('/tourist/course', courseBody(args));
  return mockCourse(args);
}

/** POST /tourist/course/alternative — 다른 코스 보기 (Agent 가 지금까지 본 장소를 피해 새로 고름) */
export async function alternativeCourse({ avoid = [], ...args }) {
  if (!isMock) return post('/tourist/course/alternative', { ...courseBody(args), avoid: avoid.slice(-60) });
  const c = await mockCourse({ ...args, avoid });
  return { ...c, source: 'rule', summary: '이전에 본 코스와 다른 장소 위주로 다시 골랐어요.' };
}

async function mockCourse({ profile, origin, weather, startTime = '15:00', removeCount = 0, seafood = false, avoid = [] }) {
  await wait(600);
  const rain = weather === 'rain';
  const skip = new Set(avoid);
  const near = [...PLACES].sort((a, b) => km(a, origin) - km(b, origin));
  // 가까운 두 곳 중 하나를 무작위로 골라, 같은 지역이어도 매번 같은 코스가 나오지 않게 합니다
  const pick = (kinds, used, pred = () => true) => {
    const top = near.filter((p) => kinds.includes(p.kind) && !used.has(p.id) && pred(p)).slice(0, 2);
    return top[Math.floor(Math.random() * top.length)];
  };
  const order = rain ? [['cafe'], ['indoor'], ['indoor', 'cafe'], ['food']] : [['cafe'], ['spot'], ['sunset'], ['food']];
  const used = new Set();
  const stops = [];
  for (const kinds of order) {
    const pred = kinds.includes('food') && seafood ? (p) => p.seafood : rain ? (p) => p.indoor : () => true;
    const p = pick(kinds, used, (x) => !skip.has(x.id) && pred(x)) || pick(kinds, used, (x) => !skip.has(x.id)) || pick(kinds, used);
    if (p) { used.add(p.id); stops.push(p); }
  }
  const trimmed = stops.slice(0, Math.max(2, stops.length - removeCount));
  let t = toMin(startTime);
  const end = profile.endTime ? toMin(profile.endTime) + (toMin(profile.endTime) <= t ? 24 * 60 : 0) : null;
  const fmt = (x) => `${String(Math.floor(x / 60) % 24).padStart(2, '0')}:${String(x % 60).padStart(2, '0')}`;
  const out = [];
  for (const [i, p] of trimmed.entries()) {
    // 직선거리(km) × 1.3(도로 보정) ÷ 평균 35km/h + 주차·도보 4분
    const move = i === 0 ? 0 : Math.max(5, Math.round((km(p, trimmed[i - 1]) * 1.3 / 35) * 60 + 4));
    if (end != null && out.length >= 2 && t + move + p.stay > end) break;
    t += move;
    const at = fmt(t);
    t += p.stay;
    out.push({ ...p, at, move });
  }
  return { weather: { code: weather, ...WEATHER[weather] }, stops: out };
}

// ── 장소 링크·대표 사진 ───────────────────────
/** 장소 이름 → 네이버 검색어. 목록에 있는 장소면 시·읍면을 붙여 한 곳으로 좁힙니다 (예: 제주시 애월읍 봄날카페) */
export function placeQuery(name) {
  const p = PLACES.find((x) => x.name === name);
  if (p?.addr) return `${p.addr.split(' ').slice(0, 2).join(' ')} ${name}`;
  return /제주|서귀포/.test(name) ? name : `제주 ${name}`;
}

/** 장소 정보 (읍·면·동, 종류 이름). 목록에 없으면 null */
export function placeInfo(name) {
  return PLACES.find((x) => x.name === name) ?? null;
}

/** 네이버 지도 검색 링크 (가게·위치 이름으로) */
export function naverPlaceUrl(name) {
  return `https://map.naver.com/p/search/${encodeURIComponent(placeQuery(name))}`;
}

const photoCache = new Map();
/** GET /places/photo?q= → 대표 사진 { thumbnail, image } | null (서버에 네이버 검색 키가 있을 때) */
export function placePhoto(name) {
  if (isMock || !name) return Promise.resolve(null);
  if (!photoCache.has(name)) {
    photoCache.set(name, get(`/places/photo?q=${encodeURIComponent(placeQuery(name))}`).then((r) => r?.photo ?? null).catch(() => null));
  }
  return photoCache.get(name);
}

/** 검색어 그대로 대표 사진 (지역 사진 등) → { thumbnail, image } | null */
export function searchPhoto(query) {
  if (isMock || !query) return Promise.resolve(null);
  if (!photoCache.has(`q:${query}`)) {
    photoCache.set(`q:${query}`, get(`/places/photo?q=${encodeURIComponent(query)}`).then((r) => r?.photo ?? null).catch(() => null));
  }
  return photoCache.get(`q:${query}`);
}

// ── 주소로 출발 지역 찾기 ──────────────────────
// 서버 카카오 주소 검색이 안 되면 읍·면·동 이름으로 지역을 찾습니다
const ADDRESS_WORDS = [
  ['aewol', /애월|하귀|곽지|한담|고내|구엄|납읍/],
  ['hallim', /한림|한경|협재|금능|고산|판포|저지/],
  ['daejeong', /대정|안덕|모슬포|산방|사계|화순|송악|가파|마라/],
  ['jungmun', /중문|색달|대포|하원|예래|상예/],
  ['namwon', /남원|표선|위미|신례|가시리|세화리.*표선|하례/],
  ['seongsan', /성산|우도|오조|고성|신양|섭지|온평|시흥/],
  ['gujwa', /구좌|월정|세화|김녕|평대|하도|종달|송당|비자림/],
  ['jocheon', /조천|함덕|신촌|북촌|선흘|와흘|교래/],
  ['seogwipo', /서귀포|서귀동|서홍|동홍|토평|보목|법환|강정|천지동|정방|효돈|쇠소깍|이중섭/],
  ['jeju-city', /제주시|연동|노형|이도|일도|삼도|건입|용담|아라|오라|도두|외도|이호|화북|삼양|봉개|탑동|동문|공항/],
];

/** 주소 → { region, label } (못 찾으면 null) */
export async function regionFromAddress(address) {
  const q = address.trim();
  if (!q) return null;
  if (!isMock) {
    try {
      const g = await post('/map/geocode', { query: q.includes('제주') ? q : `제주 ${q}` });
      const it = g?.items?.[0];
      if (it && it.lat >= 32.9 && it.lat <= 34.1) {
        const r = await nearestRegion(it.lat, it.lon);
        return { region: { ...r, at: { lat: it.lat, lon: it.lon } }, label: it.roadAddress || it.address || q };
      }
    } catch { /* 아래 이름 찾기로 */ }
  }
  const hit = ADDRESS_WORDS.find(([, re]) => re.test(q.replace(/\s/g, '')));
  if (!hit) return null;
  const regions = await getRegions();
  const r = regions.find((x) => x.id === hit[0]);
  return r ? { region: r, label: q } : null;
}

/** POST /tourist/course/chat */
export async function chatCourse(message, { stopIds, history = [] } = {}) {
  if (!isMock) {
    // 사용자 말 그대로 + 지금 코스 + 앞선 대화를 보내면, 서버의 GPT 가 고친 코스(course)를 돌려줍니다
    const res = await post('/tourist/course/chat', {
      message, ...(stopIds ? { stopIds } : {}),
      history: history.slice(-6).map((m) => ({ from: m.from === 'me' ? 'me' : 'ai', text: m.text })),
    });
    // 백엔드는 바뀌지 않은 항목을 null 로 보내므로, 값이 있는 항목만 남깁니다 (null 이 날씨를 덮어쓰지 않게)
    const p = Object.fromEntries(Object.entries(res.patch ?? {}).filter(([, v]) => v != null));
    return { reply: res.reply, patch: Object.keys(p).length ? p : null, course: res.course ?? null };
  }
  await wait(500);
  if (/아기|아이(와|랑|들|가|를|\s|$)|애기|유아|어린이|키즈/.test(message)) return { reply: '아이와 함께 가기 좋은 곳 위주로 바꿨어요.', patch: { weather: 'rain' } };
  if (/분좋카|분위기 ?(좋은|있는) ?카페|감성 ?카페/.test(message)) return { reply: '분위기 좋은 카페로 바꿨어요.', patch: { removeCount: 0 } };
  if (/해산물|회|바다 음식/.test(message)) return { reply: '저녁을 해산물 식당으로 바꿨어요.', patch: { seafood: true } };
  if (/줄여|빼|1곳/.test(message)) return { reply: '마지막 장소 하나를 뺐어요.', patch: { removeCount: 1 } };
  if (/비|실내/.test(message)) return { reply: '실내 위주 코스로 바꿨어요.', patch: { weather: 'rain' } };
  return { reply: '시연 화면에서는 "회를 먹고싶어", "아기가 놀기 좋은 곳으로", "분좋카를 원해"를 알아들어요.', patch: null };
}

/** GET /tourist/ai/status → { enabled } 서버에 GPT 키가 있고 GPT 중계 API 가 있는지 (없으면 false) */
export async function aiStatus() {
  if (isMock || !config.gptRelay) return { enabled: false };
  try { return await request('GET', '/tourist/ai/status'); } catch { return { enabled: false }; }
}

/** POST /tourist/ai/json — 프론트 프롬프트를 서버의 GPT 키로 보내고 JSON 을 받습니다 */
export async function aiJson(purpose, system, user, temperature) {
  return (await request('POST', '/tourist/ai/json', { purpose, system, user, temperature })).data;
}

// ── 제주데이터허브 (백엔드 /datahub 경유, 키는 백엔드에만) ──
// 허브 원본은 백엔드(Main PC)에만 있고, 화면은 백엔드가 가공한 값만 받습니다.
let hubCache = null;
/** { crowd: {date, regions:{지역id:{index, vsAveragePct}}} | null, sights: {start, items:[{sightsName, domestic, foreign}]} | null } */
export function getHubData() {
  if (isMock) return Promise.resolve({ crowd: null, sights: null });
  if (!hubCache) {
    const safe = (p) => request('GET', p).catch(() => null);
    hubCache = Promise.all([safe('/datahub/crowd'), safe('/datahub/sights')]).then(([crowd, sights]) => {
      const out = { crowd, sights };
      if (!crowd && !sights) hubCache = null; // 실패면 다음에 다시 시도
      return out;
    });
  }
  return hubCache;
}

/** GET /weather/now — 서버가 대신 가져온 실시간 날씨 */
export function serverWeather(lat, lon) {
  return get(`/weather/now?lat=${lat.toFixed(4)}&lon=${lon.toFixed(4)}`);
}

/** POST /tourist/reviews */
export async function submitReviews(reviews) {
  if (!isMock) return post('/tourist/reviews', { reviews });
  await wait(500);
  return { accepted: reviews.length };
}

// ── 상권 주인 ──────────────────────────────
// 대시보드는 사장님이 연결한 내 가게에 관광객이 실제로 남긴 평가로만 만듭니다 (시연용 고정 데이터 없음).
/** GET /owner/reviews/topics → { topics:[{ topic, pos, mentions, summary }], source:'gpt'|'rule', reviewCount, textCount, createdAt }
 *  리뷰 주제별 반응: 백엔드 GPT 가 프롬프트(backend/app/prompts/review_topics.md)로 분석 */
export async function getReviewTopics() {
  if (isMock) return { topics: [], source: 'rule', reviewCount: 0, textCount: 0, createdAt: new Date().toISOString() };
  return get('/owner/reviews/topics');
}

export const OWNER_SUGGESTED_QUESTIONS = [
  '손님들이 가장 아쉬워하는 점은 뭐예요?',
  '별점을 올리려면 무엇부터 바꿀까요?',
  '어떤 성향의 손님이 많이 오나요?',
];

/** POST /owner/ask — 상권 분석 Agent (내 가게 별점·리뷰가 근거) */
export async function askOwnerAgent(question) {
  if (!isMock) return post('/owner/ask', { question });
  return { answer: '백엔드에 연결하면 상권 분석 Agent가 내 가게 리뷰를 근거로 답해요.' };
}

/** POST /owner/actions */
export async function registerAction(action) {
  if (!isMock) return post('/owner/actions', action);
  await wait(300);
  return { id: Date.now(), ...action, status: 'MEASURING' };
}

// ── 내 가게 별점·리뷰 (관광객 평가 실데이터) ─────
// 가게 검색·연결·내 리뷰는 임시(목업) 데이터를 쓰지 않습니다. 관광객이 실제로 남긴 평점만 백엔드 DB 에서 가져옵니다.
/** GET /owner/places?q= → [{ id, no, name, region, kind, reviews, avgStars, lastReviewAt }]
 *  관광객이 앱에서 평점을 남긴 가게만, 최근 평가 순 */
export async function getMerchantPlaces(q = '') {
  if (isMock) return [];
  return get(`/owner/places${q.trim() ? `?q=${encodeURIComponent(q.trim())}` : ''}`);
}

/** PUT /owner/place { placeId } — 평점을 받은 가게만 연결됩니다 (아니면 PLACE_NOT_RATED) */
export async function linkMyPlace(placeId) {
  if (isMock) throw new ApiError(400, 'MOCK', '가게 연결은 백엔드에 연결해야 쓸 수 있어요 (VITE_USE_MOCK=false).');
  return request('PUT', '/owner/place', { placeId });
}

/** GET /owner/my-reviews → { place, summary:{count, avg, dist, byType[]}, reviews[], regionScore, analysis } (연결 전이면 null) */
export async function getMyReviews() {
  if (isMock) return null;
  try { return await get('/owner/my-reviews'); } catch (e) { if (e.code === 'PLACE_NOT_LINKED') return null; throw e; }
}

/** POST /owner/my-reviews/analysis → 저장된 분석 { id, title, body, source, createdAt } */
export async function analyzeMyReviews() {
  if (!isMock) return post('/owner/my-reviews/analysis');
  await wait(500);
  return { id: Date.now(), title: '리뷰 분석', body: '## 한 줄 요약\n- 시연 화면이라 실제 리뷰가 없어요.', source: 'rule', createdAt: new Date().toISOString() };
}

// ── 관리자 (Main PC 콘솔) ───────────────────
/** GET /admin/insights/regions → { updatedAt, crowdDate, weights, regions:[{ regionId, name, score, satisfaction, demand, comfort, reviews, avgStars, courses7d, reviews7d, crowd }] } */
export async function getRegionScores() {
  if (!isMock) return get('/admin/insights/regions');
  await wait(200);
  return {
    updatedAt: new Date().toISOString(), crowdDate: null, weights: { satisfaction: 0.5, demand: 0.3, comfort: 0.2 },
    regions: REGIONS.map((r) => ({ regionId: r.id, name: r.name, score: 6.3, satisfaction: 6.3, demand: 0, comfort: null, reviews: 0, avgStars: null, courses7d: 0, reviews7d: 0, crowd: null })),
  };
}

/** GET /admin/insights/places → 장소 고유 번호별 평가·사장님 연결·최근 분석 */
export async function getPlaceOverview() {
  if (!isMock) return get('/admin/insights/places');
  return PLACES.map((p, i) => ({ no: i + 1, id: p.id, name: p.name, region: p.region, kind: p.kind, reviews: 0, avgStars: null, owner: false, lastAnalysis: null }));
}

/** GET /admin/reports → Agent 가 저장한 지역 보고서 목록 */
export async function getRegionReports() {
  if (!isMock) return get('/admin/reports?limit=20');
  return [];
}

/** POST /admin/reports → 새 보고서 (GPT, 실패하면 규칙 기반) */
export async function createRegionReport() {
  if (!isMock) return post('/admin/reports');
  await wait(500);
  return { id: Date.now(), title: '지역 점수 보고서 (시연)', body: '## 요약\n- 시연 화면이라 실제 데이터가 없어요.', source: 'rule', createdAt: new Date().toISOString() };
}

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
function openEvents(onEvent) {
  const token = loadSession()?.accessToken ?? '';
  const ws = new WebSocket(`${config.eventStreamUrl}?token=${encodeURIComponent(token)}`);
  ws.onmessage = (m) => { try { onEvent(JSON.parse(m.data)); } catch { /* 형식 오류 무시 */ } };
  return () => ws.close();
}

/** 상권 주인: 내 가게(연결한 장소)에 새 평가·Agent 분석이 생기면 실시간으로 받습니다 */
export function subscribeMyStore(onEvent) {
  if (!isMock && config.eventStreamUrl) return openEvents(onEvent);
  return () => {};
}

export function subscribeEvents(onEvent) {
  if (!isMock && config.eventStreamUrl) return openEvents(onEvent);
  const pad = (n) => String(n).padStart(2, '0');
  const t = setInterval(() => {
    const [type, text] = EVENT_SAMPLES[Math.floor(Math.random() * EVENT_SAMPLES.length)];
    const d = new Date();
    onEvent({ type, text, at: `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}` });
  }, 2600);
  return () => clearInterval(t);
}
