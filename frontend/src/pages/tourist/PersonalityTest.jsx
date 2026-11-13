import { useState } from 'react';
import { QUESTIONS, COMPANIONS, TRANSPORTS, BUDGETS } from '../../mock/tourist.js';
import { analyzeProfile } from '../../api/client.js';

const SAMPLE = { 0: 'b', 1: 'a', 2: 'b', 3: 'a', 4: 'a', 5: 'a', 6: 'b', 7: 'b', 8: 'a', 9: 'a', 10: 'b', 11: 'a' };

export default function PersonalityTest({ onDone }) {
  const [i, setI] = useState(0);
  const [answers, setAnswers] = useState({});
  const [extra, setExtra] = useState({ companion: '연인', transport: '렌터카', budget: '5~10만원', startTime: '15:00', hours: 5 });
  const [loading, setLoading] = useState(false);
  const total = QUESTIONS.length;
  const inExtra = i >= total;

  const choose = (v) => {
    setAnswers((a) => ({ ...a, [i]: v }));
    setTimeout(() => setI((n) => n + 1), 160);
  };

  const finish = async (ans = answers) => {
    setLoading(true);
    const p = await analyzeProfile(ans, extra);
    setLoading(false);
    onDone(p);
  };

  if (inExtra) {
    return (
      <section className="stack">
        <div>
          <p className="eyebrow">마지막 단계</p>
          <h2>누구와, 어떻게 움직이나요?</h2>
        </div>
        <div className="card stack">
          <div className="field">
            <label>동행</label>
            <div className="chips">
              {COMPANIONS.map((c) => <button key={c} type="button" className={`chip ${extra.companion === c ? 'on' : ''}`} onClick={() => setExtra({ ...extra, companion: c })}>{c}</button>)}
            </div>
          </div>
          <div className="field">
            <label>이동수단</label>
            <div className="chips">
              {TRANSPORTS.map((c) => <button key={c} type="button" className={`chip ${extra.transport === c ? 'on' : ''}`} onClick={() => setExtra({ ...extra, transport: c })}>{c}</button>)}
            </div>
          </div>
          <div className="field">
            <label>1인 예산</label>
            <div className="chips">
              {BUDGETS.map((c) => <button key={c} type="button" className={`chip ${extra.budget === c ? 'on' : ''}`} onClick={() => setExtra({ ...extra, budget: c })}>{c}</button>)}
            </div>
          </div>
          <div className="grid g2">
            <div className="field">
              <label htmlFor="start-time">출발 시각</label>
              <input id="start-time" type="time" className="input" value={extra.startTime} onChange={(e) => setExtra({ ...extra, startTime: e.target.value })} />
            </div>
            <div className="field">
              <label htmlFor="hours">이용 시간</label>
              <select id="hours" className="select" value={extra.hours} onChange={(e) => setExtra({ ...extra, hours: Number(e.target.value) })}>
                {[3, 4, 5, 6, 8].map((h) => <option key={h} value={h}>{h}시간</option>)}
              </select>
            </div>
          </div>
        </div>
        <div className="row" style={{ justifyContent: 'space-between' }}>
          <button className="btn ghost" onClick={() => setI(total - 1)}>이전</button>
          <button className="btn primary" onClick={() => finish()} disabled={loading}>{loading ? '성향 분석 중…' : '내 여행 유형 보기'}</button>
        </div>
      </section>
    );
  }

  const q = QUESTIONS[i];
  return (
    <section className="question">
      <div className="row" style={{ justifyContent: 'space-between' }}>
        <span className="qnum">Q{String(i + 1).padStart(2, '0')} / {total}</span>
        <button className="btn ghost sm" onClick={() => { setAnswers(SAMPLE); finish(SAMPLE); }} disabled={loading}>
          {loading ? '분석 중…' : '예시 응답으로 건너뛰기'}
        </button>
      </div>
      <div className="bar" aria-hidden="true"><span style={{ width: `${(i / total) * 100}%`, background: 'var(--accent)' }} /></div>
      <h2>{q.q}</h2>
      <div className="answers">
        {['a', 'b'].map((k) => (
          <button key={k} type="button" className={`answer ${answers[i] === k ? 'on' : ''}`} onClick={() => choose(k)}>
            <span className="big" aria-hidden="true">{q[k].icon}</span>
            <span>{q[k].t}</span>
          </button>
        ))}
      </div>
      <div>
        <button className="btn ghost sm" onClick={() => setI((n) => Math.max(0, n - 1))} disabled={i === 0}>이전 문항</button>
      </div>
    </section>
  );
}
