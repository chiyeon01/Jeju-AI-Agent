# ─────────────────────────────────────────────
# 실시간 날씨 (프론트·앱이 GET /weather/now 로 받음)
#  1) KMA_SERVICE_KEY 가 있으면 기상청 초단기실황
#  2) 없거나 실패하면 Open-Meteo (키 필요 없음)
# 브라우저가 직접 부르면 CORS·네트워크 차단으로 실패할 수 있어 서버가 대신 가져옵니다.
# 같은 격자는 10분 동안 캐시합니다.
# ─────────────────────────────────────────────
from __future__ import annotations

import logging
import math
import threading
import time
from datetime import datetime, timedelta, timezone

import httpx

from app.config import get_settings
from app.errors import ApiError

logger = logging.getLogger("jejuitda.weather")
KST = timezone(timedelta(hours=9))
CACHE_SECONDS = 600
_cache: dict[tuple, tuple[float, dict]] = {}
_lock = threading.Lock()

PTY = {1: "비", 2: "비/눈", 3: "눈", 5: "빗방울", 6: "빗방울눈날림", 7: "눈날림"}


def to_kma_grid(lat: float, lon: float) -> tuple[int, int]:
    """위경도 → 기상청 격자(nx, ny), 동네예보 LCC 변환 공식."""
    re_, grid, slat1, slat2, olon, olat, xo, yo = 6371.00877, 5.0, 30.0, 60.0, 126.0, 38.0, 43, 136
    d = math.pi / 180.0
    re = re_ / grid
    slat1, slat2, olon, olat = slat1 * d, slat2 * d, olon * d, olat * d
    sn = math.log(math.cos(slat1) / math.cos(slat2)) / math.log(
        math.tan(math.pi * 0.25 + slat2 * 0.5) / math.tan(math.pi * 0.25 + slat1 * 0.5))
    sf = math.tan(math.pi * 0.25 + slat1 * 0.5) ** sn * math.cos(slat1) / sn
    ro = re * sf / math.tan(math.pi * 0.25 + olat * 0.5) ** sn
    ra = re * sf / math.tan(math.pi * 0.25 + lat * d * 0.5) ** sn
    theta = lon * d - olon
    if theta > math.pi:
        theta -= 2 * math.pi
    if theta < -math.pi:
        theta += 2 * math.pi
    theta *= sn
    return int(ra * math.sin(theta) + xo + 0.5), int(ro - ra * math.cos(theta) + yo + 0.5)


def _from_kma(lat: float, lon: float, key: str) -> dict:
    nx, ny = to_kma_grid(lat, lon)
    base = datetime.now(KST) - timedelta(minutes=40)  # 정시 자료가 약 40분 뒤 올라옴
    params = {"serviceKey": key, "pageNo": 1, "numOfRows": 10, "dataType": "JSON",
              "base_date": base.strftime("%Y%m%d"), "base_time": base.strftime("%H00"), "nx": nx, "ny": ny}
    resp = httpx.get("https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst", params=params, timeout=5)
    try:
        body = resp.json()
    except ValueError as e:
        raise RuntimeError(f"기상청 응답이 JSON 이 아니에요 (키 확인 필요): {resp.text[:120]}") from e
    head = body.get("response", {}).get("header", {})
    if head.get("resultCode") != "00":
        raise RuntimeError(f"기상청 오류 {head.get('resultCode')}: {head.get('resultMsg')}")
    items = body["response"]["body"]["items"]["item"]
    v = {i["category"]: float(i["obsrValue"]) for i in items}
    pty = int(v.get("PTY", 0))
    snow = pty in (3, 7)
    return {"code": "rain" if pty > 0 else "clear", "label": PTY.get(pty, "맑음") if pty else "맑음",
            "icon": ("🌨️" if snow else "🌧️") if pty else "☀️", "temp": v.get("T1H"), "humidity": v.get("REH"),
            "wind": v.get("WSD"), "rain1h": v.get("RN1", 0.0), "source": "기상청", "at": f"{params['base_time'][:2]}:00"}


def _wmo(code: int) -> tuple[str, str, str]:
    if code == 0:
        return "맑음", "☀️", "clear"
    if code <= 3:
        return "구름 조금", "⛅", "clear"
    if code in (45, 48):
        return "안개", "🌫️", "clear"
    if 71 <= code <= 77 or code in (85, 86):
        return "눈", "🌨️", "rain"
    if code >= 95:
        return "뇌우", "⛈️", "rain"
    return "비", "🌧️", "rain"


def _from_open_meteo(lat: float, lon: float) -> dict:
    resp = httpx.get("https://api.open-meteo.com/v1/forecast", timeout=5, params={
        "latitude": lat, "longitude": lon, "wind_speed_unit": "ms", "timezone": "Asia/Seoul",
        "current": "temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m"})
    resp.raise_for_status()
    c = resp.json()["current"]
    label, icon, code = _wmo(int(c["weather_code"]))
    return {"code": code, "label": label, "icon": icon, "temp": c["temperature_2m"], "humidity": c["relative_humidity_2m"],
            "wind": c["wind_speed_10m"], "rain1h": c.get("precipitation") or 0.0, "source": "Open-Meteo",
            "at": str(c.get("time", ""))[11:16]}


def live_weather(lat: float, lon: float) -> dict:
    key = (round(lat, 2), round(lon, 2))
    with _lock:
        hit = _cache.get(key)
        if hit and time.time() - hit[0] < CACHE_SECONDS:
            return hit[1]
    errors = []
    kma_key = get_settings().kma_service_key.strip()
    result = None
    if kma_key:
        try:
            result = _from_kma(lat, lon, kma_key)
        except Exception as e:  # noqa: BLE001 - 외부 API
            errors.append(str(e))
            logger.warning("기상청 실패, Open-Meteo 로 대신합니다: %s", e)
    if result is None:
        try:
            result = _from_open_meteo(lat, lon)
        except Exception as e:  # noqa: BLE001 - 외부 API
            errors.append(f"Open-Meteo: {e}")
    if result is None:
        raise ApiError(502, "WEATHER_UNAVAILABLE", "실시간 날씨를 가져오지 못했어요: " + " / ".join(errors))
    with _lock:
        _cache[key] = (time.time(), result)
    return result
