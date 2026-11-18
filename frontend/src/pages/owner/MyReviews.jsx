// 내 가게 화면 본문 (관광객이 앱·웹에서 남긴 실제 평가로만 만듭니다)
// 기획서 순환 구조 순서대로: ① 가게 지표 → ② 고객 분석 → ③ AI 개선 제안 → ④ 개선 조치
// ②의 주제 분석, ③의 질문, ④의 등록 폼은 OwnerDashboard 가 slots 로 넘깁니다.
import { useEffect, useRef, useState } from 'react';
import { Stars } from '../../components/Charts.jsx';
import Markdown from '../../components/Markdown.jsx';
import { relTime } from '../../utils/format.js';
import { getMyReviews, getMerchantPlaces, linkMyPlace, analyzeMyReviews, subscribeMyStore } from '../../api/client.js';

const KIND = { food: '식당', cafe: '카페', indoor: '실내 체험' };
const REFRESH_MS = 10000; // 검색 목록을 다시 불러오는 간격 (새로 평가된 가게가 바로 보이게)
const when = (iso) => (iso ? iso.slice(5, 16).replace('T', ' ') : '');

// 내 가게 검색: 관광객이 앱에서 실제로 평점을 남긴 가게만 백엔드 DB 에서 검색합니다
function LinkPlace({ onLinked, current }) {
  const [q, setQ] = useState('');
  const [places, setPlaces] = useState(null); // null=불러오는 중
  const [pick, setPick] = useState(current ?? '');
  const [err, setErr] = useState('');
  const [linking, setLinking] = useState(false);
  useEffect(() => {
    let alive = true;
    const load = () => getMerchantPlaces(q).then((p) => { if (alive) { setPlaces(p.filter((x) => Number(x.reviews) > 0)); setErr(''); } }).catch((e) => alive && setErr(e.message));
    const t = setTimeout(load, 250);
    const iv = setInterval(load, REFRESH_MS);
    return () => { alive = false; clearTimeout(t); clearInterval(iv); };
  }, [q]);
  const save = async (e) => {
    e.preventDefault();
    if (!pick || linking) return;
    setLinking(true);
    try { await linkMyPlace(pick); onLinked(); } catch (x) { setErr(x.message); setLinking(false); }
  };
  return (
    <form className="stack" style={{ gap: 16 }} onSubmit={save}>
      <input className="input" type="search" value={q} onChange={(e) => setQ(e.target.value)} placeholder="가게 이름으로 검색" aria-label="내 가게 검색" />
      <div className="store-list" role="listbox" aria-label="평점을 받은 가게">
        {places === null && <div className="skeleton" style={{ padding: '16px 0' }}><i /><i /></div>}
        {places?.length === 0 && (
          <p className="small muted" style={{ padding: '16px 0' }}>{q.trim() ? `'${q.trim()}' 검색 결과가 없어요.` : '아직 평가를 받은 가게가 없어요.'}</p>
        )}
        {places?.map((p) => (
          <button key={p.id} type="button" role="option" aria-selected={pick === p.id} className="store-opt" onClick={() => setPick(p.id)}>
            <span className="radio" aria-hidden="true" />
            <span><b>{p.name}</b><span className="meta">{[p.regionName ?? p.region, KIND[p.kind] ?? p.kind, p.no ? `장소 #${p.no}` : null].filter(Boolean).join(' · ')}</span></span>
            <span className="rate num">★ {Number(p.avgStars).toFixed(1)}<span className="meta" style={{ fontWeight: 400 }}>평가 {p.reviews}건</span></span>
          </button>
        ))}
      </div>
      {err && <p className="error">{err}</p>}
      <div className="cta-bar sticky"><span /><button className="btn primary lg" type="submit" disabled={!pick || linking}>{linking ? '연결하는 중…' : '이 가게로 시작하기'}</button></div>
    </form>
  );
}

const STEPS = [['metrics', '가게 지표'], ['customers', '고객 분석'], ['ai', 'AI 개선 제안'], ['actions', '개선 조치']];

export default function MyReviews({ onData, topics, ask, action }) {
  const [d, setD] = useState(undefined); // undefined=불러오는 중, null=연결 안 됨
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);
  const [relink, setRelink] = useState(false);
  const [toast, setToast] = useState('');
  const toastTimer = useRef(null);
  const load = () => getMyReviews().then(setD).catch((e) => { setErr(e.message); setD(null); });
  useEffect(() => { load(); }, []);
  useEffect(() => { if (d !== undefined) onData?.(relink ? null : d); }, [d, relink]); // eslint-disable-line react-hooks/exhaustive-deps

  // 실시간: 내 가게에 새 평가가 오면 알림 + 새로고침, Agent 가 분석을 저장하면 결과 새로고침
  const placeId = d?.place?.id;
  useEffect(() => {
    if (!placeId) return undefined;
    const off = subscribeMyStore((e) => {
      if (e.placeId && e.placeId !== placeId) return;
      if (e.type === '평가 등록') {
        setToast(`새 평가가 들어왔어요 ${'★'.repeat(e.stars ?? 0)}`);
        load();
      } else if (e.type === '리뷰 분석') {
        setToast('AI 개선 제안이 새로 나왔어요');
        load();
      } else return;
      clearTimeout(toastTimer.current);
      toastTimer.current = setTimeout(() => setToast(''), 6000);
    });
    return () => { off(); clearTimeout(toastTimer.current); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [placeId]);

  const analyze = async () => {
    setBusy(true); setErr('');
    try { const a = await analyzeMyReviews(); setD((x) => ({ ...x, analysis: a })); } catch (e) { setErr(e.message); } finally { setBusy(false); }
  };

  if (d === undefined) return <div className="skeleton"><i /><i /><i /></div>;
  if (!d || relink) {
    return (
      <div className="stack" style={{ gap: 24, maxWidth: 640 }}>
        <header>
          <span className="eyebrow">사장님</span>
          <h1>내 가게를 찾아 주세요</h1>
          <p className="muted" style={{ marginTop: 6 }}>관광객 평가를 받은 가게만 검색돼요.</p>
        </header>
        <LinkPlace current={d?.place?.id} onLinked={() => { setRelink(false); setD(undefined); load(); }} />
        {relink && <button className="btn ghost" style={{ justifySelf: 'start' }} onClick={() => setRelink(false)}>취소</button>}
        {err && !relink && <p className="note">{err}</p>}
      </div>
    );
  }

  const s = d.summary;
  const max = Math.max(1, ...Object.values(s.dist));
  const texts = d.reviews.filter((r) => r.text).length;
  const weekAgo = Date.now() - 7 * 86400000;
  const week = d.reviews.filter((r) => new Date(r.createdAt).getTime() >= weekAgo);
  const typeName = Object.fromEntries(s.byType.map((t) => [t.code, t.name]));
  return (
    <>
      {toast && <div className="toast" role="status">{toast}</div>}
      <header className="page-head">
        <div>
          <span className="eyebrow">{[d.regionScore?.name, KIND[d.place.kind] ?? d.place.kind, d.place.no ? `장소 #${d.place.no}` : null].filter(Boolean).join(' · ')}</span>
          <h1>{d.place.name}</h1>
        </div>
        <button className="btn sm" onClick={() => setRelink(true)}>가게 바꾸기</button>
      </header>

      <nav className="flow-nav" aria-label="화면 순서">
        {STEPS.map(([id, name], i) => <a key={id} href={`#${id}`}><b>{i + 1}</b>{name}</a>)}
      </nav>

      <section id="metrics" className="section" style={{ borderTop: 0 }}>
        <div className="section-head"><h2><span className="step-no">1</span>가게 지표</h2></div>
        <div className="figures">
          <div className="figure"><span className="k">평균 별점</span><span className="v">{s.count ? s.avg.toFixed(1) : '-'}<small>/ 5</small></span></div>
          <div className="figure"><span className="k">관광객 평가</span><span className="v">{s.count}<small>건</small></span></div>
          <div className="figure"><span className="k">최근 7일</span><span className="v">{week.length}<small>건</small></span></div>
          <div className="figure"><span className="k">리뷰 글</span><span className="v">{texts}<small>건</small></span></div>
          {d.regionScore && <div className="figure"><span className="k">{d.regionScore.name} 지역 점수</span><span className="v">{d.regionScore.score}<small>/ 10</small></span></div>}
        </div>
        <div className="grid g2" style={{ marginTop: 8 }}>
          <div className="stack" style={{ gap: 6 }}>
            <span className="label">별점 분포</span>
            {[5, 4, 3, 2, 1].map((n) => (
              <div key={n} className="stars-bar"><span className="num">{n}점</span><span className="track"><span className="fill" style={{ display: 'block', width: `${(s.dist[n] / max) * 100}%` }} /></span><span className="num r">{s.dist[n]}</span></div>
            ))}
          </div>
          <div className="stack" style={{ gap: 6 }}>
            <span className="label">어떤 성향의 손님이 왔나요</span>
            {s.byType.length ? (
              <ul className="rows">
                {s.byType.slice(0, 4).map((t) => (
                  <li key={t.code} style={{ padding: '8px 0' }}><span className="grow"><span className="title" style={{ fontWeight: 500 }}>{t.name}</span></span><span className="num small">{t.count}명{t.avg ? ` · ★${Number(t.avg).toFixed(1)}` : ''}</span></li>
                ))}
              </ul>
            ) : <p className="small muted">성향 정보가 있는 평가가 아직 없어요.</p>}
          </div>
        </div>
      </section>

      <section id="customers" className="section">
        <div className="section-head"><h2><span className="step-no">2</span>고객 분석</h2></div>
        <div className="split">
          {topics}
          <div className="stack" style={{ gap: 4 }}>
            <span className="label">최근 리뷰</span>
            {d.reviews.length === 0 && <p className="small muted">아직 리뷰가 없어요.</p>}
            <div>
              {d.reviews.slice(0, 6).map((r) => (
                <div key={r.id} className="review-item">
                  <div className="row between small"><span className="row" style={{ gap: 8 }}><Stars value={r.stars} />{r.profile && typeName[r.profile] && <span className="muted">{typeName[r.profile]}</span>}</span><span className="muted" title={when(r.createdAt)}>{relTime(r.createdAt)}</span></div>
                  {r.text ? <p className="quote">{r.text}</p> : <p className="small muted">별점만 남겼어요.</p>}
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      <section id="ai" className="section">
        <div className="section-head">
          <h2><span className="step-no">3</span>AI 개선 제안</h2>
          <button className="btn sm primary" disabled={busy} onClick={analyze}>{busy ? '분석 중…' : d.analysis ? '다시 분석' : '분석 받기'}</button>
        </div>
        {err && <p className="note">{err}</p>}
        <div className="split">
          <div className="stack" style={{ gap: 8 }}>
            {d.analysis ? (
              <>
                <span className="small muted">{when(d.analysis.createdAt)} 분석</span>
                <div className="box"><Markdown text={d.analysis.body} /></div>
              </>
            ) : <p className="small muted">‘분석 받기’를 누르면 강점, 개선할 점, 다음에 할 일을 정리해 드려요.</p>}
          </div>
          {ask}
        </div>
      </section>

      <section id="actions" className="section">
        <div className="section-head"><h2><span className="step-no">4</span>개선 조치</h2></div>
        {action}
      </section>
    </>
  );
}
