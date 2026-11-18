// 여행 정보: 동행 · 이동 수단(여러 개) · 여행 시작·끝 시각(10분 단위)
// 성향은 그대로여도 시간과 이동 수단은 여행마다 달라서, 지난 유형으로 시작해도 이 단계부터 합니다.
import { useState } from 'react';
import { COMPANIONS, TRANSPORTS } from '../../mock/tourist.js';
import { tripHours } from '../../api/client.js';

export const DEFAULT_TRIP = { companion: '연인', transport: '자동차', transports: ['자동차'], startTime: '10:00', endTime: '18:00', hours: 8 };

// 06:00 ~ 23:50, 10분 간격
export const TIMES = Array.from({ length: (24 - 6) * 6 }, (_, i) => {
  const m = 6 * 60 + i * 10;
  return `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
});
const snap = (t) => TIMES.find((x) => x >= (t || '')) ?? TIMES[TIMES.length - 1];

/** 지난 프로필의 이동 수단(예전 '렌터카'·'대중교통' 포함)을 새 선택지로 */
function initialTransports(p) {
  const list = p.transports ?? String(p.transport || '').split(/[·,\s]+/).filter(Boolean);
  const mapped = list.map((t) => (t === '렌터카' ? '자동차' : t === '대중교통' ? '버스' : t)).filter((t) => TRANSPORTS.includes(t));
  return mapped.length ? [...new Set(mapped)] : DEFAULT_TRIP.transports;
}

export default function TripStep({ profile, onDone, onBack }) {
  const [companion, setCompanion] = useState(COMPANIONS.includes(profile.companion) ? profile.companion : DEFAULT_TRIP.companion);
  const [transports, setTransports] = useState(() => initialTransports(profile));
  const [startTime, setStart] = useState(snap(profile.startTime || DEFAULT_TRIP.startTime));
  const [endTime, setEnd] = useState(snap(profile.endTime || DEFAULT_TRIP.endTime));
  const toggle = (t) => setTransports((xs) => (xs.includes(t) ? xs.filter((x) => x !== t) : [...xs, t]));
  const bad = endTime <= startTime ? '여행 끝 시각은 시작 시각보다 늦어야 해요.' : !transports.length ? '이동 수단을 하나 이상 골라 주세요.' : '';
  const hours = tripHours(startTime, endTime);
  const span = (() => {
    const [a, b] = [startTime, endTime].map((t) => t.split(':').map(Number)).map(([h, m]) => h * 60 + m);
    const d = b - a;
    return d > 0 ? `${Math.floor(d / 60)}시간${d % 60 ? ` ${d % 60}분` : ''}` : '';
  })();

  const done = () => {
    if (bad) return;
    const ordered = TRANSPORTS.filter((t) => transports.includes(t));
    onDone({ ...profile, companion, transports: ordered, transport: ordered.join('·'), startTime, endTime, hours });
  };

  return (
    <section className="stack" style={{ gap: 28 }}>
      <div className="type-line"><span>내 유형 <b>{profile.name}</b></span><button className="btn ghost sm" onClick={onBack}>다시 테스트</button></div>
      <h1 style={{ fontSize: '1.5rem' }}>이번 여행은 어떻게 다니나요?</h1>
      <div className="field"><span>누구와 함께하나요?</span>
        <div className="chips" role="radiogroup" aria-label="동행">
          {COMPANIONS.map((c) => <button key={c} type="button" role="radio" aria-checked={companion === c} className={`chip ${companion === c ? 'on' : ''}`} onClick={() => setCompanion(c)}>{c}</button>)}
        </div>
      </div>
      <div className="field"><span>이동 수단 <span className="muted" style={{ fontWeight: 400 }}>여러 개 고를 수 있어요</span></span>
        <div className="chips" role="group" aria-label="이동 수단">
          {TRANSPORTS.map((t) => <button key={t} type="button" aria-pressed={transports.includes(t)} className={`chip ${transports.includes(t) ? 'on' : ''}`} onClick={() => toggle(t)}>{t}</button>)}
        </div>
      </div>
      <div className="field"><span>여행 시간</span>
        <div className="grid g2" style={{ gap: 8 }}>
          <select className="select" aria-label="여행 시작" value={startTime} onChange={(e) => setStart(e.target.value)}>
            {TIMES.map((t) => <option key={t} value={t}>{t} 시작</option>)}
          </select>
          <select className="select" aria-label="여행 끝" value={endTime} onChange={(e) => setEnd(e.target.value)}>
            {TIMES.map((t) => <option key={t} value={t}>{t} 끝</option>)}
          </select>
        </div>
        {bad ? <p className="error" role="alert">{bad}</p> : <p className="small muted">총 {span}</p>}
      </div>
      <div className="cta-bar sticky">
        <span />
        <button className="btn primary lg" disabled={!!bad} onClick={done}>다음</button>
      </div>
    </section>
  );
}
