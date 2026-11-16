// 카카오맵 래퍼. config.kakaoMapKey(VITE_KAKAO_MAP_KEY)가 비어 있으면 안내 문구만 보여 줍니다.
// SDK 문서: https://apis.map.kakao.com/web/documentation/
import { useEffect, useRef, useState } from 'react';
import { config } from '../config.js';

let sdkPromise = null;
function loadKakao() {
  if (window.kakao?.maps?.LatLng) return Promise.resolve(window.kakao);
  if (!sdkPromise) {
    sdkPromise = new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = `https://dapi.kakao.com/v2/maps/sdk.js?appkey=${encodeURIComponent(config.kakaoMapKey)}&autoload=false`;
      s.async = true;
      s.onload = () => window.kakao.maps.load(() => resolve(window.kakao));
      s.onerror = () => { sdkPromise = null; reject(new Error('카카오맵 SDK를 불러오지 못했어요.')); };
      document.head.appendChild(s);
    });
  }
  return sdkPromise;
}

const esc = (t) => String(t).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

/**
 * props
 * - center: { lat, lon }, level: 확대 단계(작을수록 가까움, 제주 전체는 10)
 * - labels: [{ id, lat, lon, text, on }]  지역 이름표 (누르면 onLabelClick(id))
 * - markers: [{ lat, lon, text }]        번호 마커 (코스 순서)
 * - path: true 이면 markers 를 순서대로 선으로 잇습니다
 * - circles: [{ lat, lon, radius, color, text }]  지역 점수 원
 * - onClick(lat, lon): 지도 빈 곳을 눌렀을 때
 */
export default function KakaoMap({ center = { lat: 33.38, lon: 126.55 }, level = 10, labels = [], markers = [], path = false, circles = [], onClick, onLabelClick, height }) {
  const box = useRef(null);
  const map = useRef(null);
  const layers = useRef([]);
  const [error, setError] = useState('');
  const handlers = useRef({ onClick, onLabelClick });
  handlers.current = { onClick, onLabelClick };

  // 지도 생성 (한 번)
  useEffect(() => {
    if (!config.kakaoMapKey) return;
    let alive = true;
    loadKakao().then((kakao) => {
      if (!alive || !box.current) return;
      map.current = new kakao.maps.Map(box.current, { center: new kakao.maps.LatLng(center.lat, center.lon), level });
      kakao.maps.event.addListener(map.current, 'click', (e) => {
        handlers.current.onClick?.(e.latLng.getLat(), e.latLng.getLng());
      });
      setError('');
      draw();
    }).catch((e) => alive && setError(e.message));
    return () => { alive = false; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // 표시 요소 다시 그리기
  const draw = () => {
    const kakao = window.kakao;
    if (!map.current || !kakao) return;
    layers.current.forEach((l) => l.setMap(null));
    layers.current = [];
    const ll = (p) => new kakao.maps.LatLng(p.lat, p.lon);
    const add = (l) => { l.setMap(map.current); layers.current.push(l); };

    circles.forEach((c) => {
      add(new kakao.maps.Circle({ center: ll(c), radius: c.radius || 3000, strokeWeight: 1, strokeColor: c.color, strokeOpacity: 0.9, fillColor: c.color, fillOpacity: 0.35 }));
      if (c.text) add(new kakao.maps.CustomOverlay({ position: ll(c), content: `<div class="map-label">${esc(c.text)}</div>`, yAnchor: 0.5 }));
    });
    labels.forEach((l) => {
      const el = document.createElement('div');
      el.className = `map-label${l.on ? ' on' : ''}`;
      el.textContent = l.text;
      el.style.cursor = 'pointer';
      el.onclick = (ev) => { ev.stopPropagation(); handlers.current.onLabelClick?.(l.id); };
      add(new kakao.maps.CustomOverlay({ position: ll(l), content: el, yAnchor: 1 }));
    });
    markers.forEach((m, i) => {
      add(new kakao.maps.CustomOverlay({ position: ll(m), content: `<div class="map-num" title="${esc(m.text || '')}">${i + 1}</div>`, yAnchor: 0.5 }));
    });
    if (path && markers.length > 1) {
      add(new kakao.maps.Polyline({ path: markers.map(ll), strokeWeight: 4, strokeColor: '#1f6f8b', strokeOpacity: 0.8, strokeStyle: 'solid' }));
    }
    if (markers.length > 1) {
      const b = new kakao.maps.LatLngBounds();
      markers.forEach((m) => b.extend(ll(m)));
      map.current.setBounds(b, 40, 40, 40, 40);
    }
  };
  useEffect(draw, [JSON.stringify(labels), JSON.stringify(markers), JSON.stringify(circles), path]); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <div className="map" style={height ? { aspectRatio: 'auto', height } : undefined}>
      <div ref={box} style={{ position: 'absolute', inset: 0 }} />
      {!config.kakaoMapKey && (
        <div className="map-empty">
          <div>
            <b>카카오맵 키를 넣으면 지도가 표시됩니다</b>
            <div>frontend/.env 의 VITE_KAKAO_MAP_KEY</div>
          </div>
        </div>
      )}
      {error && <div className="map-empty">{error}</div>}
    </div>
  );
}
