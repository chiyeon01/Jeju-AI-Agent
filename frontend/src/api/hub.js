// ─────────────────────────────────────────────
// 제주데이터허브 값을 장소 목록에 붙입니다.
//  - D2 지역 혼잡도: 백엔드 /datahub/crowd (지역 id 별 0~1 지수, 평균 대비 %)
//  - D4 관광지 유입자 수: 백엔드 /datahub/sights (관광지명별 월 방문객)
// 허브 데이터는 Main PC(백엔드) 밖으로 나가면 안 되므로,
// 화면에는 숫자를 보여 주되 GPT 프롬프트에는 "낮음/보통/높음" 같은 등급만 넣습니다.
// ─────────────────────────────────────────────

// 우리 장소 id → 허브 관광지명에 들어 있는 낱말 (공백을 뺀 이름에서 찾습니다)
export const HUB_ALIAS = {
  p2: ['한담'], p6: ['협재'], p8: ['수월봉'], p10: ['동문시장', '동문재래시장'], p12: ['사라봉'],
  p14: ['함덕'], p17: ['월정'], p18: ['성산일출봉', '일출봉'], p19: ['광치기'], p21: ['중문', '색달'],
  p23: ['이중섭'], p24: ['쇠소깍'], p25: ['올레시장'], p26: ['표선'], p27: ['큰엉'], p29: ['송악산'],
};

const norm = (s) => String(s ?? '').replace(/\s/g, '');
const comma = (n) => Number(n).toLocaleString('ko-KR');

export function crowdLabel(index) {
  if (index == null) return '-';
  if (index >= 0.67) return '높음';
  if (index >= 0.34) return '보통';
  return '낮음';
}

export function popularityLabel(rankPct) {
  if (rankPct == null) return '-';
  if (rankPct <= 0.1) return '최상위';
  if (rankPct <= 0.3) return '상위';
  if (rankPct <= 0.6) return '보통';
  return '한산';
}

/** 허브 관광지 목록에서 장소 하나의 방문객 수와 순위(0=1등, 1=꼴찌)를 찾습니다 */
function findSight(placeId, items) {
  const alias = HUB_ALIAS[placeId];
  if (!alias || !items?.length) return null;
  const hits = items.filter((x) => alias.some((a) => norm(x.sightsName).includes(a)));
  if (!hits.length) return null;
  const total = hits.reduce((s, x) => s + (x.domestic || 0) + (x.foreign || 0), 0);
  const all = items.map((x) => (x.domestic || 0) + (x.foreign || 0)).sort((a, b) => b - a);
  const rank = all.findIndex((v) => v <= total);
  return { visitors: total, rankPct: (rank < 0 ? all.length : rank) / Math.max(1, all.length) };
}

/**
 * 장소마다 hub 값을 붙이고, 허브에서 확인한 근거를 맨 앞에 넣습니다.
 * 허브 값이 들어간 근거는 3번째 칸에 'hub' 표시를 달아 GPT 프롬프트에서 뺍니다.
 */
export function applyHub(places, hub) {
  const regions = hub?.crowd?.regions ?? {};
  const items = hub?.sights?.items ?? [];
  const month = hub?.sights?.start;
  if (!hub?.crowd && !items.length) return places;
  return places.map((p) => {
    const c = regions[p.region];
    const sight = findSight(p.id, items);
    const info = {
      crowd: c ? crowdLabel(c.index) : null,
      crowdPct: c?.vsAveragePct ?? null,
      crowdDate: hub?.crowd?.date ?? null,
      popularity: sight ? popularityLabel(sight.rankPct) : null,
      visitors: sight?.visitors ?? null,
      month: sight ? month : null,
    };
    const real = [];
    if (sight) real.push(['D4', `허브 ${month} 방문객 ${comma(sight.visitors)}명 (제주 관광지 중 ${popularityLabel(sight.rankPct)})`, 'hub']);
    if (c) real.push(['D2', `지역 유동인구 평균 대비 ${c.vsAveragePct >= 0 ? '+' : ''}${c.vsAveragePct}% · 혼잡도 ${info.crowd} (${hub.crowd.date})`, 'hub']);
    // 허브로 확인한 종류(D2·D4)의 예시 근거는 빼고 실제 값으로 바꿉니다
    const kept = p.reasons.filter(([src]) => !real.some(([s]) => s === src));
    return { ...p, hub: info, reasons: [...real, ...kept] };
  });
}

/** 허브 연결 상태를 화면용 한 줄로 */
export function hubLine(hub) {
  if (!hub?.crowd && !hub?.sights) return null;
  const parts = [];
  if (hub.crowd) parts.push(`지역 혼잡도 ${hub.crowd.date}`);
  if (hub.sights) parts.push(`관광지 방문객 ${hub.sights.start}`);
  return `제주데이터허브 반영: ${parts.join(' · ')}`;
}
