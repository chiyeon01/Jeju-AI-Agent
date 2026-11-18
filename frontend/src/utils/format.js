// 화면에 보이는 시간·숫자 표현

/** "방금", "5분 전", "3시간 전", "어제", "4일 전", "11월 2일" */
export function relTime(iso, now = new Date()) {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const sec = Math.max(0, (now - d) / 1000);
  if (sec < 60) return '방금';
  if (sec < 3600) return `${Math.floor(sec / 60)}분 전`;
  if (sec < 86400) return `${Math.floor(sec / 3600)}시간 전`;
  const days = Math.floor(sec / 86400);
  if (days === 1) return '어제';
  if (days < 7) return `${days}일 전`;
  return `${d.getMonth() + 1}월 ${d.getDate()}일`;
}

/** 시간대 인사 */
export function greeting(now = new Date()) {
  const h = now.getHours();
  if (h < 5) return '늦은 밤이에요';
  if (h < 11) return '좋은 아침이에요';
  if (h < 17) return '좋은 오후예요';
  if (h < 21) return '좋은 저녁이에요';
  return '편안한 밤 보내세요';
}

const toMin = (hhmm) => { const [h, m] = String(hhmm || '0:0').split(':').map(Number); return h * 60 + m; };
const fmt = (m) => `${String(Math.floor(m / 60) % 24).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;

/** "1시간 20분", "45분" */
export function duration(min) {
  const h = Math.floor(min / 60), m = Math.round(min % 60);
  return h ? `${h}시간${m ? ` ${m}분` : ''}` : `${m}분`;
}

/** 코스 요약: 끝나는 시각, 총 이동 시간, 총 시간 */
export function courseSummary(stops = []) {
  if (!stops.length) return null;
  const start = toMin(stops[0].at);
  const last = stops[stops.length - 1];
  let end = toMin(last.at) + (last.stay || 0);
  if (end < start) end += 24 * 60;
  const move = stops.reduce((s, x) => s + (x.move || 0), 0);
  return { start: stops[0].at, end: fmt(end), total: duration(end - start), move: duration(move), moveMin: move };
}

/** 장소를 떠나는 시각 */
export function leaveAt(stop) {
  return stop.stay ? fmt(toMin(stop.at) + stop.stay) : null;
}

/** 카카오맵 길찾기 (도착지) */
export function kakaoRouteUrl(s) {
  return s.lat != null ? `https://map.kakao.com/link/to/${encodeURIComponent(s.name)},${s.lat},${s.lon}` : `https://map.kakao.com/?q=${encodeURIComponent(s.name)}`;
}
