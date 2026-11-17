// 가게·위치 이름 → 네이버 지도 검색 링크, 그리고 대표 사진(서버에 네이버 검색 키가 있을 때)
import { useEffect, useState } from 'react';
import { naverPlaceUrl, placePhoto, placeInfo } from '../api/client.js';
import { KIND_LABEL } from '../mock/tourist.js';

export default function PlaceLink({ name, className = '' }) {
  return (
    <a className={`place-link ${className}`} href={naverPlaceUrl(name)} target="_blank" rel="noopener noreferrer"
      title={`${name} 네이버 지도에서 보기`}>
      {name}<span aria-hidden="true" className="ext">↗</span>
    </a>
  );
}

export function PlacePhoto({ name }) {
  const [photo, setPhoto] = useState(null);
  const [broken, setBroken] = useState(false);
  useEffect(() => {
    let alive = true;
    setPhoto(null); setBroken(false);
    placePhoto(name).then((p) => alive && setPhoto(p));
    return () => { alive = false; };
  }, [name]);
  if (!photo?.thumbnail || broken) return null;
  return (
    <a href={naverPlaceUrl(name)} target="_blank" rel="noopener noreferrer" className="place-photo">
      <img src={photo.thumbnail} alt={`${name} 대표 사진`} loading="lazy" referrerPolicy="no-referrer" onError={() => setBroken(true)} />
    </a>
  );
}

/** 종류 이름 (미술관·기념품샵 등) + 읍·면·동 주소 */
export function PlaceMeta({ name, kind, label, addr }) {
  const info = placeInfo(name);
  const tag = label ?? info?.label ?? KIND_LABEL[kind ?? info?.kind];
  const where = addr || info?.addr;
  return (
    <>
      {tag && <span className="pill">{tag}</span>}
      {where && <span className="small muted">{where}</span>}
    </>
  );
}
