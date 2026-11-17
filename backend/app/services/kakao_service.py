# ─────────────────────────────────────────────
# 카카오맵(Kakao Local) REST API 래퍼
#
# - 지도를 "그리는" 작업은 프론트엔드가 카카오맵 JavaScript SDK로 직접 합니다
#   (frontend/.env 의 VITE_MAP_JS_KEY, 브라우저에 노출돼도 되는 키).
# - 이 모듈은 "주소 → 좌표", "좌표 → 행정동" 처럼 비밀로 유지해야 하는 REST API 키를
#   쓰는 호출만 백엔드에서 대신 해 줍니다 (LocationStep.jsx 주석의
#   "navigator.geolocation → 가장 가까운 읍면동으로 변환"에 해당).
# - KAKAO_REST_API_KEY가 없으면 is_enabled=False → 호출부가 로컬 좌표 계산으로
#   대체합니다(geo.haversine_km 기반 최근접 REGIONS).
# ─────────────────────────────────────────────
from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any

import httpx

from app.config import get_settings

logger = logging.getLogger("jejuitda.kakao")

ADDRESS_SEARCH_URL = "https://dapi.kakao.com/v2/local/search/address.json"
COORD_TO_REGION_URL = "https://dapi.kakao.com/v2/local/geo/coord2regioncode.json"
KEYWORD_SEARCH_URL = "https://dapi.kakao.com/v2/local/search/keyword.json"


@dataclass
class KakaoResult:
    ok: bool
    data: Any = None
    error: str | None = None


class KakaoService:
    def __init__(self) -> None:
        settings = get_settings()
        self._api_key = settings.kakao_rest_api_key.strip()

    @property
    def is_enabled(self) -> bool:
        return bool(self._api_key)

    def _headers(self) -> dict[str, str]:
        return {"Authorization": f"KakaoAK {self._api_key}"}

    def _get(self, url: str, params: dict[str, Any]) -> KakaoResult:
        if not self.is_enabled:
            return KakaoResult(ok=False, error="KAKAO_REST_API_KEY가 설정되지 않았습니다 (backend/.env 확인)")
        try:
            resp = httpx.get(url, headers=self._headers(), params=params, timeout=8.0)
            resp.raise_for_status()
            return KakaoResult(ok=True, data=resp.json())
        except httpx.HTTPStatusError as e:
            logger.warning("카카오 API 오류 응답: %s", e.response.text)
            return KakaoResult(ok=False, error=f"카카오 API 오류 ({e.response.status_code})")
        except httpx.HTTPError as e:
            logger.warning("카카오 API 호출 실패: %s", e)
            return KakaoResult(ok=False, error="카카오 API 호출에 실패했어요")

    def geocode_address(self, query: str) -> KakaoResult:
        """주소 문자열 → 좌표 목록."""
        result = self._get(ADDRESS_SEARCH_URL, {"query": query})
        if not result.ok:
            return result
        docs = result.data.get("documents", [])
        items = [
            {
                "address": d.get("address_name"),
                "roadAddress": (d.get("road_address") or {}).get("address_name"),
                "lat": float(d["y"]),
                "lon": float(d["x"]),
            }
            for d in docs
        ]
        return KakaoResult(ok=True, data=items)

    def search_keyword(self, query: str, lat: float | None = None, lon: float | None = None) -> KakaoResult:
        """장소·상호명 키워드 검색 → 좌표 목록 (주변 좌표가 있으면 가까운 순으로 정렬됨)."""
        params: dict[str, Any] = {"query": query}
        if lat is not None and lon is not None:
            params.update({"x": lon, "y": lat, "radius": 20000, "sort": "distance"})
        result = self._get(KEYWORD_SEARCH_URL, params)
        if not result.ok:
            return result
        docs = result.data.get("documents", [])
        items = [
            {
                "name": d.get("place_name"),
                "address": d.get("address_name"),
                "roadAddress": d.get("road_address_name"),
                "category": d.get("category_name"),
                "lat": float(d["y"]),
                "lon": float(d["x"]),
            }
            for d in docs
        ]
        return KakaoResult(ok=True, data=items)

    def reverse_geocode(self, lat: float, lon: float) -> KakaoResult:
        """좌표 → 행정동(읍면동) 이름."""
        result = self._get(COORD_TO_REGION_URL, {"x": lon, "y": lat})
        if not result.ok:
            return result
        docs = result.data.get("documents", [])
        # region_type "H"(행정동)를 우선, 없으면 "B"(법정동)
        admin = next((d for d in docs if d.get("region_type") == "H"), None) or (docs[0] if docs else None)
        if not admin:
            return KakaoResult(ok=False, error="행정동 정보를 찾지 못했어요")
        return KakaoResult(
            ok=True,
            data={
                "regionName": admin.get("region_3depth_name") or admin.get("region_2depth_name"),
                "fullAddress": admin.get("address_name"),
            },
        )


_kakao_service: KakaoService | None = None


def get_kakao_service() -> KakaoService:
    global _kakao_service
    if _kakao_service is None:
        _kakao_service = KakaoService()
    return _kakao_service
