import { useCallback, useState } from 'react';
import { useBackHandler } from '../../components/BackButton.jsx';
import { QUESTIONS, COMPANIONS, TRANSPORTS } from '../../mock/tourist.js';
import { analyzeProfile } from '../../api/client.js';

const SAMPLE = { 0: 'a', 1: 'a', 2: 'b', 3: 'a', 4: 'a' };

export default function PersonalityTest({ onDone }) {
  const [i, setI] = useState(0);
  const [answers, setAnswers] = useState({});
  const [extra, setExtra] = useState({ companion: '연인', transport: '렌터카', startTime: '15:00', hours: 5 });
  const [loading, setLoading] = useState(false);
  const total = QUESTIONS.length;
  // 왼쪽 위 뒤로가기: 이전 문항으로
  const prev = useCallback(() => setI((n) => Math.max(0, n - 1)), []);
  useBackHandler(i > 0 ? prev : null);

  const choose = (v) => {
    setAnswers((a) => ({ ...a, [i]: v }));
    setTimeout(() => setI((n) => n + 1), 150);
  };
  const finish = async (ans = answers) => {
    setLoading(true);
    onDone(await analyzeProfile(ans, extra));
  };

  if (i >= total) {
    const chips = (list, key) => (
      <div className="chips">
        {list.map((c) => <button key={c} type="button" className={`chip ${extra[key] === c ? 'on' : ''}`} onClick={() => setExtra({ ...extra, [key]: c })}>{c}</button>)}
      </div>
    );
    return (
      <section className="stack">
        <h2>누구와, 어떻게 움직이나요?</h2>
        <div className="card stack">
          <div className="field"><span>동행</span>{chips(COMPANIONS, 'companion')}</div>
          <div className="field"><span>이동수단</span>{chips(TRANSPORTS, 'transport')}</div>
          <div className="grid g2">
            <label className="field"><span>출발 시각</span>
              <input type="time" className="input" value={extra.startTime} onChange={(e) => setExtra({ ...extra, startTime: e.target.value })} />
            </label>
            <label className="field"><span>이용 시간</span>
              <select className="select" value={extra.hours} onChange={(e) => setExtra({ ...extra, hours: Number(e.target.value) })}>
                {[3, 4, 5, 6, 8].map((h) => <option key={h} value={h}>{h}시간</option>)}
              </select>
            </label>
          </div>
        </div>
        <div className="row between">
          <button className="btn ghost" onClick={() => setI(total - 1)}>이전</button>
          <button className="btn primary" onClick={() => finish()} disabled={loading}>{loading ? '분석 중…' : '내 여행 유형 보기'}</button>
        </div>
      </section>
    );
  }

  const q = QUESTIONS[i];
  return (
    <section className="stack">
      <div className="row between">
        <span className="label num">{i + 1} / {total}</span>
        <button className="btn ghost sm" onClick={() => finish(SAMPLE)} disabled={loading}>{loading ? '분석 중…' : '예시 응답으로 건너뛰기'}</button>
      </div>
      <h2>{q.q}</h2>
      <div className="answers">
        {['a', 'b'].map((k) => (
          <button key={k} type="button" className={`answer ${answers[i] === k ? 'on' : ''}`} onClick={() => choose(k)}>
            <span className="big" aria-hidden="true">{q[k].icon}</span>
            <span>{q[k].t}</span>
          </button>
        ))}
      </div>
      {i > 0 && <button className="btn ghost sm" style={{ alignSelf: 'flex-start' }} onClick={() => setI(i - 1)}>이전 문항</button>}
    </section>
  );
}
