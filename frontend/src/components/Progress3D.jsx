// 입체 진행 막대. 홈이 파인 듯한 바탕 위에 볼록하고 윤이 나는 막대가 차오릅니다.
//  value/max: 진행 정도, color: 막대 색 (기본 하늘색), label: 막대 위 왼쪽 글, showValue: 오른쪽 % 표시
//  size: 'sm' | 'md' | 'lg', active: true 면 줄무늬가 흘러갑니다 (작업 중 표시)
export default function Progress3D({ value = 0, max = 100, color, label, valueText, showValue = true, size = 'md', active = false }) {
  const pct = max > 0 ? Math.max(0, Math.min(100, (value / max) * 100)) : 0;
  return (
    <div className={`p3d ${size}${active ? ' active' : ''}`} style={color ? { '--p3d-color': color } : undefined}>
      {(label || showValue) && (
        <div className="p3d-top">
          {label && <span className="p3d-label">{label}</span>}
          {showValue && <span className="p3d-val num">{valueText ?? `${Math.round(pct)}%`}</span>}
        </div>
      )}
      <div className="p3d-track" role="progressbar" aria-valuemin={0} aria-valuemax={max} aria-valuenow={Math.round(value * 10) / 10} aria-label={typeof label === 'string' ? label : undefined}>
        <div className="p3d-fill" style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}
