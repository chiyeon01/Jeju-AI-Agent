import { useEffect, useState } from 'react';
import { LineChart, Stars } from '../../components/Charts.jsx';
import { getOwnerDashboard, askOwnerAgent, registerAction, OWNER_SUGGESTED_QUESTIONS } from '../../api/client.js';
import { useAuth } from '../../auth/AuthContext.jsx';
import MyReviews from './MyReviews.jsx';

function Indicator({ m }) {
  const cls = !m.delta ? '' : (m.delta > 0) === m.good ? 'up' : 'down';
  return (
    <div className="card metric stack" style={{ gap: 4 }}>
      <span className="label">{m.name}</span>
      <span className="v num">{m.value}<small>{m.unit}</small></span>
      <span className={`small num ${cls}`}>{m.delta ? `${m.delta > 0 ? '▲' : '▼'} ${Math.abs(m.delta)} 지난달 대비` : '변화 없음'}</span>
    </div>
  );
}

export default function OwnerDashboard() {
  const { user } = useAuth();
  const [d, setD] = useState(null);
  const [dashErr, setDashErr] = useState('');
  const [chat, setChat] = useState([]);
  const [q, setQ] = useState('');
  const [asking, setAsking] = useState(false);
  const [action, setAction] = useState('');
  const [saved, setSaved] = useState([]);

  // 상권 지표 대시보드는 지표가 준비된 매장만 열립니다. 아니어도 내 가게 별점·리뷰는 볼 수 있어요
  useEffect(() => { getOwnerDashboard().then(setD).catch((e) => setDashErr(e.message)); }, []);

  const ask = async (question) => {
    const text = (question ?? q).trim();
    if (!text) return;
    setQ('');
    setChat((c) => [...c, { from: 'me', text }]);
    setAsking(true);
    const r = await askOwnerAgent(text);
    setAsking(false);
    setChat((c) => [...c, { from: 'ai', text: r.answer }]);
  };

  const submitAction = async (e) => {
    e.preventDefault();
    if (!action.trim()) return;
    await registerAction({ kind: '메뉴·이벤트', title: action });
    setSaved((s) => [action, ...s]);
    setAction('');
  };

  if (!d) {
    return (
      <main className="page stack" style={{ gap: 20 }}>
        <h1>{user?.name || '내 가게'}</h1>
        <MyReviews />
        <p className="note">{dashErr ? `상권 지표: ${dashErr}` : '상권 지표를 불러오는 중…'}</p>
      </main>
    );
  }

  return (
    <main className="page stack" style={{ gap: 20 }}>
      <div>
        <span className="label">{d.store.dong} · {d.store.category}</span>
        <h1>{d.store.name}</h1>
      </div>

      <MyReviews />

      <section className="grid g2">
        <div className="card stack" style={{ gap: 8 }}>
          <span className="label">상권 건강 점수</span>
          <div className="score"><b className="num">{d.score.score}</b><span className="muted">/ 100</span></div>
          <div className="row">
            <span className={`pill ${d.score.delta >= 0 ? 'good' : 'bad'}`}>{d.score.delta >= 0 ? '▲' : '▼'} {Math.abs(d.score.delta)}점 지난주 대비</span>
            <span className="pill">같은 업종 {d.score.peers}곳 중 상위 {100 - d.score.percentile}%</span>
          </div>
        </div>
        <div className="card">
          <div className="head"><h3>주간 추이</h3><span className="small muted">최근 12주</span></div>
          <LineChart data={d.trend.values} labels={d.trend.labels} />
        </div>
      </section>

      <section className="card stack">
        <div className="head" style={{ marginBottom: 0 }}><h3>이번 주 AI 제안</h3><span className="small muted">{d.report.week}</span></div>
        <p>{d.report.summary}</p>
        <div className="grid g3">
          {d.report.actions.map((a) => (
            <div key={a.title} className="stack" style={{ gap: 4, background: 'var(--surface-2)', borderRadius: 12, padding: 14 }}>
              <strong>{a.title}</strong>
              <span className="small muted">{a.why}</span>
              <span className="pill" style={{ alignSelf: 'flex-start' }}>{a.impact}</span>
            </div>
          ))}
        </div>
      </section>

      <section className="grid g3">
        {d.indicators.map((m) => <Indicator key={m.key} m={m} />)}
      </section>

      <section className="grid g2" style={{ alignItems: 'start' }}>
        <div className="card stack">
          <h3>리뷰 주제별 반응</h3>
          {[...d.topics].sort((a, b) => a.pos - b.pos).map((t) => (
            <div key={t.topic} className="stack" style={{ gap: 4 }}>
              <div className="row between small"><span>{t.topic} {t.pos < 60 && <span className="pill bad">개선 필요</span>}</span><span className="num muted">긍정 {t.pos}% · {t.mentions}건</span></div>
              <div className="bar"><span style={{ width: `${t.pos}%`, background: t.pos < 60 ? 'var(--bad)' : 'var(--sky)' }} /></div>
            </div>
          ))}
          <h3 style={{ marginTop: 8 }}>최근 리뷰</h3>
          {d.reviews.map((r) => (
            <div key={r.at} className="stack" style={{ gap: 2, borderTop: '1px solid var(--line)', paddingTop: 10 }}>
              <div className="row between small"><Stars value={r.stars} /><span className="muted num">{r.at}</span></div>
              <p className="small">{r.text}</p>
            </div>
          ))}
        </div>

        <div className="stack">
          <div className="card">
            <h3 style={{ marginBottom: 10 }}>AI에게 물어보기</h3>
            <div className="chat" aria-live="polite">
              {chat.length === 0 && <div className="bubble ai">가게 지표에 대해 궁금한 점을 물어보세요.</div>}
              {chat.map((m, i) => <div key={i} className={`bubble ${m.from}`}>{m.text}</div>)}
              {asking && <div className="bubble ai muted">확인하는 중…</div>}
            </div>
            <div className="chips" style={{ marginTop: 10 }}>
              {OWNER_SUGGESTED_QUESTIONS.map((s) => <button key={s} type="button" className="chip" onClick={() => ask(s)}>{s}</button>)}
            </div>
            <form className="chat-input" onSubmit={(e) => { e.preventDefault(); ask(); }}>
              <input className="input" value={q} onChange={(e) => setQ(e.target.value)} placeholder="예: 평일 저녁 손님을 늘리려면?" aria-label="질문" />
              <button className="btn primary" type="submit">질문</button>
            </form>
          </div>
          <form className="card stack" onSubmit={submitAction}>
            <div>
              <h3>메뉴·이벤트 등록</h3>
              <p className="small muted">등록하면 관광객 코스 추천 문구에 반영돼요.</p>
            </div>
            <input className="input" value={action} onChange={(e) => setAction(e.target.value)} placeholder="예: 17~19시 커플 세트" aria-label="등록할 내용" />
            <button className="btn primary" type="submit" disabled={!action.trim()}>등록하기</button>
            {saved.map((s, i) => <div key={i} className="row between small"><span>{s}</span><span className="pill good">등록됨</span></div>)}
          </form>
        </div>
      </section>
    </main>
  );
}
