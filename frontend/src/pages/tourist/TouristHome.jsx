// 관광객 첫 화면: "지금 할 일" 하나를 먼저 보여 주고, 아래에 내 기록을 둡니다.
// 순환 구조(성향 테스트 → 코스 추천 → 방문 → 평가)에서 지금 어디쯤인지에 따라 다음 행동이 바뀝니다.
import { useEffect, useMemo, useState } from 'react';
import { takeFlash } from '../../utils/flash.js';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../../auth/AuthContext.jsx';
import { loadHistory, fmtWhen } from '../../api/history.js';
import TypeCard from './TypeCard.jsx';
import PlaceLink from '../../components/PlaceLink.jsx';
import { greeting, relTime } from '../../utils/format.js';

const starText = (n) => '★'.repeat(n) + '☆'.repeat(5 - n);
const JOURNEY = [['성향 테스트', '5문항 · 1분'], ['출발 지역', '현재 위치·주소'], ['코스 추천', '추천 이유와 함께'], ['방문 후 평가', '가게와 다음 추천에 반영']];
const Chevron = () => <svg className="chev" width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 6l6 6-6 6" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" /></svg>;

export default function TouristHome() {
  const { user } = useAuth();
  const nav = useNavigate();
  const h = useMemo(() => loadHistory(user.id), [user.id]);
  // 지금까지 나온 여행 유형 (같은 유형은 가장 최근 것 하나만)
  const types = useMemo(() => {
    const seen = new Map();
    for (const x of h.profiles) if (x.profile?.code && !seen.has(x.profile.code)) seen.set(x.profile.code, x);
    return [...seen.values()];
  }, [h.profiles]);
  const [pick, setPick] = useState(types[0]?.profile.code ?? null);
  // 코스 저장·평가 보내기를 마치고 돌아오면 한 번 알려 줍니다
  const [flash] = useState(takeFlash);
  const [showFlash, setShowFlash] = useState(Boolean(flash));
  useEffect(() => { if (!flash) return undefined; const t = setTimeout(() => setShowFlash(false), 3500); return () => clearTimeout(t); }, [flash]);
  const chosen = types.find((t) => t.profile.code === pick) ?? types[0] ?? null;
  const last = chosen?.profile ?? null;
  const avg = h.reviews.length ? (h.reviews.reduce((s, r) => s + r.stars, 0) / h.reviews.length).toFixed(1) : '-';

  // 가장 최근 코스를 아직 평가하지 않았으면 평가부터 권합니다
  const lastCourse = h.courses[0] ?? null;
  const lastReviewAt = h.reviews[0]?.at ?? '';
  const pending = lastCourse && lastCourse.at > lastReviewAt ? lastCourse : null;

  return (
    <main className="page narrow">
      {showFlash && <div className="toast" role="status">{flash}</div>}
      <header className="page-head">
        <div>
          <span className="eyebrow">{greeting()}</span>
          <h1>{user.name}님</h1>
        </div>
        <div className="figures">
          <div className="figure"><span className="k">만든 코스</span><span className="v">{h.courses.length}</span></div>
          <div className="figure"><span className="k">보낸 평가</span><span className="v">{h.reviews.length}</span></div>
          <div className="figure"><span className="k">평균 별점</span><span className="v">{avg}</span></div>
        </div>
      </header>

      {pending ? (
        <section className="next">
          <div>
            <span className="eyebrow">{relTime(pending.at)} 저장한 코스</span>
            <h2>{pending.origin} 출발 코스, 어떠셨어요?</h2>
            <p className="small muted" style={{ marginTop: 4 }}>{pending.stops.map((s) => s.name).join(' · ')}</p>
          </div>
          <p className="small">별점을 남기면 가게의 지표와 다음 여행자의 추천에 바로 반영돼요.</p>
          <div className="row">
            <button className="btn primary lg" onClick={() => nav('/tourist/new', { state: { review: pending, profile: last } })}>평가하기</button>
            <button className="btn lg" onClick={() => nav('/tourist/new', last ? { state: { profile: last } } : undefined)}>새 코스 만들기</button>
          </div>
        </section>
      ) : last ? (
        <section className="next">
          <div>
            <span className="eyebrow">오늘의 코스</span>
            <h2>‘{last.name}’ 유형으로 코스를 만들어 볼까요?</h2>
          </div>
          <p className="small">여행 시간과 이동 수단, 출발 지역만 고르면 실시간 날씨와 혼잡도를 반영해 하루 코스를 짜 드려요.</p>
          <div className="row">
            <button className="btn primary lg" onClick={() => nav('/tourist/new', { state: { profile: last } })}>코스 만들기</button>
            <button className="btn lg" onClick={() => nav('/tourist/new')}>성향 테스트 다시 하기</button>
          </div>
        </section>
      ) : (
        <section className="next">
          <div>
            <span className="eyebrow">처음 오셨네요</span>
            <h2>나에게 맞는 제주의 하루를 찾아볼까요?</h2>
          </div>
          <ol className="journey">
            {JOURNEY.map(([k, v], i) => <li key={k} className={i === 0 ? 'on' : ''}><b>{k}</b>{v}</li>)}
          </ol>
          <div className="row"><button className="btn primary lg" onClick={() => nav('/tourist/new')}>성향 테스트 시작</button></div>
        </section>
      )}

      {last && (
        <section className="section" style={{ marginTop: 32 }}>
          <div className="section-head"><h2>내 여행 유형</h2><span className="small muted">{fmtWhen(chosen.at)}</span></div>
          {types.length > 1 && (
            <div className="chips" role="radiogroup" aria-label="내 여행 유형">
              {types.map((t) => (
                <button key={t.profile.code} type="button" role="radio" aria-checked={t.profile.code === chosen.profile.code}
                  className={`chip ${t.profile.code === chosen.profile.code ? 'on' : ''}`} onClick={() => setPick(t.profile.code)}>
                  {t.profile.name}
                </button>
              ))}
            </div>
          )}
          <TypeCard profile={last} showTrip={false} />
        </section>
      )}

      <section className="section" style={last ? undefined : { marginTop: 32 }}>
        <div className="section-head"><h2>최근 코스</h2><span className="small muted">{h.courses.length ? `${h.courses.length}개` : ''}</span></div>
        {h.courses.length ? (
          <div className="rows">
            {h.courses.slice(0, 6).map((c, i) => (
              <Link key={i} className="row-link" to={`/tourist/history/${i}`}>
                <span className="grow">
                  <span className="title">{c.origin} 출발 · {c.stops.length}곳</span>
                  <span className="sub">{c.stops.map((s) => s.name).join(' → ')}</span>
                </span>
                <span className="end"><span className="small muted">{relTime(c.at)}</span>{c === pending && <span className="pill brand">평가 전</span>}</span>
                <Chevron />
              </Link>
            ))}
          </div>
        ) : <p className="small muted">아직 만든 코스가 없어요.</p>}
      </section>

      <section className="section">
        <div className="section-head"><h2>내가 남긴 평가</h2></div>
        {h.reviews.length ? (
          <ul className="rows">
            {h.reviews.slice(0, 5).map((r, i) => (
              <li key={i}>
                <span className="grow">
                  <PlaceLink name={r.name} />
                  {r.text && <span className="sub">{r.text}</span>}
                </span>
                <span className="end">
                  <span className="small" style={{ color: 'var(--star)', letterSpacing: 1 }} aria-label={`별 ${r.stars}개`}>{starText(r.stars)}</span>
                  <span className="small muted">{relTime(r.at)}</span>
                </span>
              </li>
            ))}
          </ul>
        ) : <p className="small muted">여행을 마치고 평가를 보내면 여기에 모여요.</p>}
        <p className="small muted">기록은 이 기기에만 저장돼요. 내 정보에서 지울 수 있어요.</p>
      </section>
    </main>
  );
}
