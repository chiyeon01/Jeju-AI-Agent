import { useEffect, useState } from 'react';
import KakaoMap from '../../components/KakaoMap.jsx';
import RegionArt from '../../components/RegionArt.jsx';
import { getRegions, getPlaces, nearestRegion, regionFromAddress, searchPhoto } from '../../api/client.js';

import { REGION_INFO, fitWith } from '../../regionInfo.js';

// 고른 지역의 특색: 그림 + 해시태그 + 설명 + 갈 만한 곳
/** 지역 대표 사진 (실제 사진, 네이버 이미지 검색). 불러오기 전·실패하면 그림으로 */
function RegionPhoto({ region, info }) {
  const [photo, setPhoto] = useState(null);
  const [src, setSrc] = useState(null);
  useEffect(() => {
    let alive = true;
    setPhoto(null); setSrc(null);
    searchPhoto(info.photo).then((p) => { if (alive && p) { setPhoto(p); setSrc(p.image || p.thumbnail); } });
    return () => { alive = false; };
  }, [info.photo]);
  if (!src) return <RegionArt info={info} title={`${region.name} 풍경 그림`} />;
  return (
    <figure className="region-photo">
      <img src={src} alt={`${region.name} 대표 사진 (${info.photo})`} referrerPolicy="no-referrer"
        onError={() => setSrc(src === photo.image && photo.thumbnail && photo.thumbnail !== src ? photo.thumbnail : null)} />
    </figure>
  );
}

function RegionFeature({ region, profile }) {
  const info = REGION_INFO[region.id];
  // 갈 만한 곳: 백엔드 장소 목록 (관광객 실제 별점이 반영된 평점 순)
  const [spots, setSpots] = useState([]);
  useEffect(() => {
    let alive = true;
    setSpots([]);
    getPlaces(region.id).then((l) => alive && setSpots([...l].sort((a, b) => b.rating - a.rating).slice(0, 4))).catch(() => {});
    return () => { alive = false; };
  }, [region.id]);
  if (!info) return null;
  const fit = fitWith(region.id, profile.code);
  return (
    <div key={region.id} className="region-feature" style={{ '--accent': info.accent }}>
      <RegionPhoto region={region} info={info} />
      <div className="region-body stack" style={{ gap: 8 }}>
        <div className="row between" style={{ gap: 8, flexWrap: 'wrap' }}>
          <h3 style={{ margin: 0 }}>{region.name}</h3>
          {fit.length > 0 && <span className="pill brand">내 유형과 잘 맞아요</span>}
        </div>
        <div className="region-tags">{info.tags.map((t) => <span key={t}>{t}</span>)}</div>
        <p className="small" style={{ margin: 0 }}>{info.desc}</p>
        {spots.length > 0 && (
          <p className="small muted" style={{ margin: 0 }}>
            평점 높은 곳 · {spots.map((p) => `${p.name} ★${Number(p.rating).toFixed(1)}`).join(' · ')}
          </p>
        )}
      </div>
    </div>
  );
}

// 제주 범위 (백엔드 /regions/nearest 가 받는 범위와 같음)
const inJeju = (lat, lon) => lat >= 32.9 && lat <= 34.1 && lon >= 125.9 && lon <= 127.1;

export default function LocationStep({ profile, initial = null, onDone, onBack }) {
  const [regions, setRegions] = useState([]);
  const [region, setRegion] = useState(initial); // 이전 단계로 돌아왔다 다시 오면 고른 지역 유지
  const [note, setNote] = useState('');

  useEffect(() => { getRegions().then(setRegions); }, []);

  // at: 실제로 고른 좌표 (실시간 날씨를 그 자리 기준으로 가져옵니다)
  const pickAt = async (lat, lon, msg) => {
    const r = await nearestRegion(lat, lon);
    setRegion({ ...r, at: { lat, lon } });
    setNote(msg ?? '');
  };

  // 주소 입력: 서버 주소 검색(카카오) → 가장 가까운 지역, 안 되면 읍·면·동 이름으로
  const [address, setAddress] = useState('');
  const [finding, setFinding] = useState(false);
  const findAddress = async (e) => {
    e.preventDefault();
    if (!address.trim()) return;
    setFinding(true);
    try {
      const hit = await regionFromAddress(address);
      if (hit) { setRegion(hit.region); setNote(`'${hit.label}' 기준으로 ${hit.region.name}에서 시작해요.`); }
      else setNote('주소에서 제주 지역을 찾지 못했어요. 읍·면·동 이름(예: 애월읍 곽지리)으로 다시 적거나 아래에서 골라 주세요.');
    } finally {
      setFinding(false);
    }
  };

  const [locating, setLocating] = useState(false);
  const useCurrent = () => {
    const fallback = (why) => {
      setLocating(false);
      const r = regions.find((x) => x.id === 'aewol') ?? regions[0];
      setRegion(r);
      setNote(`${why} 애월읍으로 잡았어요. 지도나 지역을 눌러 바꿀 수 있어요.`);
    };
    if (!navigator.geolocation) return fallback('이 브라우저는 위치를 지원하지 않아');
    setLocating(true);
    navigator.geolocation.getCurrentPosition(
      async ({ coords: { latitude: lat, longitude: lon } }) => {
        setLocating(false);
        if (!inJeju(lat, lon)) return fallback('지금 위치가 제주 밖이라');
        await pickAt(lat, lon, '현재 위치에서 가장 가까운 지역이에요.');
      },
      (e) => fallback(e.code === 1 ? '위치 권한이 꺼져 있어' : '위치를 가져오지 못해'),
      { enableHighAccuracy: false, timeout: 10000, maximumAge: 60000 },
    );
  };

  return (
    <section className="stack" style={{ gap: 24 }}>
      <div className="row between">
        <h1 style={{ fontSize: '1.5rem' }}>어디에서 출발하나요?</h1>
        <button className="btn sm" onClick={useCurrent} disabled={locating || !regions.length}>{locating ? '위치 찾는 중…' : '현재 위치'}</button>
      </div>
      <form className="locate-tools" onSubmit={findAddress}>
        <input className="input" value={address} onChange={(e) => setAddress(e.target.value)}
          placeholder="주소 입력 (예: 애월읍 애월해안로 272)" aria-label="출발 주소" />
        <button className="btn" type="submit" disabled={finding || !address.trim()}>{finding ? '찾는 중…' : '찾기'}</button>
      </form>
      <div className="field"><span>지역에서 고르기</span>
        <div className="chips">
          {regions.map((r) => (
            <button key={r.id} type="button" className={`chip region-chip ${region?.id === r.id ? 'on' : ''}`} style={{ '--accent': REGION_INFO[r.id]?.accent }} onClick={() => { setRegion(r); setNote(''); }}>{r.name}</button>
          ))}
        </div>
      </div>
      {note && <p className="note">{note}</p>}
      {region && <RegionFeature region={region} profile={profile} />}
      <KakaoMap
        center={region ?? undefined}
        labels={regions.map((r) => ({ id: r.id, lat: r.lat, lon: r.lon, text: r.name, on: r.id === region?.id }))}
        onLabelClick={(id) => { setRegion(regions.find((r) => r.id === id)); setNote(''); }}
        onClick={(lat, lon) => pickAt(lat, lon, '지도에서 고른 곳과 가장 가까운 지역이에요.')}
      />
      <div className="cta-bar sticky">
        <button className="btn ghost" onClick={onBack}>이전</button>
        <button className="btn primary lg" disabled={!region} onClick={() => onDone(region)}>
          {region ? `${region.name}에서 코스 만들기` : '출발 지역을 골라 주세요'}
        </button>
      </div>
    </section>
  );
}
