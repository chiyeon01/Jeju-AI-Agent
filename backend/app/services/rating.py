# ─────────────────────────────────────────────
# 장소 평점 = 초기 평점(tourist_data) + 관광객이 앱에서 남긴 실제 별점
#  - 평가가 없으면 초기 평점 그대로 (콜드스타트)
#  - 평가가 쌓일수록 실제 별점 평균 쪽으로 옮겨 갑니다 (초기 평점을 PRIOR_N 건으로 취급)
# 코스 점수·코스 응답·장소 목록이 모두 이 값을 씁니다.
# ─────────────────────────────────────────────
from __future__ import annotations

import threading
import time

from app import db

PRIOR_N = 5
_TTL_SECONDS = 30

_lock = threading.Lock()
_cache: tuple[float, dict[str, dict]] | None = None


def _stats() -> dict[str, dict]:
    global _cache
    with _lock:
        if _cache and time.monotonic() - _cache[0] < _TTL_SECONDS:
            return _cache[1]
        stats = db.review_stats_by_place()
        _cache = (time.monotonic(), stats)
        return stats


def invalidate() -> None:
    """새 평가가 저장되면 다음 요청부터 바로 반영되게 캐시를 비웁니다."""
    global _cache
    with _lock:
        _cache = None


def live_rating(place: dict) -> float:
    s = _stats().get(place["id"])
    if not s or not s["count"]:
        return place["rating"]
    n = s["count"]
    return round((place["rating"] * PRIOR_N + s["avg"] * n) / (PRIOR_N + n), 2)


def with_live_rating(place: dict) -> dict:
    return {**place, "rating": live_rating(place)}
