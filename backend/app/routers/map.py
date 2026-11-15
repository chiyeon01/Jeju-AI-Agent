# ─────────────────────────────────────────────
# 지도 엔드포인트 (카카오맵 연동)
# 프론트가 카카오맵 JS SDK로 실제 지도를 그릴 때 필요한 데이터·변환을 제공합니다.
#  - 마커용 장소/지역 좌표
#  - 주소 → 좌표, 키워드 장소 검색 (카카오 REST API, 키는 서버에만 보관)
#  - 현재 위치 좌표 → 서비스 지역(읍면동 그룹) 변환
# ─────────────────────────────────────────────
from __future__ import annotations

from fastapi import APIRouter, Query

from app.schemas import (
    GeocodeOut,
    GeocodeRequest,
    PlaceOut,
    PlaceSearchOut,
    PlaceSearchRequest,
    RegionOut,
    ReverseGeocodeOut,
    ReverseGeocodeRequest,
)
from app.services import map_service

router = APIRouter(prefix="/map", tags=["map"])


@router.get("/regions", response_model=list[RegionOut])
def regions() -> list[RegionOut]:
    """서비스 지역(10개) 중심 좌표 — 지도에 지역 마커/선택 영역을 그릴 때 사용."""
    return map_service.list_regions()


@router.get("/places", response_model=list[PlaceOut])
def places(
    region: str | None = Query(None, description="지역 id (예: aewol)"),
    kind: str | None = Query(None, description="cafe | spot | sunset | food | indoor"),
) -> list[PlaceOut]:
    """추천 후보 장소 좌표 — 지도 마커용."""
    return map_service.list_places(region, kind)


@router.post("/geocode", response_model=GeocodeOut)
def geocode(req: GeocodeRequest) -> GeocodeOut:
    """주소 → 좌표 (카카오 주소 검색). 키가 없으면 source='none', 빈 목록."""
    return map_service.geocode_address(req.query)


@router.post("/search", response_model=PlaceSearchOut)
def search(req: PlaceSearchRequest) -> PlaceSearchOut:
    """키워드 장소 검색 (카카오 키워드 검색). lat/lon을 주면 가까운 순."""
    return map_service.search_places(req.query, req.lat, req.lon)


@router.post("/reverse-geocode", response_model=ReverseGeocodeOut)
def reverse_geocode(req: ReverseGeocodeRequest) -> ReverseGeocodeOut:
    """현재 위치 좌표 → 가장 가까운 서비스 지역. 카카오 키가 있으면 실제 행정동 주소도 함께."""
    return map_service.reverse_geocode(req.lat, req.lon)
