// 지난 코스 한 개 자세히: 시간표, 장소 링크(네이버 지도), 대표 사진, 지도
import { Link, useParams } from 'react-router-dom';
import { useAuth } from '../../auth/AuthContext.jsx';
import { loadHistory, fmtWhen } from '../../api/history.js';
import KakaoMap from '../../components/KakaoMap.jsx';
import PlaceLink, { PlacePhoto, PlaceMeta } from '../../components/PlaceLink.jsx';

export default function CourseDetail() {
  const { user } = useAuth();
  const { i } = useParams();
  const c = loadHistory(user.id).courses[Number(i)];
  if (!c) {
    return (
      <main className="page narrow stack">
        <p className="muted">이 코스를 찾지 못했어요. 이 기기에 저장된 기록만 볼 수 있어요.</p>
        <Link className="btn" to="/tourist">내 여행 기록으로</Link>
      </main>
    );
  }
  const withPos = c.stops.filter((s) => s.lat != null);
  return (
    <main className="page narrow stack" style={{ gap: 28 }}>
      <header className="page-head" style={{ paddingBottom: 0 }}>
        <div>
          <span className="eyebrow">{fmtWhen(c.at)}</span>
          <h1>{c.origin} 출발 · {c.stops.length}곳</h1>
          <p className="small">{[c.type, c.trip, c.weather].filter(Boolean).join(' · ')}</p>
        </div>
      </header>
      <ol className="timeline">
        {c.stops.map((s, i) => (
          <li key={s.id} className="stop">
            <span className="t">{s.at}</span>
            <span className="rail"><i>{i + 1}</i></span>
            <div className="body">
              <div className="row">
                <PlaceLink name={s.name} />
                <PlaceMeta name={s.name} kind={s.kind} />
              </div>
              <PlacePhoto name={s.name} />
            </div>
          </li>
        ))}
      </ol>
      {withPos.length > 0 && <KakaoMap center={withPos[0]} level={9} path markers={withPos.map((s) => ({ lat: s.lat, lon: s.lon, text: s.name }))} />}
      <Link className="btn" to="/tourist" style={{ alignSelf: 'flex-start' }}>내 여행으로</Link>
    </main>
  );
}
