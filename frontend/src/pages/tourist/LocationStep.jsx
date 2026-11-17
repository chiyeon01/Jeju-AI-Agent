import { useEffect, useState } from 'react';
import KakaoMap from '../../components/KakaoMap.jsx';
import TypeCard from './TypeCard.jsx';
import { getRegions, nearestRegion } from '../../api/client.js';

// 제주 범위 (백엔드 /regions/nearest 가 받는 범위와 같음)
const inJeju = (lat, lon) => lat >= 32.9 && lat <= 34.1 && lon >= 125.9 && lon <= 127.1;

export default function LocationStep({ profile, onDone, onBack }) {
  const [regions, setRegions] = useState([]);
  const [region, setRegion] = useState(null);
  const [note, setNote] = useState('');

  useEffect(() => { getRegions().then(setRegions); }, []);

  // at: 실제로 고른 좌표 (실시간 날씨를 그 자리 기준으로 가져옵니다)
  const pickAt = async (lat, lon, msg) => {
    const r = await nearestRegion(lat, lon);
    setRegion({ ...r, at: { lat, lon } });
    setNote(msg ?? '');
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
    <section className="stack">
      <TypeCard profile={profile} />
      <div className="card stack">
        <div className="head" style={{ marginBottom: 0 }}>
          <h3>어디에서 시작할까요?</h3>
          <button className="btn sm" onClick={useCurrent} disabled={locating || !regions.length}>{locating ? '위치 찾는 중…' : '현재 위치 사용'}</button>
        </div>
        <div className="chips">
          {regions.map((r) => (
            <button key={r.id} type="button" className={`chip ${region?.id === r.id ? 'on' : ''}`} onClick={() => { setRegion(r); setNote(''); }}>{r.name}</button>
          ))}
        </div>
        <KakaoMap
          center={region ?? undefined}
          labels={regions.map((r) => ({ id: r.id, lat: r.lat, lon: r.lon, text: r.name, on: r.id === region?.id }))}
          onLabelClick={(id) => { setRegion(regions.find((r) => r.id === id)); setNote(''); }}
          onClick={(lat, lon) => pickAt(lat, lon, '지도에서 고른 곳과 가장 가까운 지역이에요.')}
        />
        {note && <p className="note">{note}</p>}
      </div>
      <div className="row between">
        <button className="btn ghost" onClick={onBack}>테스트 다시 하기</button>
        <button className="btn primary" disabled={!region} onClick={() => onDone(region)}>
          {region ? `${region.name}에서 코스 만들기` : '지역을 골라 주세요'}
        </button>
      </div>
    </section>
  );
}
