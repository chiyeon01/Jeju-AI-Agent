import { useEffect, useState } from 'react';
import KakaoMap from '../../components/KakaoMap.jsx';
import TypeCard from './TypeCard.jsx';
import { getRegions, nearestRegion } from '../../api/client.js';

export default function LocationStep({ profile, onDone, onBack }) {
  const [regions, setRegions] = useState([]);
  const [region, setRegion] = useState(null);
  const [note, setNote] = useState('');

  useEffect(() => { getRegions().then(setRegions); }, []);

  const pickAt = async (lat, lon, msg) => {
    const r = await nearestRegion(lat, lon);
    setRegion(r);
    setNote(msg ?? '');
  };

  const useCurrent = () => {
    const fallback = () => {
      const r = regions.find((x) => x.id === 'aewol');
      setRegion(r);
      setNote('위치를 가져오지 못해 애월읍으로 잡았어요.');
    };
    if (!navigator.geolocation) return fallback();
    navigator.geolocation.getCurrentPosition(
      (p) => pickAt(p.coords.latitude, p.coords.longitude, '현재 위치에서 가장 가까운 지역이에요.'),
      fallback,
      { timeout: 5000 },
    );
  };

  return (
    <section className="stack">
      <TypeCard profile={profile} />
      <div className="card stack">
        <div className="head" style={{ marginBottom: 0 }}>
          <h3>어디에서 시작할까요?</h3>
          <button className="btn sm" onClick={useCurrent}>현재 위치 사용</button>
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
