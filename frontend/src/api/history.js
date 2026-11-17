// ─────────────────────────────────────────────
// 내 여행 기록 (성향 테스트 · 만든 코스 · 보낸 평가)
// 백엔드는 성향 결과와 코스를 저장하지 않으므로, 이 기기(브라우저)에 계정별로 저장합니다.
// 다른 기기에서 로그인하면 보이지 않습니다.
// ─────────────────────────────────────────────
const KEY = (userId) => `jeju-history:${userId}`;
const LIMIT = 20;
const EMPTY = { profiles: [], courses: [], reviews: [] };

export function loadHistory(userId) {
  if (!userId) return EMPTY;
  try {
    const h = JSON.parse(localStorage.getItem(KEY(userId)) || 'null');
    return { ...EMPTY, ...(h ?? {}) };
  } catch { return EMPTY; }
}

function save(userId, h) {
  try { localStorage.setItem(KEY(userId), JSON.stringify(h)); } catch { /* 저장 불가(사생활 모드 등) */ }
}

const now = () => new Date().toISOString();
const push = (list, item) => [item, ...list].slice(0, LIMIT);

/** 성향 테스트 결과 */
export function recordProfile(userId, p) {
  if (!userId || !p) return;
  const h = loadHistory(userId);
  save(userId, { ...h, profiles: push(h.profiles, { at: now(), profile: p }) });
}

/** 여행을 마친 코스 */
export function recordCourse(userId, { course, origin, profile, live }) {
  if (!userId || !course) return;
  const h = loadHistory(userId);
  save(userId, {
    ...h,
    courses: push(h.courses, {
      at: now(),
      origin: origin?.name ?? '',
      type: profile ? `${profile.name} (${profile.code})` : '',
      weather: live ? `${live.icon} ${live.label} ${Math.round(live.temp)}°C` : null,
      source: course.source ?? 'rule',
      trip: profile ? [profile.companion, profile.transport, profile.endTime ? `${profile.startTime}~${profile.endTime}` : null].filter(Boolean).join(' · ') : '',
      stops: course.stops.map((s) => ({ id: s.id, name: s.name, kind: s.kind, at: s.at, lat: s.lat, lon: s.lon })),
    }),
  });
}

/** 보낸 평가 */
export function recordReviews(userId, items) {
  if (!userId || !items?.length) return;
  const h = loadHistory(userId);
  let reviews = h.reviews;
  for (const r of items) reviews = push(reviews, { at: now(), ...r });
  save(userId, { ...h, reviews });
}

export function clearHistory(userId) {
  try { localStorage.removeItem(KEY(userId)); } catch { /* 무시 */ }
}

/** "11월 17일 14:05" */
export function fmtWhen(iso) {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  return `${d.getMonth() + 1}월 ${d.getDate()}일 ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}
