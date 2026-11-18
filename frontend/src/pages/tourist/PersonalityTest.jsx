import { useCallback, useState } from 'react';
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
  const finish = async (ans = answers) => {
    setLoading(true);
    onDone(await analyzeProfile(ans, DEFAULT_TRIP));
  };
  const choose = (v) => {
    const next = { ...answers, [i]: v };
    setAnswers(next);
    if (i === total - 1) finish(next);
    else setTimeout(() => setI((n) => n + 1), 150);
  };

  if (i >= total) return <div className="done-card"><p className="muted">내 여행 유형을 분석하는 중…</p></div>;

  const q = QUESTIONS[i];
  return (
    <section className="stack" style={{ gap: 28 }}>
      <div className="stack" style={{ gap: 8 }}>
        <span className="eyebrow num">질문 {i + 1}</span>
        <h1 className="quiz-q">{q.q}</h1>
      </div>
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
