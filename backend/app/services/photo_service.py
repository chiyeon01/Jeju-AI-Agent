# ─────────────────────────────────────────────
# 장소 대표 사진 (네이버 검색 API · 이미지)
#  GET https://openapi.naver.com/v1/search/image?query=... (X-Naver-Client-Id / Secret)
#  - 키가 없으면 None → 화면은 사진 없이 이름만 보여 줍니다
#  - 같은 검색어는 하루 동안 캐시 (네이버 검색 API 하루 25,000건 한도)
# ─────────────────────────────────────────────
from __future__ import annotations

import logging
import threading
import time

import httpx

from app.config import get_settings

logger = logging.getLogger("jejuitda.photo")
CACHE_SECONDS = 24 * 3600
_cache: dict[str, tuple[float, dict | None]] = {}
_lock = threading.Lock()


def place_photo(query: str) -> dict | None:
    """{ thumbnail, image, link, title } 또는 None"""
    q = " ".join(query.split())[:60]
    if not q:
        return None
    with _lock:
        hit = _cache.get(q)
        if hit and time.time() - hit[0] < CACHE_SECONDS:
            return hit[1]
    s = get_settings()
    if not (s.naver_client_id.strip() and s.naver_client_secret.strip()):
        return None
    result = None
    try:
        resp = httpx.get("https://openapi.naver.com/v1/search/image",
                         params={"query": q, "display": 3, "sort": "sim", "filter": "medium"},
                         headers={"X-Naver-Client-Id": s.naver_client_id.strip(),
                                  "X-Naver-Client-Secret": s.naver_client_secret.strip()}, timeout=5)
        resp.raise_for_status()
        items = resp.json().get("items") or []
        if items:
            it = items[0]
            result = {"thumbnail": it.get("thumbnail"), "image": it.get("link"), "title": it.get("title"), "source": "naver"}
    except Exception as e:  # noqa: BLE001 - 외부 API, 실패하면 사진 없이
        logger.warning("네이버 이미지 검색 실패 (%s): %s", q, e)
        return None  # 실패는 캐시하지 않음
    with _lock:
        _cache[q] = (time.time(), result)
    return result
