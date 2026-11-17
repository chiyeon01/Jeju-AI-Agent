// 관광객 첫 화면: 지금까지의 기록을 한눈에 보고, 새 여행을 시작합니다.
import { useMemo } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../../auth/AuthContext.jsx';
import { loadHistory, fmtWhen } from '../../api/history.js';
import { KIND_LABEL } from '../../mock/tourist.js';
import TypeCard from './TypeCard.jsx';

const starText = (n) => '★'.repeat(n) + '☆'.repeat(5 - n);

export default function TouristHome() {
  const { user } = useAuth();
  const nav = useNavigate();
  const h = useMemo(() => loadHistory(user.id), [user.id]);
  const last = h.profiles[0]?.profile ?? null;
  const avg = h.reviews.length ? (h.reviews.reduce((s, r) => s + r.stars, 0) / h.reviews.length).toFixed(1) : '-';

  return (
    <main className="page">
      <div className="stack">
        <div className="head" style={{ marginBottom: 0 }}>
          <div>
            <span className="label">내 여행 기록</span>
            <h2>{user.name}님, 반가워요</h2>
          </div>
          <div className="row">
            {last && <button className="btn" onClick={() => nav('/tourist/new', { state: { profile: last } })}>지난 성향으로 코스 만들기</button>}
            <button className="btn primary" onClick={() => nav('/tourist/new')}>{last ? '성향 테스트부터 새로 시작' : '첫 여행 코스 만들기'}</button>
          </div>
        </div>

        <div className="grid g3 stats">
          <div className="stat"><span className="label">만든 코스</span><b>{h.courses.length}</b></div>
          <div className="stat"><span className="label">보낸 평가</span><b>{h.reviews.length}</b></div>
          <div className="stat"><span className="label">평균 별점</span><b>{avg}</b></div>
        </div>

        <div className="grid g2" style={{ alignItems: 'start' }}>
          <section className="stack">
            <h3>내 여행 유형</h3>
            {last ? (
              <>
                <TypeCard profile={last} />
                <p className="small muted">{fmtWhen(h.profiles[0].at)}에 테스트했어요{h.profiles.length > 1 ? ` · 지금까지 ${h.profiles.length}번` : ''}</p>
              </>
            ) : (
              <div className="card empty"><p>아직 성향 테스트를 하지 않았어요.</p><Link className="btn primary sm" to="/tourist/new">5문항 테스트 하기</Link></div>
            )}

            <h3>최근 평가</h3>
            <div className="card">
              {h.reviews.length ? (
                <ul className="hist">
                  {h.reviews.slice(0, 5).map((r, i) => (
                    <li key={i}>
                      <div className="row between"><strong>{r.name}</strong><span className="small" style={{ color: 'var(--warn)' }} aria-label={`별 ${r.stars}개`}>{starText(r.stars)}</span></div>
                      {r.text && <span className="small">{r.text}</span>}
                      <span className="small muted">{fmtWhen(r.at)}</span>
                    </li>
                  ))}
                </ul>
              ) : <p className="muted small">여행을 마치고 평가를 보내면 여기에 모여요.</p>}
            </div>
          </section>

          <section className="stack">
            <h3>최근 코스</h3>
            <div className="card">
              {h.courses.length ? (
                <ul className="hist">
                  {h.courses.slice(0, 6).map((c, i) => (
                    <li key={i}>
                      <div className="row between">
                        <strong>{c.origin} 출발 · {c.stops.length}곳</strong>
                        <span className="small muted">{fmtWhen(c.at)}</span>
                      </div>
                      <span className="small">{c.stops.map((s) => s.name).join(' → ')}</span>
                      <div className="row" style={{ gap: 6 }}>
                        {c.weather && <span className="pill">{c.weather}</span>}
                        {[...new Set(c.stops.map((s) => KIND_LABEL[s.kind]).filter(Boolean))].slice(0, 3).map((k) => <span key={k} className="pill">{k}</span>)}
                      </div>
                    </li>
                  ))}
                </ul>
              ) : (
                <div className="empty"><p>아직 다녀온 코스가 없어요.</p><Link className="btn primary sm" to="/tourist/new">코스 만들기</Link></div>
              )}
            </div>
            <p className="small muted">기록은 이 기기에만 저장돼요. 내 정보에서 지울 수 있어요.</p>
          </section>
        </div>
      </div>
    </main>
  );
}
