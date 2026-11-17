# ─────────────────────────────────────────────
# 제주데이터허브 데이터 가공 (Agent 공통 도구: crowd_forecast·weather 등의 실데이터 버전)
# 원본 행은 datahub_client 가 가져오고, 여기서는 서비스가 쓰기 좋은 형태로 합칩니다.
# 숫자는 모두 Python으로 계산합니다 (LLM은 이 결과를 설명만 함).
# ─────────────────────────────────────────────
from __future__ import annotations

import logging
import threading
import time
from collections import defaultdict
from datetime import date, timedelta

from app.data.datahub_catalog import DATASETS, EMD_REGION, REGION_EMD
from app.data.tourist_data import REGIONS_BY_ID
from app.services.datahub_client import DataHubError, get_datahub_client

logger = logging.getLogger("jejuitda.datahub")

LATEST_TTL_SECONDS = 12 * 3600
_latest_cache: dict[str, tuple[float, date | None]] = {}
_crowd_cache: dict | None = None
_crowd_lock = threading.Lock()


def _num(v) -> float:
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def _ymd(d: date) -> str:
    return d.strftime("%Y%m%d")


def parse_date(s: str | None) -> date | None:
    if not s:
        return None
    s = s.replace("-", "")
    return date(int(s[:4]), int(s[4:6]), int(s[6:8]) if len(s) >= 8 else 1)


# ── 최신 데이터 날짜 찾기 ─────────────────────
def known_latest_date(dataset: str) -> date | None:
    """이미 찾아 둔 최신 날짜(없으면 None). 관리 콘솔이 허브를 부르지 않고 보여줄 때 씀."""
    hit = _latest_cache.get(dataset)
    return hit[1] if hit else None


def latest_date(dataset: str, max_back_days: int = 4000) -> date | None:
    """오늘부터 거꾸로 데이터가 있는 가장 최근 날짜를 찾습니다 (지수 탐색 + 이분 탐색, 약 10~15회 호출).
    결과는 12시간 동안 메모리에 둡니다."""
    hit = _latest_cache.get(dataset)
    if hit and time.time() - hit[0] < LATEST_TTL_SECONDS:
        return hit[1]

    client = get_datahub_client()
    monthly = DATASETS[dataset].get("date_format") == "%Y%m"
    step = 31 if monthly else 1

    def probe(d: date) -> bool:
        # 허브가 특정 날짜에 계속 5xx를 주면 하루(월 단위면 한 달)씩 옆 날짜로 다시 확인
        for shift in (0, -1, 1):
            r = client.has_data(dataset, d + timedelta(days=shift * step))
            if r is not None:
                return r
        return False

    today = date.today()
    newer = today  # 데이터 없음이 확인된 날짜
    older: date | None = None  # 데이터 있음이 확인된 날짜
    back = step
    while back <= max_back_days:
        d = today - timedelta(days=back)
        if probe(d):
            older = d
            break
        newer = d
        back *= 2
    if older is None:
        _latest_cache[dataset] = (time.time(), None)
        return None
    while (newer - older).days > step:
        mid = older + (newer - older) / 2
        if probe(mid):
            older = mid
        else:
            newer = mid
    if monthly:
        older = older.replace(day=1)
    _latest_cache[dataset] = (time.time(), older)
    return older


def _resolve_day(dataset: str, day: str | None) -> date:
    d = parse_date(day) or latest_date(dataset)
    if d is None:
        raise DataHubError(f"'{DATASETS[dataset]['title']}' 데이터가 있는 날짜를 찾지 못했어요", status=404)
    return d


def _fetch_day(dataset: str, day: str | None, build_params, fallback_days: int = 3):
    """날짜를 정해 가져옵니다. 날짜를 비웠을 때(최신) 그 날짜가 허브에서 계속 실패하면
    하루씩 앞 날짜로 최대 fallback_days 번 물러나 다시 시도합니다. 반환: (실제 날짜, FetchResult)."""
    d = _resolve_day(dataset, day)
    client = get_datahub_client()
    tries = 1 if day else fallback_days + 1
    last: DataHubError | None = None
    for i in range(tries):
        target = d - timedelta(days=i)
        try:
            return target, client.fetch(dataset, build_params(_ymd(target)))
        except DataHubError as e:
            if e.status in (429, 503, 422):
                raise
            last = e
            logger.info("%s %s 실패, 하루 전 날짜로 재시도: %s", dataset, target, e)
    raise last  # type: ignore[misc]


# ── 유동인구 (D2) ─────────────────────────────
def population(day: str | None = None, emd: str | None = None) -> dict:
    """읍면동별 내국인 유동인구 합계(성별·연령 합산)와 서비스 지역별 합계."""
    d, res = _fetch_day("population", day, lambda x: {"startDate": x, "endDate": x, "emd": emd})
    by_emd: dict[str, dict] = defaultdict(lambda: {"visitPop": 0, "resdPop": 0, "workPop": 0})
    city_of: dict[str, str] = {}
    for r in res.rows:
        e = r["emd"]
        city_of[e] = r["city"]
        for k in ("visitPop", "resdPop", "workPop"):
            by_emd[e][k] += int(_num(r.get(k)))
    emds = [{"city": city_of[e], "emd": e, "region": EMD_REGION.get(e), **v} for e, v in by_emd.items()]
    emds.sort(key=lambda x: -x["visitPop"])

    regions = []
    for rid, names in REGION_EMD.items():
        members = [x for x in emds if x["emd"] in names]
        if not members:
            continue
        visit = sum(x["visitPop"] for x in members)
        regions.append({
            "regionId": rid,
            "regionName": REGIONS_BY_ID[rid]["name"],
            "emdCount": len(members),
            "visitPop": visit,
            "visitPopPerEmd": round(visit / len(members)),
            "resdPop": sum(x["resdPop"] for x in members),
            "workPop": sum(x["workPop"] for x in members),
        })
    regions.sort(key=lambda x: -x["visitPop"])
    return {"date": d.isoformat(), "source": "D2", "dataset": DATASETS["population"]["title"],
            "complete": res.complete, "emds": emds, "regions": regions}


def foreign_population(kind: str = "short", day: str | None = None, emd: str | None = None,
                       nationality: str | None = None) -> dict:
    """외국인 단기/장기체류 유동인구: 국적별·읍면동별 합계."""
    dataset = "foreign_short" if kind == "short" else "foreign_long"
    d, res = _fetch_day(dataset, day, lambda x: {"startDate": x, "endDate": x, "emd": emd, "nationality": nationality})
    by_nat: dict[str, int] = defaultdict(int)
    by_emd: dict[str, int] = defaultdict(int)
    for r in res.rows:
        v = int(_num(r.get("visitPop")))
        by_nat[r["nationality"]] += v
        by_emd[r["emd"]] += v
    return {
        "date": d.isoformat(), "source": "D2", "dataset": DATASETS[dataset]["title"], "complete": res.complete,
        "total": sum(by_nat.values()),
        "byNationality": sorted(({"nationality": k, "visitPop": v} for k, v in by_nat.items()), key=lambda x: -x["visitPop"]),
        "byEmd": sorted(({"emd": k, "region": EMD_REGION.get(k), "visitPop": v} for k, v in by_emd.items()),
                        key=lambda x: -x["visitPop"]),
    }


def region_crowd(refresh: bool = False) -> dict | None:
    """서비스 지역별 혼잡도 지수(0~1). 최신 날짜 유동인구의 '읍면동당 방문인구'를 지역끼리 비교합니다.
    코스 플래너가 매 요청마다 부르므로 캐시만 읽고, 갱신은 refresh=True(시작 시 백그라운드)로 합니다."""
    global _crowd_cache
    if not refresh:
        return _crowd_cache
    with _crowd_lock:
        pop = population()
        regions = pop["regions"]
        if not regions:
            return _crowd_cache
        vals = [r["visitPopPerEmd"] for r in regions]
        lo, hi = min(vals), max(vals)
        avg = sum(vals) / len(vals)
        index = {
            r["regionId"]: {
                "index": round((r["visitPopPerEmd"] - lo) / (hi - lo), 3) if hi > lo else 0.0,
                "visitPopPerEmd": r["visitPopPerEmd"],
                "visitPop": r["visitPop"],
                "vsAveragePct": round((r["visitPopPerEmd"] / avg - 1) * 100),
            }
            for r in regions
        }
        _crowd_cache = {"date": pop["date"], "regions": index}
        logger.info("지역 혼잡도 갱신 (%s 기준, %d개 지역)", pop["date"], len(index))
        return _crowd_cache


# ── 기상 (D7) ─────────────────────────────────
def weather(day: str | None = None, observatory: str | None = None) -> dict:
    d, res = _fetch_day("weather", day, lambda x: {"searchDate": x, "observatoryName": observatory})
    items = [{
        "observatory": r["observatoryName"],
        "avgTemp": _num(r.get("averageTemperature")),
        "minTemp": _num(r.get("lowestTemperature")),
        "maxTemp": _num(r.get("highestTemperature")),
        "rainfallMm": _num(r.get("dailyRainfall")),
        "maxWindMs": _num(r.get("maximumWindSpeed")),
        "avgWindMs": _num(r.get("averageWindSpeed")),
    } for r in res.rows]
    rainy = [x for x in items if x["rainfallMm"] >= 1.0]
    return {"date": d.isoformat(), "source": "D7", "dataset": DATASETS["weather"]["title"],
            "rainyObservatoryRatio": round(len(rainy) / len(items), 2) if items else None,
            "observatories": items}


# ── 관광지 유입 (D4) ──────────────────────────
def sights(start: str | None = None, end: str | None = None, name: str | None = None) -> dict:
    """관광지별 내·외국인 유입자 수(월). 기간을 안 주면 최신 달."""
    s = parse_date(start) or latest_date("sights_domestic")
    if s is None:
        raise DataHubError("관광지 유입 데이터가 있는 달을 찾지 못했어요", status=404)
    e = parse_date(end) or s
    params = {"startDate": s.strftime("%Y%m"), "endDate": e.strftime("%Y%m"), "sightsName": name}
    client = get_datahub_client()
    merged: dict[tuple[str, str], dict] = {}
    for ds, key in (("sights_domestic", "domestic"), ("sights_foreign", "foreign")):
        for r in client.fetch(ds, params).rows:
            k = (r["dtYearMonth"], r["sightsName"].strip())
            item = merged.setdefault(k, {"yearMonth": k[0], "sightsName": k[1], "payType": r.get("payType"),
                                         "domestic": 0, "foreign": 0})
            item[key] += int(_num(r.get("userCnt")))
    items = sorted(merged.values(), key=lambda x: (x["yearMonth"], -(x["domestic"] + x["foreign"])))
    return {"start": s.strftime("%Y-%m"), "end": e.strftime("%Y-%m"), "source": "D4", "items": items}


# ── 버스 (D6) ─────────────────────────────────
def bus_stations(name: str | None = None, limit: int = 200) -> dict:
    res = get_datahub_client().fetch("bus_stations", {"stationName": name}, max_rows=limit)
    items = [{**r, "latitude": _num(r.get("latitude")), "longitude": _num(r.get("longitude"))} for r in res.rows]
    return {"source": "D6", "total": res.total, "items": items}


def bus_routes(start_station_id: str | None = None, limit: int = 200) -> dict:
    res = get_datahub_client().fetch("bus_routes", {"startStationId": start_station_id}, max_rows=limit)
    items = [{**r, "stationCount": int(_num(r.get("stationCount"))), "routeLengthM": int(_num(r.get("routeLength")))}
             for r in res.rows]
    return {"source": "D6", "total": res.total, "items": items}


def bus_usage(day: str | None = None, top: int = 30) -> dict:
    """정류소별 하루 이용자 수(승차+환승 합) 상위 N곳. 하루치 전체를 받아야 해서 처음엔 40~60회 호출됩니다."""
    d, res = _fetch_day("bus_usage", day, lambda x: {"startDate": x, "endDate": x})
    by: dict[str, dict] = {}
    for r in res.rows:
        s = by.setdefault(r["stationId"], {"stationId": r["stationId"], "stationName": r.get("stationName") or "",
                                           "boarding": 0, "transfer": 0})
        if r.get("stationName") and not s["stationName"]:
            s["stationName"] = r["stationName"]
        s["transfer" if r.get("moveType") == "환승" else "boarding"] += int(_num(r.get("userCount")))
    items = sorted(by.values(), key=lambda x: -(x["boarding"] + x["transfer"]))
    return {"date": d.isoformat(), "source": "D6", "stations": len(items), "items": items[:top]}


# ── 와이파이 (D3) ─────────────────────────────
def wifi_usage(day: str | None = None, top: int = 30, name: str | None = None) -> dict:
    d, res = _fetch_day("wifi_usage", day, lambda x: {"searchDate": x})
    rows = res.rows
    items = [{
        "apGroupName": r["apGroupName"],
        "userCount": int(_num(r.get("userCount"))),
        "sessionTimeSec": int(_num(r.get("sessionTime"))),
        "downloadMB": round(_num(r.get("downloadBytes")) / 1_048_576, 1),
    } for r in rows if not name or name in r["apGroupName"]]
    items.sort(key=lambda x: -x["userCount"])
    users = get_datahub_client().fetch("wifi_users", {"searchDate": _ymd(d)}).rows
    return {"date": d.isoformat(), "source": "D3",
            "totalUsers": int(_num(users[0]["userCount"])) if users else None,
            "apGroups": len(items), "items": items[:top]}


# ── 상태 ──────────────────────────────────────
def status() -> dict:
    client = get_datahub_client()
    return {
        "enabled": client.is_enabled,
        "callsToday": client.calls_today(),
        "regionCrowd": {"date": _crowd_cache["date"]} if _crowd_cache else None,
        "datasets": [{"key": k, "title": v["title"], "source": v["source"], "hubId": v["hub_id"],
                      "params": v["params"], "freshness": v["freshness"]} for k, v in DATASETS.items()],
    }
