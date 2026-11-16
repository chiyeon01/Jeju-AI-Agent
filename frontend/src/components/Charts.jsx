// 작은 차트: 선 그래프, 별점

export function LineChart({ data, labels, height = 160 }) {
  const W = 560, H = height, L = 30, R = 16, T = 12, B = 24;
  const min = Math.floor((Math.min(...data) - 5) / 10) * 10;
  const max = Math.ceil((Math.max(...data) + 5) / 10) * 10;
  const x = (i) => L + (i * (W - L - R)) / (data.length - 1);
  const y = (v) => T + (1 - (v - min) / (max - min)) * (H - T - B);
  const ticks = [];
  for (let v = min; v <= max; v += 10) ticks.push(v);
  const line = data.map((v, i) => `${x(i)},${y(v)}`).join(' ');
  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" role="img" aria-label="주간 점수 추이">
      {ticks.map((t) => (
        <g key={t}>
          <line x1={L} x2={W - R} y1={y(t)} y2={y(t)} stroke="var(--line)" />
          <text x={L - 8} y={y(t) + 4} textAnchor="end" fontSize="11" fill="var(--muted)">{t}</text>
        </g>
      ))}
      <polygon points={`${x(0)},${H - B} ${line} ${x(data.length - 1)},${H - B}`} fill="var(--sky)" fillOpacity=".25" />
      <polyline points={line} fill="none" stroke="var(--sky-deep)" strokeWidth="2.2" strokeLinejoin="round" />
      <circle cx={x(data.length - 1)} cy={y(data[data.length - 1])} r="4.5" fill="var(--sky-deep)" />
      {labels?.map((lb, i) => (i % 3 === 2 || i === labels.length - 1) && (
        <text key={i} x={x(i)} y={H - 6} textAnchor="middle" fontSize="11" fill="var(--muted)">{lb}</text>
      ))}
    </svg>
  );
}

export function Stars({ value, onChange }) {
  if (!onChange) {
    return (
      <span className="stars" aria-label={`별점 ${value}점`}>
        {[1, 2, 3, 4, 5].map((n) => <span key={n} className={n <= value ? 'on' : ''}>★</span>)}
      </span>
    );
  }
  return (
    <span className="stars" role="radiogroup" aria-label="별점">
      {[1, 2, 3, 4, 5].map((n) => (
        <button key={n} type="button" role="radio" aria-checked={value === n} aria-label={`${n}점`}
                className={n <= value ? 'on' : ''} onClick={() => onChange(n)}>★</button>
      ))}
    </span>
  );
}
