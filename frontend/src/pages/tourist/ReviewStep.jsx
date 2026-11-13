import { useState } from 'react';
import { Link } from 'react-router-dom';
import { Stars } from '../../components/Charts.jsx';
import { submitReviews } from '../../api/client.js';

export default function ReviewStep({ profile, course, onRestart }) {
  // 방문 인증: 코스에 포함되고 해당 시간대 반경 내 있었던 장소만 평가 가능 (시연에서는 마지막 장소를 미인증으로 표시)
  const stops = (course?.stops || []).map((s, i, arr) => ({ ...s, verified: i < arr.length - 1 || arr.length <= 2 }));
  const [form, setForm] = useState(() => Object.fromEntries(stops.map((s) => [s.id, { stars: 0, text: '' }])));
  const [done, setDone] = useState(null);
  const [sending, setSending] = useState(false);

  const ready = stops.filter((s) => s.verified && form[s.id].stars > 0);

  const submit = async (e) => {
    e.preventDefault();
    setSending(true);
    const res = await submitReviews(ready.map((s) => ({ placeId: s.id, stars: form[s.id].stars, text: form[s.id].text, profile: profile.code })));
    setSending(false);
    setDone(res);
  };

  if (done?.skipped) {
    return (
      <section className="stack">
        <div className="card raised stack">
          <p className="eyebrow">평가 건너뜀</p>
          <h2>즐거운 여행이었길 바라요</h2>
          <p className="muted">이번 코스는 평가 없이 마쳤어요. 코스 선택 기록만 익명으로 인기 코스 집계에 쓰여요.</p>
          <div className="row">
            <button className="btn primary" onClick={onRestart}>새 코스 만들기</button>
            <Link className="btn" to="/">처음으로</Link>
          </div>
        </div>
      </section>
    );
  }

  if (done) {
    return (
      <section className="stack">
        <div className="card raised stack">
          <p className="eyebrow">평가 {done.accepted}건 저장됨</p>
          <h2>고마워요! 남긴 평가가 이렇게 쓰여요</h2>
          <ul className="stack" style={{ margin: 0, paddingLeft: '1.2em', gap: 8 }}>
            <li>각 매장의 <b>고객 만족 지수</b>와 <b>성향 적합도</b>가 바로 다시 계산돼 사장님 대시보드에 반영돼요.</li>
            <li><b>{profile.name}</b> 유형의 장소 선호 행렬이 갱신돼, 비슷한 성향의 다음 여행자 코스가 더 정확해져요.</li>
            <li>평가는 개인을 알아볼 수 없게 처리된 뒤 제주시 Main PC 통합 저장소에 쌓여요.</li>
          </ul>
          <div className="row">
            <button className="btn primary" onClick={onRestart}>새 코스 만들기</button>
          </div>
        </div>
      </section>
    );
  }

  return (
    <form className="stack" onSubmit={submit}>
      <div>
        <p className="eyebrow">방문 후 평가</p>
        <h2>오늘 다녀온 곳은 어땠나요?</h2>
        <p className="small muted" style={{ marginTop: 4 }}>별점과 한 줄 평만 남기면 돼요. 방문이 확인된 장소만 평가할 수 있어요.</p>
      </div>
      {stops.map((s) => (
        <fieldset key={s.id} className="card stack" style={{ gap: 10, opacity: s.verified ? 1 : .6 }} disabled={!s.verified}>
          <div className="row" style={{ justifyContent: 'space-between' }}>
            <div className="row" style={{ gap: 8 }}>
              <span className="num muted small">{s.at}</span>
              <strong>{s.name}</strong>
            </div>
            {s.verified
              ? <span className="pill good">✓ 방문 인증 · 반경 150m</span>
              : <span className="pill">방문 확인 안 됨</span>}
          </div>
          <Stars value={form[s.id].stars} onChange={(n) => setForm({ ...form, [s.id]: { ...form[s.id], stars: n } })} />
          <input id={`review-${s.id}`} className="input" maxLength={100} placeholder="한 줄 평 (선택, 100자 이내)"
                 value={form[s.id].text} onChange={(e) => setForm({ ...form, [s.id]: { ...form[s.id], text: e.target.value } })} />
        </fieldset>
      ))}
      <div className="row" style={{ justifyContent: 'space-between' }}>
        <span className="small muted">계정당 하루 평가 횟수가 제한돼요.</span>
        <div className="row">
          <button className="btn ghost" type="button" onClick={() => setDone({ skipped: true })} disabled={sending}>평가 안 하기</button>
          <button className="btn primary" type="submit" disabled={!ready.length || sending}>{sending ? '보내는 중…' : `평가 ${ready.length}건 보내기`}</button>
        </div>
      </div>
    </form>
  );
}
