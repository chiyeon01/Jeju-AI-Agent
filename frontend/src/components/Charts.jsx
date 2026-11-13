// 작은 차트 모음: 스파크라인, 점수 게이지, 별점

export function Sparkline({ data, width = 120, height = 36, color = 'var(--sea)' }) {
  if (!data?.length) return null;
  const min = Math.min(...data), max = Math.max(...data);
  const span = max - min || 1;
  const pad = 4;
  const pts = data.map((v, i) => [
    pad + (i * (width - pad * 2)) / (data.length - 1),
    height - pad - ((v - min) / span) * (height - pad * 2),
  ]);
  const line = pts.map((p) => p.join(',')).join(' ');
  const area = `${pad},${height - pad} ${line} ${width - pad},${height - pad}`;
  const last = pts[pts.length - 1];
  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} aria-hidden="true">
      <polygon points={area} fill={color} fillOpacity=".12" />
      <polyline points={line} fill="none" stroke={color} strokeWidth="1.8" strokeLinejoin="round" strokeLinecap="round" />
      <circle cx={last[0]} cy={last[1]} r="3" fill={color} />
    </svg>
  );
}

export function LineChart({ data, labels, height = 160 }) {
  const W = 560, H = height, L = 32, R = 28, T = 12, B = 24;
  const min = Math.floor((Math.min(...data) - 5) / 10) * 10;
  const max = Math.ceil((Math.max(...data) + 5) / 10) * 10;
  const x = (i) => L + (i * (W - L - R)) / (data.length - 1);
  const y = (v) => T + (1 - (v - min) / (max - min)) * (H - T - B);
  const ticks = [];
  for (let v = min; v <= max; v += 10) ticks.push(v);
  const line = data.map((v, i) => `${x(i)},${y(v)}`).join(' ');
  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" role="img" aria-label="주간 상권 건강 점수 추이">
      {ticks.map((t) => (
        <g key={t}>
          <line x1={L} x2={W - R} y1={y(t)} y2={y(t)} stroke="var(--line)" strokeDasharray="2 4" />
          <text x={L - 8} y={y(t) + 4} textAnchor="end" fontSize="10" fill="var(--muted)" fontFamily="var(--font-mono)">{t}</text>
        </g>
      ))}
      <polygon points={`${x(0)},${H - B} ${line} ${x(data.length - 1)},${H - B}`} fill="var(--accent)" fillOpacity=".1" />
      <polyline points={line} fill="none" stroke="var(--accent)" strokeWidth="2.2" strokeLinejoin="round" />
      {data.map((v, i) => (
        <circle key={i} cx={x(i)} cy={y(v)} r={i === data.length - 1 ? 4.5 : 2.5} fill={i === data.length - 1 ? 'var(--accent)' : 'var(--surface)'} stroke="var(--accent)" strokeWidth="1.5" />
      ))}
      {labels?.map((lb, i) => (i % 2 === 1 || i === labels.length - 1) && (
        <text key={i} x={x(i)} y={H - 6} textAnchor="middle" fontSize="10" fill="var(--muted)">{lb}</text>
      ))}
    </svg>
  );
}

export function Gauge({ value, size = 168, label = '상권 건강 점수' }) {
  const r = size / 2 - 14;
  const c = 2 * Math.PI * r;
  const arc = c * 0.75; // 270도
  const color = value >= 70 ? 'var(--good)' : value >= 55 ? 'var(--warn)' : 'var(--bad)';
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} role="img" aria-label={`${label} ${value}점`}>
      <g transform={`rotate(135 ${size / 2} ${size / 2})`}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--surface-2)" strokeWidth="14" strokeDasharray={`${arc} ${c}`} strokeLinecap="round" />
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={color} strokeWidth="14" strokeDasharray={`${(arc * value) / 100} ${c}`} strokeLinecap="round" />
      </g>
      <text x="50%" y="50%" textAnchor="middle" fontSize="44" fontFamily="var(--font-mono)" fill="var(--ink)" dy="8">{value}</text>
      <text x="50%" y="50%" textAnchor="middle" fontSize="12" fill="var(--muted)" dy="32">/ 100</text>
    </svg>
  );
}

export function Stars({ value, onChange, size }) {
  if (!onChange) {
    return (
      <span className="stars static" aria-label={`별점 ${value}점`}>
        {[1, 2, 3, 4, 5].map((n) => <span key={n} className={n <= value ? 'on' : ''}>★</span>)}
      </span>
    );
  }
  return (
    <span className="stars" role="radiogroup" aria-label="별점">
      {[1, 2, 3, 4, 5].map((n) => (
        <button key={n} type="button" role="radio" aria-checked={value === n} aria-label={`${n}점`}
                className={n <= value ? 'on' : ''} style={size ? { fontSize: size } : undefined} onClick={() => onChange(n)}>★</button>
      ))}
    </span>
  );
}
