import { REGIONS } from '../mock/tourist.js';
import { DONGS, MAP_W, MAP_H, project } from '../mock/jejuGeo.js';

const HALLA = project(33.3617, 126.5292);
const ALL_D = Object.values(DONGS).flat().map((g) => g.d).join('');

const scoreColor = (s) => (s >= 70 ? 'var(--good)' : s >= 60 ? 'var(--sea)' : s >= 55 ? 'var(--warn)' : 'var(--bad)');

/**
 * 제주 지도 (읍면동 실제 경계)
 * props
 *  - selected: region id      - onSelect(region): 지역 클릭
 *  - origin: {x,y} 출발 위치   - stops: 코스 장소 배열 (번호 + 경로, 자동 확대)
 *  - health: { [regionId]: { score, visits } } → 지역별 점수 색칠 (콘솔)
 *  - flows: [{from, to, count}] → 인기 코스 흐름선
 */
export default function JejuMap({ selected, onSelect, origin, stops, health, flows }) {
  const byId = Object.fromEntries(REGIONS.map((r) => [r.id, r]));

  // 코스가 있으면 코스 주변으로 확대합니다. k 는 글자·점 크기 보정 배율.
  let vb = [0, 0, MAP_W, MAP_H];
  if (stops?.length) {
    const pts = [...stops, ...(origin ? [origin] : [])];
    const xs = pts.map((p) => p.x), ys = pts.map((p) => p.y);
    const ratio = MAP_H / MAP_W;
    let w = Math.max(Math.max(...xs) - Math.min(...xs) + 140, 240);
    let h = w * ratio;
    const needH = Math.max(...ys) - Math.min(...ys) + 120;
    if (needH > h) { h = needH; w = h / ratio; }
    const cx = (Math.max(...xs) + Math.min(...xs)) / 2, cy = (Math.max(...ys) + Math.min(...ys)) / 2;
    vb = [cx - w / 2, cy - h / 2, w, h];
  }
  const k = vb[2] / MAP_W;

  return (
    <div className="map-wrap">
      <svg viewBox={vb.map((v) => v.toFixed(1)).join(' ')} role="img" aria-label="제주도 지도">
        <rect x={vb[0]} y={vb[1]} width={vb[2]} height={vb[3]} fill="var(--sea-soft)" />
        {/* 해안선: 바다색 두꺼운 테두리를 먼저 깔아 섬 윤곽을 만듭니다 */}
        <path d={ALL_D} fill="var(--surface)" stroke="var(--sea)" strokeOpacity=".45" strokeWidth={5 * k} strokeLinejoin="round" />

        {Object.entries(DONGS).map(([rid, dongs]) => {
          const h = health?.[rid];
          const on = selected === rid;
          const fill = h ? scoreColor(h.score) : on ? 'var(--accent)' : 'var(--surface)';
          const fillOpacity = h ? 0.28 : on ? 0.22 : 1;
          const r = byId[rid];
          return (
            <g key={rid} className={onSelect ? 'map-region' : undefined}
               onClick={onSelect ? () => onSelect(r) : undefined}
               role={onSelect ? 'button' : undefined} tabIndex={onSelect ? 0 : undefined}
               onKeyDown={onSelect ? (e) => (e.key === 'Enter' || e.key === ' ') && onSelect(r) : undefined}
               aria-label={onSelect ? `${r.name} 선택` : undefined}>
              {dongs.map((g) => (
                <path key={g.name} d={g.d} fill={fill} fillOpacity={fillOpacity}
                      stroke="var(--line)" strokeWidth={0.6 * k} strokeLinejoin="round">
                  <title>{g.name}</title>
                </path>
              ))}
            </g>
          );
        })}
        {/* 지역(읍면 묶음) 경계 강조 */}
        {Object.entries(DONGS).map(([rid, dongs]) => (
          <path key={rid} d={dongs.map((g) => g.d).join('')} fill="none" pointerEvents="none"
                stroke={selected === rid ? 'var(--accent)' : 'var(--muted)'} strokeOpacity={selected === rid ? 1 : 0.35}
                strokeWidth={(selected === rid ? 2 : 0.9) * k} strokeLinejoin="round" />
        ))}

        {/* 한라산 */}
        <g transform={`translate(${HALLA.x} ${HALLA.y}) scale(${k})`} aria-hidden="true" pointerEvents="none">
          <path d="M-14 7 L0 -9 L14 7 Z" fill="var(--surface-2)" stroke="var(--muted)" strokeWidth="1" />
          <text y="21" textAnchor="middle" fontSize="12" fill="var(--muted)">한라산 1,947m</text>
        </g>

        {flows?.map((f, i) => {
          const a = byId[f.from], b = byId[f.to];
          const mx = (a.x + b.x) / 2, my = Math.min(a.y, b.y) - 40;
          return <path key={i} d={`M${a.x},${a.y} Q${mx},${my} ${b.x},${b.y}`} fill="none" stroke="var(--accent)" strokeOpacity=".8"
                       strokeWidth={1 + f.count / 120} strokeDasharray="5 4" pointerEvents="none" />;
        })}

        {REGIONS.map((r) => {
          const h = health?.[r.id];
          const on = selected === r.id;
          if (stops?.length && !on) {
            return <text key={r.id} x={r.x} y={r.y} textAnchor="middle" fontSize={13 * k} fill="var(--muted)" pointerEvents="none">{r.name}</text>;
          }
          return (
            <g key={r.id} pointerEvents="none">
              {h ? (
                <>
                  <circle cx={r.x} cy={r.y} r={9 + h.visits / 130} fill="var(--surface)" stroke={scoreColor(h.score)} strokeWidth="2" />
                  <text x={r.x} y={r.y + 4} textAnchor="middle" fontSize="14" fontWeight="700" fill="var(--ink)" fontFamily="var(--font-mono)">{h.score}</text>
                  <text x={r.x} y={r.y + 22 + h.visits / 130} textAnchor="middle" fontSize="13" fill="var(--ink)" stroke="var(--surface)" strokeWidth="3" paintOrder="stroke">{r.name}</text>
                </>
              ) : (
                <text x={r.x} y={r.y + 4 * k} textAnchor="middle" fontSize={(on ? 18 : 14) * k} fontWeight={on ? 700 : 500}
                      fill={on ? 'var(--accent)' : 'var(--ink)'} stroke="var(--surface)" strokeWidth={3 * k} paintOrder="stroke">{r.name}</text>
              )}
            </g>
          );
        })}

        {stops && stops.length > 1 && (
          <polyline points={stops.map((s) => `${s.x},${s.y}`).join(' ')} fill="none" stroke="var(--accent)" strokeWidth={2.5 * k} strokeLinejoin="round" pointerEvents="none" />
        )}
        {stops?.map((s, i) => (
          <g key={s.id} pointerEvents="none">
            <circle cx={s.x} cy={s.y} r={11 * k} fill="var(--accent)" stroke="var(--surface)" strokeWidth={2 * k} />
            <text x={s.x} y={s.y + 4 * k} textAnchor="middle" fontSize={11 * k} fontWeight="700" fill="var(--accent-ink)">{i + 1}</text>
            <text x={s.x + (i % 2 ? -15 : 15) * k} y={s.y + 4 * k} textAnchor={i % 2 ? 'end' : 'start'} fontSize={13 * k} fill="var(--ink)" stroke="var(--surface)" strokeWidth={3 * k} paintOrder="stroke">{s.name}</text>
          </g>
        ))}

        {origin && !stops?.length && (
          <g transform={`translate(${origin.x} ${origin.y + 14}) scale(${k})`} pointerEvents="none">
            <circle r="14" fill="var(--sea)" fillOpacity=".2" />
            <circle r="5" fill="var(--sea)" stroke="var(--surface)" strokeWidth="2" />
          </g>
        )}
      </svg>
    </div>
  );
}
