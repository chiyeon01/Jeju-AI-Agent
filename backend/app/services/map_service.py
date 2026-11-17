# ─────────────────────────────────────────────
# 지도 Agent 도구 (sql_query 옆의 spatial_search 에 해당)
# 카카오 REST API가 있으면 그걸 쓰고, 없거나 실패하면 보유한 REGIONS 좌표로
# 직접 최근접 지역을 계산합니다 (LocationStep.jsx 주석의 "백엔드 PostGIS" 자리).
# ─────────────────────────────────────────────
from __future__ import annotations

from app.data.tourist_data import PLACES, REGIONS
from app.schemas import (
    GeocodeOut,
    PlaceOut,
    PlaceSearchOut,
    RegionOut,
    ReverseGeocodeOut,
)
from app.services.geo import haversine_km
from app.services.kakao_service import get_kakao_service


def list_regions() -> list[RegionOut]:
    return [RegionOut(**r) for r in REGIONS]


def list_places(region: str | None = None, kind: str | None = None) -> list[PlaceOut]:
    items = PLACES
    if region:
        items = [p for p in items if p["region"] == region]
    if kind:
        items = [p for p in items if p["kind"] == kind]
    return [PlaceOut(**p) for p in items]


def geocode_address(query: str) -> GeocodeOut:
    kakao = get_kakao_service()
    if not kakao.is_enabled:
        return GeocodeOut(source="none", items=[])
    result = kakao.geocode_address(query)
    if not result.ok:
        return GeocodeOut(source="none", items=[])
    return GeocodeOut(source="kakao", items=result.data)


def search_places(query: str, lat: float | None, lon: float | None) -> PlaceSearchOut:
    kakao = get_kakao_service()
    if not kakao.is_enabled:
        return PlaceSearchOut(source="none", items=[])
    result = kakao.search_keyword(query, lat, lon)
    if not result.ok:
        return PlaceSearchOut(source="none", items=[])
    return PlaceSearchOut(source="kakao", items=result.data)


def _nearest_local_region(lat: float, lon: float) -> ReverseGeocodeOut:
    best = min(REGIONS, key=lambda r: haversine_km(lat, lon, r["lat"], r["lon"]))
    dist = haversine_km(lat, lon, best["lat"], best["lon"])
    return ReverseGeocodeOut(source="local", regionId=best["id"], regionName=best["name"], distanceKm=round(dist, 2))


def reverse_geocode(lat: float, lon: float) -> ReverseGeocodeOut:
    kakao = get_kakao_service()
    local = _nearest_local_region(lat, lon)
    if not kakao.is_enabled:
        return local

    result = kakao.reverse_geocode(lat, lon)
    if not result.ok:
        return local

    # 카카오가 돌려준 행정동 이름은 참고용 주소로 담고, 서비스가 쓰는 10개 지역(REGIONS) 중
    # 가장 가까운 곳을 regionId로 써서 코스 플래너 등 다른 Agent와 데이터를 맞춥니다.
    return ReverseGeocodeOut(
        source="kakao",
        regionId=local.regionId,
        regionName=local.regionName,
        distanceKm=local.distanceKm,
        fullAddress=result.data.get("fullAddress"),
    )
