// 상권 주인 대시보드
// 처음 들어오면 내 가게(관광객 평점을 받은 가게)를 먼저 고르고, 연결된 뒤에만 아래 분석이 열립니다.
// 화면의 모든 값은 관광객이 앱에서 실제로 남긴 별점·리뷰로 만듭니다 (시연용 고정 데이터 없음).
import { useEffect, useState } from 'react';
import { getReviewTopics, askOwnerAgent, registerAction, OWNER_SUGGESTED_QUESTIONS } from '../../api/client.js';
import MyReviews from './MyReviews.jsx';

const KIND = { food: '식당', cafe: '카페', indoor: '실내 체험' };
const KIND_ICON = { food: '🍜', cafe: '☕', indoor: '🎨' };

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
        <h3 className="section-title"><span className="ico" aria-hidden="true">💬</span>리뷰 주제별 반응</h3>
        {t && <span className="small muted">{t.source === 'gpt' ? 'GPT 분석' : '규칙 기반 분석'} · 리뷰 {t.textCount}건</span>}
      </div>
      {err && <p className="note">{err}</p>}
      {!t && !err && <div className="skeleton"><i /><i /><i /><span className="small muted">GPT가 리뷰를 읽고 있어요…</span></div>}
      {t && topics.length === 0 && <p className="small muted">아직 분석할 리뷰 글이 없어요. 관광객이 한 줄 평을 남기면 주제별로 정리해 드려요.</p>}
      {topics.map((x) => (
        <div key={x.topic} className={`topic ${x.pos < 60 ? 'weak' : ''}`}>
          <div className="row between small">
            <b>{x.topic} {x.pos < 60 && <span className="pill bad">개선 필요</span>}</b>
            <span className="num muted">긍정 <b style={{ color: x.pos < 60 ? 'var(--bad)' : 'var(--good)' }}>{x.pos}%</b> · {x.mentions}건</span>
          </div>
          <div className="bar"><span style={{ width: `${x.pos}%`, background: x.pos < 60 ? 'var(--bad)' : 'var(--good)' }} /></div>
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
    <div className="card raised chat-card">
      <div className="ai-head">
        <span className="ico" aria-hidden="true">✨</span>
        <div><h3>AI 상권 분석가에게 물어보기</h3><span className="small muted">내 가게 별점·리뷰를 근거로 답해요</span></div>
      </div>
      <div className="chat" aria-live="polite">
        {chat.length === 0 && <div className="bubble ai">관광객 별점·리뷰에 대해 궁금한 점을 물어보세요.</div>}
        {chat.map((m, i) => <div key={i} className={`bubble ${m.from}`}>{m.text}</div>)}
        {asking && <div className="bubble ai muted">확인하는 중…</div>}
      </div>
      <div className="chips">
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
        <h3 className="section-title"><span className="ico" aria-hidden="true">📣</span>메뉴·이벤트 등록</h3>
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
        <section className="hero">
          <div className="hero-row">
            <div className="stack" style={{ gap: 6 }}>
              <span className="label">{[d.regionScore?.name, KIND[place.kind] ?? place.kind].filter(Boolean).join(' · ')}{place.no ? ` · 장소 #${place.no}` : ''}</span>
              <h1><span aria-hidden="true">{KIND_ICON[place.kind] ?? '🏪'} </span>{place.name}</h1>
              <p>관광객이 남긴 실제 별점·리뷰로 만든 내 가게 대시보드예요.</p>
            </div>
          </div>
          <div className="hero-stats">
            <div className="hero-stat"><span>평균 별점</span><b>{d.summary.count ? `★ ${d.summary.avg.toFixed(1)}` : '-'}</b></div>
            <div className="hero-stat"><span>관광객 평가</span><b>{d.summary.count}건</b></div>
            <div className="hero-stat"><span>리뷰 글</span><b>{d.reviews.filter((r) => r.text).length}건</b></div>
            {d.regionScore && <div className="hero-stat"><span>{d.regionScore.name} 지역 점수</span><b>{d.regionScore.score}<small style={{ fontSize: '.8rem', opacity: .8 }}> / 10</small></b></div>}
          </div>
        </section>
      ) : (
        <section className="hero">
          <span className="label">사장님 대시보드</span>
          <h1>{d === undefined ? '내 가게' : '내 가게를 선택해 주세요'}</h1>
          <p>관광객 평점을 받은 가게를 연결하면 별점·리뷰와 AI 분석이 열려요.</p>
        </section>
      )}

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
