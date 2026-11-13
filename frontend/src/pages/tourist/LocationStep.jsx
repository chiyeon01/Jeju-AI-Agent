import { useState } from 'react';
import JejuMap from '../../components/JejuMap.jsx';
import TypeCard from './TypeCard.jsx';
import { REGIONS } from '../../mock/tourist.js';

export default function LocationStep({ profile, onDone, onBack }) {
  const [region, setRegion] = useState(null);
  const [note, setNote] = useState('');

  const useCurrent = () => {
    // 실제 서비스: navigator.geolocation → 가장 가까운 읍면동으로 변환 (백엔드 PostGIS)
    const r = REGIONS.find((x) => x.id === 'aewol');
    setRegion(r);
    setNote('현재 위치를 애월읍으로 잡았어요. (시연용 가상 위치)');
  };

  return (
    <section className="grid" style={{ gridTemplateColumns: 'minmax(0,1fr)', gap: 20 }}>
      <TypeCard profile={profile} />
      <div className="card stack">
        <div className="card-head">
          <div>
            <h3>어디에서 시작할까요?</h3>
            <p className="small muted">지도에서 지역을 누르거나 현재 위치를 사용하세요.</p>
          </div>
          <button className="btn sm" onClick={useCurrent}>📍 현재 위치 사용</button>
        </div>
        <JejuMap selected={region?.id} onSelect={(r) => { setRegion(r); setNote(''); }} origin={region} />
        <div className="row" style={{ justifyContent: 'space-between' }}>
          <div className="small">
            {region ? <>출발 지역 <b>{region.name}</b> {note && <span className="muted">· {note}</span>}</> : <span className="muted">아직 고른 지역이 없어요.</span>}
          </div>
          <div className="row">
            <button className="btn ghost" onClick={onBack}>테스트 다시 하기</button>
            <button className="btn primary" disabled={!region} onClick={() => onDone(region)}>AI 코스 만들기</button>
          </div>
        </div>
      </div>
    </section>
  );
}
