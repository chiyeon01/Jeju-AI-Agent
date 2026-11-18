import { useState } from 'react';
import { Stars } from '../../components/Charts.jsx';
import { submitReviews } from '../../api/client.js';

export default function ReviewStep({ course, profile, onRestart, onSent }) {
  const stops = course?.stops ?? [];
  const [form, setForm] = useState(() => Object.fromEntries(stops.map((s) => [s.id, { stars: 0, text: '' }])));
  const [done, setDone] = useState(null);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');
  const ready = stops.filter((s) => form[s.id].stars > 0);
  const edit = (id, v) => setForm({ ...form, [id]: { ...form[id], ...v } });

  const submit = async (e) => {
    e.preventDefault();
    setSending(true);
    try {
      const res = await submitReviews(ready.map((s) => ({ placeId: s.id, stars: form[s.id].stars, text: form[s.id].text, profile: profile.code })));
      onSent?.(ready.map((s) => ({ placeId: s.id, name: s.name, stars: form[s.id].stars, text: form[s.id].text })));
      setDone(res);
    } catch (err) {
      setError(err.message);
    } finally {
      setSending(false);
    }
  };

  if (done) {
    return (
      <div className="card raised done-card">
        <span className="big" aria-hidden="true">🍊</span>
        <h2>고마워요!</h2>
        <p className="muted">평가 {done.accepted}건이 저장됐어요.<br />가게 점수와 다음 여행자의 코스 추천에 반영돼요.</p>
        <button className="btn primary lg" onClick={onRestart}>내 기록 보기</button>
      </div>
    );
  }

  return (
    <form className="stack" onSubmit={submit}>
      <div className="stack" style={{ gap: 4 }}>
        <h2>오늘 다녀온 곳은 어땠나요?</h2>
        <p className="small muted">별점을 누른 곳만 보내요. 한 줄 평은 사장님께 큰 힘이 돼요.</p>
      </div>
      {stops.map((s, i) => (
        <div key={s.id} className={`card review-card ${form[s.id].stars ? 'rated' : ''}`}>
          <span className="no num" aria-hidden="true">{i + 1}</span>
          <div className="stack" style={{ gap: 10 }}>
            <div className="row between">
              <strong>{s.name}</strong>
              <Stars value={form[s.id].stars} onChange={(n) => edit(s.id, { stars: n })} />
            </div>
            <input className="input" maxLength={100} placeholder="한 줄 평 (선택)" aria-label={`${s.name} 한 줄 평`}
                   value={form[s.id].text} onChange={(e) => edit(s.id, { text: e.target.value })} />
          </div>
        </div>
      ))}
      {error && <p className="error" role="alert">{error}</p>}
      <div className="row between">
        <button className="btn ghost" type="button" onClick={onRestart}>건너뛰기</button>
        <button className="btn primary lg" type="submit" disabled={!ready.length || sending}>{sending ? '보내는 중…' : `평가 ${ready.length}건 보내기`}</button>
      </div>
    </form>
  );
}
