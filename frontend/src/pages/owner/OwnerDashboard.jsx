// 상권 주인 화면
// 처음 들어오면 내 가게(관광객 평점을 받은 가게)를 먼저 고르고, 연결된 뒤에
// ① 가게 지표 → ② 고객 분석 → ③ AI 개선 제안 → ④ 개선 조치 순서로 보여 줍니다 (MyReviews).
// 화면의 모든 값은 관광객이 실제로 남긴 별점·리뷰로 만듭니다.
import { useEffect, useState } from 'react';
import { getReviewTopics, askOwnerAgent, registerAction, OWNER_SUGGESTED_QUESTIONS } from '../../api/client.js';
import MyReviews from './MyReviews.jsx';

// 리뷰 주제별 반응: 백엔드 GPT 가 리뷰를 읽고 주제별 긍정률을 정리. 새 평가가 오면(reviewCount 변경) 다시 불러옵니다
function ReviewTopics({ reviewCount }) {
  const [t, setT] = useState(null);
  const [err, setErr] = useState('');
  useEffect(() => {
    let alive = true;
    setErr('');
    getReviewTopics().then((r) => alive && setT(r)).catch((e) => alive && setErr(e.message));
    return () => { alive = false; };
  }, [reviewCount]);
  const topics = [...(t?.topics ?? [])].sort((a, b) => a.pos - b.pos);
  return (
    <div className="stack" style={{ gap: 4 }}>
      <div className="row between">
        <span className="label">리뷰 주제별 반응 <span style={{ fontWeight: 400 }}>· 낮은 순</span></span>
        {t && <span className="small muted">{t.source === 'gpt' ? 'GPT' : '규칙 기반'} · 리뷰 {t.textCount}건</span>}
      </div>
      {err && <p className="note">{err}</p>}
      {!t && !err && <div className="skeleton" style={{ paddingTop: 8 }}><i /><i /><i /></div>}
      {t && topics.length === 0 && <p className="small muted">아직 분석할 리뷰 글이 없어요. 관광객이 한 줄 평을 남기면 주제별로 정리해 드려요.</p>}
      <div>
        {topics.map((x) => (
          <div key={x.topic} className={`topic ${x.pos < 60 ? 'weak' : ''}`}>
            <div className="row between small">
              <b>{x.topic}{x.pos < 60 && <span className="pill bad" style={{ marginLeft: 6 }}>개선 필요</span>}</b>
              <span className="num muted">긍정 <b style={{ color: x.pos < 60 ? 'var(--bad)' : 'var(--ink)' }}>{x.pos}%</b> · {x.mentions}건</span>
            </div>
            <div className="bar"><span style={{ width: `${x.pos}%`, background: x.pos < 60 ? 'var(--bad)' : 'var(--brand)' }} /></div>
            {x.summary && <span className="small muted">{x.summary}</span>}
          </div>
        ))}
      </div>
    </div>
  );
}

function AskAgent() {
  const [chat, setChat] = useState([]);
  const [q, setQ] = useState('');
  const [asking, setAsking] = useState(false);
  const ask = async (question) => {
    const text = (question ?? q).trim();
    if (!text) return;
    setQ('');
    setChat((c) => [...c, { from: 'me', text }]);
    setAsking(true);
    try {
      const r = await askOwnerAgent(text);
      setChat((c) => [...c, { from: 'ai', text: r.answer }]);
    } catch (e) {
      setChat((c) => [...c, { from: 'ai', text: e.message }]);
    } finally { setAsking(false); }
  };
  return (
    <div className="chat-card">
      <span className="label">AI에게 직접 물어보기</span>
      {chat.length > 0 && (
        <div className="chat" aria-live="polite">
          {chat.map((m, i) => <div key={i} className={`bubble ${m.from}`}>{m.text}</div>)}
          {asking && <div className="bubble ai muted">내 가게 리뷰를 확인하는 중…</div>}
        </div>
      )}
      <div className="chips">
        {OWNER_SUGGESTED_QUESTIONS.map((s) => <button key={s} type="button" className="chip" disabled={asking} onClick={() => ask(s)}>{s}</button>)}
      </div>
      <form className="chat-input" onSubmit={(e) => { e.preventDefault(); ask(); }}>
        <input className="input" value={q} onChange={(e) => setQ(e.target.value)} placeholder="예: 평일 저녁 손님을 늘리려면?" aria-label="질문" />
        <button className="btn primary" type="submit" disabled={asking || !q.trim()}>질문</button>
      </form>
    </div>
  );
}

function ActionForm() {
  const [action, setAction] = useState('');
  const [saved, setSaved] = useState([]);
  const [err, setErr] = useState('');
  const submit = async (e) => {
    e.preventDefault();
    if (!action.trim()) return;
    setErr('');
    try {
      await registerAction({ kind: '메뉴·이벤트', title: action });
      setSaved((s) => [{ title: action, at: new Date() }, ...s]);
      setAction('');
    } catch (x) { setErr(x.message); }
  };
  return (
    <div className="split">
      <form className="stack" style={{ gap: 10 }} onSubmit={submit}>
        <label className="field"><span>새 메뉴·이벤트</span>
          <input className="input" value={action} onChange={(e) => setAction(e.target.value)} placeholder="예: 17~19시 커플 세트 10% 할인" />
        </label>
        {err && <p className="error">{err}</p>}
        <button className="btn primary" type="submit" disabled={!action.trim()} style={{ justifySelf: 'start' }}>등록하기</button>
      </form>
      <div className="stack" style={{ gap: 4 }}>
        <span className="label">이번에 등록한 조치</span>
        {saved.length === 0 ? <p className="small muted">AI 개선 제안을 보고 해 볼 일을 등록해 보세요.</p> : (
          <ul className="rows">
            {saved.map((s, i) => (
              <li key={i}><span className="grow"><span className="title">{s.title}</span><span className="sub">{s.at.toLocaleString('ko-KR', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' })} 등록</span></span><span className="pill good">효과 측정 중</span></li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}

export default function OwnerDashboard() {
  const [d, setD] = useState(undefined); // undefined=불러오는 중, null=가게 미연결
  const place = d?.place;
  return (
    <main className="page">
      <MyReviews
        onData={setD}
        topics={place ? <ReviewTopics key={place.id} reviewCount={d.summary.count} /> : null}
        ask={place ? <AskAgent key={place.id} /> : null}
        action={<ActionForm />}
      />
    </main>
  );
}
