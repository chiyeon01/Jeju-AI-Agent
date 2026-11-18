// 내 가게 별점·리뷰 (관광객이 앱·웹에서 남긴 실제 평가) + Agent 리뷰 분석
import { useEffect, useRef, useState } from 'react';
import { Stars } from '../../components/Charts.jsx';
import Markdown from '../../components/Markdown.jsx';
import { getMyReviews, getMerchantPlaces, linkMyPlace, analyzeMyReviews, subscribeMyStore } from '../../api/client.js';

const KIND = { food: '식당', cafe: '카페', indoor: '실내 체험' };

const REFRESH_MS = 10000; // 검색 목록을 다시 불러오는 간격 (새로 평가된 가게가 바로 보이게)

// 내 가게 검색: 관광객이 앱에서 실제로 평점을 남긴 가게만 백엔드 DB 에서 검색합니다
function LinkPlace({ onLinked, current }) {
  const [q, setQ] = useState('');
  const [places, setPlaces] = useState(null); // null=불러오는 중
  const [pick, setPick] = useState(current ?? '');
  const [err, setErr] = useState('');
  useEffect(() => {
    let alive = true;
    // 평가 수가 없는 장소는 혹시 백엔드가 예전 버전이어도 보이지 않게 한 번 더 거릅니다
    const load = () => getMerchantPlaces(q).then((p) => { if (alive) { setPlaces(p.filter((x) => Number(x.reviews) > 0)); setErr(''); } }).catch((e) => alive && setErr(e.message));
    const t = setTimeout(load, 250);
    const iv = setInterval(load, REFRESH_MS);
    return () => { alive = false; clearTimeout(t); clearInterval(iv); };
  }, [q]);
  const save = async (e) => {
    e.preventDefault();
    if (!pick) return;
    try { await linkMyPlace(pick); onLinked(); } catch (x) { setErr(x.message); }
  };
  return (
    <form className="stack" style={{ gap: 8 }} onSubmit={save}>
      <input className="input" type="search" value={q} onChange={(e) => setQ(e.target.value)}
             placeholder="가게 이름으로 검색" aria-label="내 가게 검색" />
      <div className="stack" role="listbox" aria-label="평점을 받은 가게" style={{ gap: 4, maxHeight: 280, overflowY: 'auto' }}>
        {places === null && <span className="small muted">검색 중…</span>}
        {places?.length === 0 && (
          <span className="small muted">{q.trim() ? `'${q.trim()}'에 해당하는, 관광객 평점을 받은 가게가 없어요.` : '아직 관광객 평점을 받은 가게가 없어요. 관광객이 앱에서 평점을 남기면 여기에 나타나요.'}</span>
        )}
        {places?.map((p) => (
          <button key={p.id} type="button" role="option" aria-selected={pick === p.id}
                  className={`btn sm ${pick === p.id ? 'primary' : 'ghost'}`}
                  style={{ justifyContent: 'space-between', display: 'flex', textAlign: 'left' }}
                  onClick={() => setPick(p.id)}>
            <span>{p.no ? `#${p.no} ` : ''}{p.name} · {KIND[p.kind] ?? p.kind}</span>
            <span className="num">★ {Number(p.avgStars).toFixed(1)} · {p.reviews}건</span>
          </button>
        ))}
      </div>
      <div className="row" style={{ gap: 8 }}>
        <button className="btn primary" type="submit" disabled={!pick}>연결</button>
        {err && <span className="small bad">{err}</span>}
      </div>
    </form>
  );
}

export default function MyReviews({ onData }) {
  const [d, setD] = useState(undefined); // undefined=불러오는 중, null=연결 안 됨
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);
  const [relink, setRelink] = useState(false);
  const [toast, setToast] = useState('');
  const toastTimer = useRef(null);
  const load = () => getMyReviews().then(setD).catch((e) => { setErr(e.message); setD(null); });
  useEffect(() => { load(); }, []);
  useEffect(() => { if (d !== undefined) onData?.(relink ? null : d); }, [d, relink]); // eslint-disable-line react-hooks/exhaustive-deps

  // 실시간: 내 가게에 새 평가가 오면 알림 + 목록 새로고침, Agent 가 분석을 저장하면 결과 새로고침
  const placeId = d?.place?.id;
  useEffect(() => {
    if (!placeId) return undefined;
    const off = subscribeMyStore((e) => {
      if (e.placeId && e.placeId !== placeId) return;
      if (e.type === '평가 등록') {
        setToast(`새 평가 ${'★'.repeat(e.stars ?? 0)} · ${e.text} — Agent가 곧 분석해요`);
        load();
      } else if (e.type === '리뷰 분석') {
        setToast('Agent가 새 리뷰 분석을 저장했어요');
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

  if (d === undefined) return <section className="card"><p className="muted">내 가게 평가를 불러오는 중…</p></section>;
  if (!d || relink) {
    return (
      <section className="card stack">
        <h3>내 가게 선택</h3>
        <p className="small muted" style={{ margin: 0 }}>관광객 평점을 받은 가게만 검색돼요. 내 가게를 골라 연결하면 별점·리뷰와 AI 분석을 볼 수 있어요.</p>
        <LinkPlace current={d?.place?.id} onLinked={() => { setRelink(false); setD(undefined); load(); }} />
        {err && <p className="note">{err}</p>}
      </section>
    );
  }
  const s = d.summary;
  const max = Math.max(1, ...Object.values(s.dist));
  return (
    <section className="grid g2" style={{ alignItems: 'start' }}>
      {toast && <div className="toast" role="status">{toast}</div>}
      <div className="card stack">
        <div className="head" style={{ marginBottom: 0 }}>
          <h3>내 가게 별점·리뷰 <span className="live" aria-hidden="true" /></h3>
          <button className="btn sm ghost" onClick={() => setRelink(true)}>가게 바꾸기</button>
        </div>
        <span className="small muted">{d.place.no ? `장소 #${d.place.no} · ` : ''}{d.place.name}{d.regionScore ? ` · ${d.regionScore.name} 지역 점수 ${d.regionScore.score}/10` : ''}</span>
        <div className="row" style={{ gap: 16, alignItems: 'center' }}>
          <div className="score"><b className="num">{s.count ? s.avg.toFixed(1) : '-'}</b><span className="muted">/ 5</span></div>
          <div className="stack" style={{ gap: 2 }}>
            <Stars value={Math.round(s.avg)} />
            <span className="small muted">관광객 평가 {s.count}건</span>
          </div>
        </div>
        <div className="stack" style={{ gap: 4 }}>
          {[5, 4, 3, 2, 1].map((n) => (
            <div key={n} className="stars-bar"><span className="num">{n}점</span><span className="track"><span className="fill" style={{ display: 'block', width: `${(s.dist[n] / max) * 100}%` }} /></span><span className="num muted r">{s.dist[n]}</span></div>
          ))}
        </div>
        {s.byType.length > 0 && (
          <div className="row" style={{ gap: 6, flexWrap: 'wrap' }}>
            {s.byType.slice(0, 4).map((t) => <span key={t.code} className="pill">{t.name} {t.count}</span>)}
          </div>
        )}
        <h3 style={{ marginTop: 8 }}>최근 리뷰</h3>
        {d.reviews.length === 0 && <p className="small muted">아직 리뷰가 없어요.</p>}
        {d.reviews.slice(0, 8).map((r) => (
          <div key={r.id} className="stack" style={{ gap: 2, borderTop: '1px solid var(--line)', paddingTop: 10 }}>
            <div className="row between small"><Stars value={r.stars} /><span className="muted num">{r.createdAt.slice(5, 16).replace('T', ' ')}</span></div>
            {r.text ? <p className="small">{r.text}</p> : <p className="small muted">별점만 남겼어요.</p>}
          </div>
        ))}
      </div>
      <div className="card stack">
        <div className="head" style={{ marginBottom: 0 }}>
          <h3>Agent 리뷰 분석</h3>
          <button className="btn sm primary" disabled={busy} onClick={analyze}>{busy ? '분석 중…' : d.analysis ? '다시 분석' : '분석하기'}</button>
        </div>
        {err && <p className="note">{err}</p>}
        {d.analysis ? (
          <>
            <span className="small muted">{d.analysis.createdAt.slice(5, 16).replace('T', ' ')} · {d.analysis.source === 'gpt' ? 'GPT 분석' : '규칙 기반 분석'}</span>
            <Markdown text={d.analysis.body} />
          </>
        ) : <p className="small muted">별점과 리뷰를 읽고 강점·개선할 점·다음 할 일을 정리해 드려요. 새 평가가 들어오면 Agent가 자동으로 다시 분석해요.</p>}
      </div>
    </section>
  );
}
