// 지역 특색 그림 (인라인 SVG, 외부 이미지 없음). art 종류마다 간단한 풍경을 그립니다.
export default function RegionArt({ info, title }) {
  const { from, to, accent, art } = info;
  const id = `g-${art}`;
  const sea = <path d="M0 120 Q40 112 80 120 T160 120 T240 120 T320 120 V160 H0Z" fill="#ffffff" opacity=".35" />;
  const scenes = {
    sunset: <>
      <circle cx="210" cy="112" r="34" fill="#FFE08A" />
      <rect x="0" y="112" width="320" height="48" fill={accent} opacity=".35" />
      {sea}
      <path d="M40 110 h30 l-6 8 h-18z" fill="#3b3b3b" opacity=".55" />
    </>,
    city: <>
      <circle cx="260" cy="40" r="16" fill="#FFF3C4" />
      {[[20, 70, 34], [60, 50, 30], [96, 80, 26], [128, 40, 36], [170, 64, 28], [204, 56, 34]].map(([x, y, w], i) => (
        <rect key={i} x={x} y={y} width={w} height={130 - y} rx="3" fill={accent} opacity={0.45 + (i % 3) * 0.15} />
      ))}
      <rect x="0" y="128" width="320" height="32" fill="#ffffff" opacity=".4" />
    </>,
    island: <>
      <circle cx="60" cy="40" r="18" fill="#FFF6C8" />
      <rect x="0" y="96" width="320" height="64" fill={accent} opacity=".35" />
      <ellipse cx="220" cy="98" rx="48" ry="16" fill="#3E7D5A" opacity=".75" />
      {sea}
    </>,
    hills: <>
      <circle cx="250" cy="42" r="16" fill="#FFF6C8" />
      <path d="M0 130 Q60 60 120 120 Q170 40 230 118 Q270 80 320 120 V160 H0Z" fill={accent} opacity=".6" />
      <path d="M0 140 Q80 110 160 138 T320 136 V160 H0Z" fill="#ffffff" opacity=".35" />
    </>,
    cliff: <>
      <circle cx="70" cy="40" r="16" fill="#FFF6C8" />
      {[0, 1, 2, 3, 4, 5, 6].map((i) => <rect key={i} x={190 + i * 14} y={70 + (i % 3) * 8} width="12" height="80" fill={accent} opacity=".7" />)}
      <rect x="0" y="118" width="190" height="42" fill="#ffffff" opacity=".35" />
      {sea}
    </>,
    tangerine: <>
      <path d="M0 140 Q160 100 320 140 V160 H0Z" fill="#6E9E4F" opacity=".6" />
      {[[60, 70], [110, 92], [170, 64], [230, 88], [280, 60]].map(([x, y], i) => (
        <g key={i}><circle cx={x} cy={y} r="18" fill="#FF9F1C" /><ellipse cx={x + 6} cy={y - 18} rx="8" ry="4" fill="#3E7D3A" /></g>
      ))}
    </>,
    waves: <>
      <circle cx="250" cy="40" r="16" fill="#FFF6C8" />
      {[90, 108, 126, 144].map((y, i) => (
        <path key={y} d={`M0 ${y} Q40 ${y - 10} 80 ${y} T160 ${y} T240 ${y} T320 ${y}`} stroke={i % 2 ? '#ffffff' : accent} strokeWidth="6" fill="none" opacity=".7" />
      ))}
    </>,
    peak: <>
      <circle cx="70" cy="70" r="22" fill="#FFD27A" />
      <path d="M150 130 L180 62 Q220 52 260 62 L290 130Z" fill={accent} opacity=".8" />
      <path d="M182 64 Q220 74 258 64" stroke="#ffffff" strokeWidth="3" fill="none" opacity=".6" />
      {sea}
    </>,
    forest: <>
      <path d="M0 132 Q90 100 180 130 T320 128 V160 H0Z" fill={accent} opacity=".35" />
      {[30, 70, 110, 150, 190, 230, 270].map((x, i) => (
        <path key={x} d={`M${x} ${130 - (i % 3) * 8} l18 -${56 + (i % 2) * 14} l18 ${56 + (i % 2) * 14}z`} fill={accent} opacity={0.55 + (i % 3) * 0.15} />
      ))}
    </>,
    beach: <>
      <circle cx="260" cy="40" r="16" fill="#FFF6C8" />
      <path d="M0 100 Q60 90 120 100 T240 98 T320 100 V160 H0Z" fill={accent} opacity=".45" />
      <path d="M0 130 Q100 118 200 132 T320 128 V160 H0Z" fill="#FFF1D0" />
      <path d="M40 92 Q70 50 100 92Z" fill="#3E7D5A" opacity=".7" />
    </>,
  };
  return (
    <svg className="region-art" viewBox="0 20 320 125" preserveAspectRatio="xMidYMid slice" role="img" aria-label={title}>
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={from} /><stop offset="1" stopColor={to} /></linearGradient>
      </defs>
      <rect width="320" height="160" fill={`url(#${id})`} />
      {scenes[art]}
    </svg>
  );
}
