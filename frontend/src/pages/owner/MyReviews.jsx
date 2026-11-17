// 내 가게 별점·리뷰 (관광객이 앱·웹에서 남긴 실제 평가) + Agent 리뷰 분석
import { useEffect, useState } from 'react';
import { Stars } from '../../components/Charts.jsx';
import Markdown from '../../components/Markdown.jsx';
import { getMyReviews, getMerchantPlaces, linkMyPlace, analyzeMyReviews } from '../../api/client.js';

const KIND = { food: '식당', cafe: '카페', indoor: '실내 체험' };

function LinkPlace({ onLinked, current }) {
  const [places, setPlaces] = useState([]);
  const [pick, setPick] = useState(current ?? '');
  const [err, setErr] = useState('');
  useEffect(() => { getMerchantPlaces().then(setPlaces).catch((e) => setErr(e.message)); }, []);
  const save = async (e) => {
    e.preventDefault();
    if (!pick) return;
    try { await linkMyPlace(pick); onLinked(); } catch (x) { setErr(x.message); }
  };
  return (
    <form className="row" style={{ gap: 8, flexWrap: 'wrap' }} onSubmit={save}>
      <select className="input" style={{ flex: '1 1 220px' }} value={pick} onChange={(e) => setPick(e.target.value)} aria-label="내 가게">
        <option value="">관광객 평가를 받는 내 가게를 고르세요</option>
        {places.map((p) => <option key={p.id} value={p.id}>{p.name} · {KIND[p.kind] ?? p.kind}</option>)}
      </select>
      <button className="btn primary" type="submit" disabled={!pick}>연결</button>
      {err && <span className="small bad">{err}</span>}
    </form>
  );
}

export default function MyReviews() {
  const [d, setD] = useState(undefined); // undefined=불러오는 중, null=연결 안 됨
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);
  const [relink, setRelink] = useState(false);
  const load = () => getMyReviews().then(setD).catch((e) => { setErr(e.message); setD(null); });
  useEffect(() => { load(); }, []);

  const analyze = async () => {
    setBusy(true); setErr('');
    try { const a = await analyzeMyReviews(); setD((x) => ({ ...x, analysis: a })); } catch (e) { setErr(e.message); } finally { setBusy(false); }
  };

  if (d === undefined) return <section className="card"><p className="muted">내 가게 평가를 불러오는 중…</p></section>;
  if (!d || relink) {
    return (
      <section className="card stack">
        <h3>내 가게 별점·리뷰</h3>
        <p className="small muted" style={{ margin: 0 }}>관광객이 코스를 다녀와 남긴 별점·리뷰를 보려면 내 가게를 연결해 주세요.</p>
        <LinkPlace current={d?.place?.id} onLinked={() => { setRelink(false); setD(undefined); load(); }} />
        {err && <p className="note">{err}</p>}
      </section>
    );
  }
  const s = d.summary;
  const max = Math.max(1, ...Object.values(s.dist));
  return (
    <section className="grid g2" style={{ alignItems: 'start' }}>
      <div className="card stack">
        <div className="head" style={{ marginBottom: 0 }}>
          <h3>내 가게 별점·리뷰</h3>
          <button className="btn sm ghost" onClick={() => setRelink(true)}>가게 바꾸기</button>
        </div>
        <span className="small muted">{d.place.name}{d.regionScore ? ` · ${d.regionScore.name} 지역 점수 ${d.regionScore.score}/10` : ''}</span>
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
        ) : <p className="small muted">별점과 리뷰를 읽고 강점·개선할 점·다음 할 일을 정리해 드려요. 결과는 저장돼서 다음에 다시 볼 수 있어요.</p>}
      </div>
    </section>
  );
}
