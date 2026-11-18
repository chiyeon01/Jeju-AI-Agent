import { useCallback, useEffect, useRef, useState } from 'react';
import { useBackHandler } from '../../components/BackButton.jsx';
import { QUESTIONS } from '../../mock/tourist.js';
import { DEFAULT_TRIP } from './TripStep.jsx';
import { analyzeProfile } from '../../api/client.js';

const SAMPLE = { 0: 'a', 1: 'a', 2: 'b', 3: 'a', 4: 'a' };

export default function PersonalityTest({ onDone }) {
  const [i, setI] = useState(0);
  const [answers, setAnswers] = useState({});
  const [loading, setLoading] = useState(false);
  const total = QUESTIONS.length;
  // 왼쪽 위 뒤로가기: 이전 문항으로
  const prev = useCallback(() => setI((n) => Math.max(0, n - 1)), []);
  useBackHandler(i > 0 ? prev : null);

  // 마지막 문항에 답하면 바로 분석합니다 (동행·이동 수단·시간은 다음 '여행 정보' 단계에서)
  // 분석 중에 화면을 떠나면 결과가 와도 다음 단계로 넘기지 않습니다
  const alive = useRef(true);
  useEffect(() => () => { alive.current = false; }, []);
  const lock = useRef(false); // 답을 누른 뒤 다음 문항으로 넘어가는 동안 두 번 눌림 방지
  const [err, setErr] = useState('');
  const finish = async (ans = answers) => {
    if (loading) return;
    setLoading(true); setErr('');
    try {
      const p = await analyzeProfile(ans, DEFAULT_TRIP);
      if (alive.current) onDone(p);
    } catch (e) {
      if (alive.current) { setErr(`분석하지 못했어요. 다시 시도해 주세요. (${e.message})`); setLoading(false); setI(total - 1); }
    }
  };
  const choose = (v) => {
    if (lock.current || loading) return;
    const next = { ...answers, [i]: v };
    setAnswers(next);
    if (i === total - 1) { setI(total); finish(next); return; }
    lock.current = true;
    setTimeout(() => { setI((n) => n + 1); lock.current = false; }, 150);
  };

  if (i >= total || (loading && !err)) return <div className="done-card"><div className="spinner" aria-hidden="true" /><p className="muted">내 여행 유형을 분석하는 중…</p></div>;

  const q = QUESTIONS[i];
  return (
    <section className="stack" style={{ gap: 28 }}>
      <div className="stack" style={{ gap: 8 }}>
        <span className="eyebrow num">질문 {i + 1}</span>
        <h1 className="quiz-q">{q.q}</h1>
      </div>
      {err && <p className="error" role="alert">{err}</p>}
      <div className="answers">
        {['a', 'b'].map((k) => (
          <button key={k} type="button" className={`answer ${answers[i] === k ? 'on' : ''}`} onClick={() => choose(k)}>
            <span className="big" aria-hidden="true">{q[k].icon}</span>
            <span>{q[k].t}</span>
          </button>
        ))}
      </div>
      <div className="row between">
        {i > 0 ? <button className="btn ghost sm" onClick={() => setI(i - 1)}>이전 문항</button> : <span />}
        <button className="btn ghost sm" onClick={() => finish(SAMPLE)} disabled={loading}>{loading ? '분석 중…' : '건너뛰고 예시로 보기'}</button>
      </div>
    </section>
  );
}
