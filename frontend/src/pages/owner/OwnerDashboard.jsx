// 상권 주인 대시보드
// 처음 들어오면 내 가게(관광객 평점을 받은 가게)를 먼저 고르고, 연결된 뒤에만 아래 분석이 열립니다.
// 화면의 모든 값은 관광객이 앱에서 실제로 남긴 별점·리뷰로 만듭니다 (시연용 고정 데이터 없음).
import { useEffect, useState } from 'react';
import { getReviewTopics, askOwnerAgent, registerAction, OWNER_SUGGESTED_QUESTIONS } from '../../api/client.js';
import MyReviews from './MyReviews.jsx';

const KIND = { food: '식당', cafe: '카페', indoor: '실내 체험' };

// 리뷰 주제별 반응: 백엔드 GPT 가 프롬프트로 리뷰를 읽고 주제별 긍정률을 정리. 새 평가가 오면(reviewCount 변경) 다시 불러옵니다
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
    <div className="card stack">
      <div className="head" style={{ marginBottom: 0 }}>
        <h3>리뷰 주제별 반응</h3>
        {t && <span className="small muted">{t.source === 'gpt' ? 'GPT 분석' : '규칙 기반 분석'} · 리뷰 {t.textCount}건</span>}
      </div>
      {err && <p className="note">{err}</p>}
      {!t && !err && <p className="small muted">GPT가 리뷰를 읽고 있어요…</p>}
      {t && topics.length === 0 && <p className="small muted">아직 분석할 리뷰 글이 없어요. 관광객이 한 줄 평을 남기면 주제별로 정리해 드려요.</p>}
      {topics.map((x) => (
        <div key={x.topic} className="stack" style={{ gap: 4 }}>
          <div className="row between small">
            <span>{x.topic} {x.pos < 60 && <span className="pill bad">개선 필요</span>}</span>
            <span className="num muted">긍정 {x.pos}% · {x.mentions}건</span>
          </div>
          <div className="bar"><span style={{ width: `${x.pos}%`, background: x.pos < 60 ? 'var(--bad)' : 'var(--sky)' }} /></div>
          {x.summary && <span className="small muted">{x.summary}</span>}
        </div>
      ))}
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
    <div className="card">
      <h3 style={{ marginBottom: 10 }}>AI에게 물어보기</h3>
      <div className="chat" aria-live="polite">
        {chat.length === 0 && <div className="bubble ai">관광객 별점·리뷰에 대해 궁금한 점을 물어보세요.</div>}
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
  );
}

function ActionForm() {
  const [action, setAction] = useState('');
  const [saved, setSaved] = useState([]);
  const submit = async (e) => {
    e.preventDefault();
    if (!action.trim()) return;
    await registerAction({ kind: '메뉴·이벤트', title: action });
    setSaved((s) => [action, ...s]);
    setAction('');
  };
  return (
    <form className="card stack" onSubmit={submit}>
      <div>
        <h3>메뉴·이벤트 등록</h3>
        <p className="small muted">등록하면 관광객 코스 추천 문구에 반영돼요.</p>
      </div>
      <input className="input" value={action} onChange={(e) => setAction(e.target.value)} placeholder="예: 17~19시 커플 세트" aria-label="등록할 내용" />
      <button className="btn primary" type="submit" disabled={!action.trim()}>등록하기</button>
      {saved.map((s, i) => <div key={i} className="row between small"><span>{s}</span><span className="pill good">등록됨</span></div>)}
    </form>
  );
}

export default function OwnerDashboard() {
  const [d, setD] = useState(undefined); // undefined=불러오는 중, null=가게 미연결
  const place = d?.place;
  return (
    <main className="page stack" style={{ gap: 20 }}>
      {place ? (
        <div>
          <span className="label">{[d.regionScore?.name, KIND[place.kind] ?? place.kind].filter(Boolean).join(' · ')}</span>
          <h1>{place.name}</h1>
        </div>
      ) : <h1>{d === undefined ? '내 가게' : '내 가게를 선택해 주세요'}</h1>}

      <MyReviews onData={setD} />

      {place && (
        <section className="grid g2" style={{ alignItems: 'start' }}>
          <ReviewTopics key={place.id} reviewCount={d.summary.count} />
          <div className="stack">
            <AskAgent key={place.id} />
            <ActionForm />
          </div>
        </section>
      )}
    </main>
  );
}
