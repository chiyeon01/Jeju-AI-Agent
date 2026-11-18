import { useState } from 'react';
import { Stars } from '../../components/Charts.jsx';
import { submitReviews } from '../../api/client.js';

const STAR_TEXT = ['', '별로예요', '아쉬워요', '보통이에요', '좋아요', '최고예요'];
// 한 줄 평 빠른 선택 (사장님 화면의 주제별 분석에 그대로 쓰입니다)
const QUICK = {
  good: ['친절해요', '분위기가 좋아요', '뷰가 좋아요', '맛있어요', '가격이 괜찮아요', '깨끗해요'],
  bad: ['웨이팅이 길어요', '가격이 비싸요', '불친절해요', '자리가 불편해요', '주차가 어려워요', '붐벼요'],
};

const quickFor = (n) => (n >= 4 ? QUICK.good : n <= 2 ? QUICK.bad : [...QUICK.good.slice(0, 3), ...QUICK.bad.slice(0, 3)]);

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
      const res = await submitReviews(ready.map((s) => ({ placeId: s.id, stars: form[s.id].stars, text: form[s.id].text, profile: profile?.code ?? /\(([A-Z]{4})\)/.exec(course?.type ?? '')?.[1] })));
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
      <div className="done-card">
        <h1>평가를 보냈어요</h1>
        <p className="muted">{done.accepted}곳의 평가가 가게 지표와 다음 여행자의 추천에 반영돼요.</p>
        <button className="btn primary lg" style={{ marginTop: 12 }} onClick={onRestart}>내 여행으로</button>
      </div>
    );
  }

  return (
    <form className="stack" style={{ gap: 0 }} onSubmit={submit}>
      <div style={{ paddingBottom: 12 }}>
        <h1 style={{ fontSize: '1.5rem' }}>다녀온 곳은 어땠나요?</h1>
        <p className="muted" style={{ marginTop: 6 }}>별점을 누른 곳만 보내요. 한 줄 평은 사장님께 큰 도움이 돼요.</p>
      </div>
      {stops.map((s) => (
        <div key={s.id} className="review-card">
          <div className="row between">
            <strong>{s.name}</strong>
            <Stars value={form[s.id].stars} onChange={(n) => edit(s.id, { stars: n })} />
          </div>
          {form[s.id].stars > 0 && (
            <>
              <span className="small brand-text" style={{ fontWeight: 600, marginTop: -6 }}>{STAR_TEXT[form[s.id].stars]}</span>
              <div className="chips">
                {quickFor(form[s.id].stars).map((t) => {
                  const on = form[s.id].text.includes(t);
                  return (
                    <button key={t} type="button" className={`chip sm ${on ? 'on' : ''}`} aria-pressed={on}
                      onClick={() => {
                        const parts = form[s.id].text.split(', ').filter(Boolean);
                        const next = on ? parts.filter((x) => x !== t) : [...parts, t];
                        edit(s.id, { text: next.join(', ').slice(0, 100) });
                      }}>{t}</button>
                  );
                })}
              </div>
              <input className="input" maxLength={100} placeholder="직접 남기기 (선택)" aria-label={`${s.name} 한 줄 평`}
                     value={form[s.id].text} onChange={(e) => edit(s.id, { text: e.target.value })} />
            </>
          )}
        </div>
      ))}
      {error && <p className="error" role="alert">{error}</p>}
      <div className="cta-bar sticky" style={{ marginTop: 16 }}>
        <button className="btn ghost" type="button" onClick={onRestart}>나중에 하기</button>
        <button className="btn primary lg" type="submit" disabled={!ready.length || sending}>{sending ? '보내는 중…' : ready.length ? `${ready.length}곳 평가 보내기` : '별점을 눌러 주세요'}</button>
      </div>
    </form>
  );
}
