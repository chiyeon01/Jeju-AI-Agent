# ─────────────────────────────────────────────
# 위경도 기반 거리·이동시간 계산
# 프론트 목업(client.js)은 SVG 지도 픽셀 좌표로 근사했지만,
# 백엔드는 실제 위도·경도(모든 PLACES/REGIONS가 가지고 있음)로 더 정확하게 계산합니다.
# ─────────────────────────────────────────────
from __future__ import annotations

from math import asin, cos, radians, sin, sqrt

EARTH_RADIUS_KM = 6371.0


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """두 위경도 좌표 사이의 대원거리(직선거리, km)."""
    p1, p2 = radians(lat1), radians(lat2)
    dp = radians(lat2 - lat1)
    dl = radians(lon2 - lon1)
    a = sin(dp / 2) ** 2 + cos(p1) * cos(p2) * sin(dl / 2) ** 2
    return 2 * EARTH_RADIUS_KM * asin(sqrt(a))


def travel_minutes(distance_km: float) -> int:
    """직선거리(km) × 1.3(도로 보정) ÷ 평균 35km/h + 주차·도보 4분. 최소 5분."""
    if distance_km <= 0:
        return 0
    road_km = distance_km * 1.3
    minutes = (road_km / 35) * 60 + 4
    return max(5, round(minutes))
