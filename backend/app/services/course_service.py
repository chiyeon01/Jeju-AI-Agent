# ─────────────────────────────────────────────
# 코스 플래너 Agent
#
# 기획서(5.3) 공식을 그대로 구현합니다.
#   장소점수 = w1·성향적합도 + w2·데이터인기도(D1,D3) + w3·평가점수(자체)
#            − w4·혼잡도(D2) − w5·이동시간(D6) + w6·날씨적합도(D7)
# - 성향적합도: 성향 코드(공간 N/C, 취향 F/P)와 장소 종류(kind)의 일치 여부
# - 데이터인기도: PLACES.reasons 의 데이터 코드 수(D1~D8이 많이 뒷받침할수록 인기) — 실데이터
#   연동 시 D1(카드)·D3(와이파이/내비) 실제 지표값으로 교체
# - 평가점수: 장소 평점(rating, 자체 앱 평가가 쌓이기 전에는 초기 평점으로 콜드스타트)
# - 혼잡도: 제주데이터허브 D2(읍면동 내국인 유동인구) 최신 날짜 기준 지역 혼잡도 지수(0~1).
#   datahub_service.region_crowd() 캐시만 읽음 → 허브가 느리거나 실패해도 코스는 혼잡도 0으로 동작
# - 이동시간: 직전 정류지에서의 실제 이동 분(geo.travel_minutes)
# - 날씨적합도: 비 오는 날 실내 장소 가중치
#
# 순서 구성(그리디)은 "카페 → 명소/노을 → 식사"처럼 시간대 성격이 있는 카테고리를
# 순서대로 하나씩 채우고, 비 오는 날은 실내 카테고리로 자동 전환합니다(기획서 4.1-(2)).
# 이동 순서 자체는 카테고리 순서 + 카테고리 내 최적 장소 선택으로 구성해 간단한 그리디
# TSP 역할을 합니다 (기획서가 말하는 "그리디 + 2-opt"의 그리디 단계; 2-opt 교환은 TODO).
# ─────────────────────────────────────────────
from __future__ import annotations

from app.data.tourist_data import KIND_LABEL, PLACES, REGIONS_BY_ID, WEATHER
from app.errors import ApiError
from app.schemas import CourseOut, CourseRequest, CourseStopOut, ProfileOut, WeatherOut
from app.services.datahub_service import region_crowd
from app.services.geo import haversine_km, travel_minutes

W1_AFFINITY = 18.0
W2_POPULARITY = 6.0
W3_RATING = 14.0
W4_CONGESTION = 15.0
W5_TRAVEL_PENALTY = 0.6
W6_WEATHER = 20.0


def _affinity_score(profile: ProfileOut, place: dict) -> float:
    """성향 코드(공간 N/C, 취향 F/P)와 장소 종류의 일치도."""
    code = profile.code or ""
    score = 0.0
    space = code[1] if len(code) > 1 else ""
    taste = code[2] if len(code) > 2 else ""
    outdoor_kinds = {"spot", "sunset"}
    indoor_social_kinds = {"cafe", "food", "indoor"}
    if space == "N" and place["kind"] in outdoor_kinds:
        score += 1.0
    if space == "C" and place["kind"] in indoor_social_kinds:
        score += 0.6
    if taste == "F" and place["kind"] == "food":
        score += 1.0
    if taste == "P" and place["kind"] in {"spot", "sunset"}:
        score += 1.0
    return score


def _popularity_score(place: dict) -> float:
    """reasons에 D1~D8 데이터 근거가 많을수록 "데이터로 뒷받침되는 인기"로 간주."""
    return sum(1 for src, _ in place["reasons"] if src.startswith("D"))


def _congestion(place: dict, crowd: dict | None) -> float:
    if not crowd:
        return 0.0
    return (crowd["regions"].get(place["region"]) or {}).get("index", 0.0)


def _place_score(profile: ProfileOut, place: dict, rain: bool, crowd: dict | None = None) -> float:
    affinity = _affinity_score(profile, place)
    popularity = _popularity_score(place)
    rating = place["rating"]
    weather_fit = 1.0 if (rain and place["indoor"]) or (not rain and not place["indoor"]) else -0.5
    congestion = _congestion(place, crowd)
    return (
        W1_AFFINITY * affinity
        + W2_POPULARITY * popularity
        + W3_RATING * rating
        - W4_CONGESTION * congestion
        + W6_WEATHER * weather_fit
    )


def _with_real_crowd_reason(place: dict, crowd: dict | None) -> list[list[str]]:
    """D2(유동인구) 근거를 허브 실측값 문장으로 바꿉니다. 실측값이 없으면 기존 근거 그대로."""
    reasons = [list(r) for r in place["reasons"]]
    info = crowd and crowd["regions"].get(place["region"])
    if not info:
        return reasons
    pct = info["vsAveragePct"]
    level = "낮음" if info["index"] < 0.34 else "보통" if info["index"] < 0.67 else "높음"
    text = (f"읍면동 방문인구 하루 {info['visitPopPerEmd']:,}명 · 제주 평균 대비 "
            f"{'+' if pct >= 0 else ''}{pct}% → 혼잡도 {level} ({crowd['date']} 실측)")
    for r in reasons:
        if r[0] == "D2":
            r[1] = text
            return reasons
    return [*reasons, ["D2", text]]


def _category_order(rain: bool) -> list[list[str]]:
    if rain:
        return [["cafe"], ["indoor"], ["indoor", "cafe"], ["food"]]
    return [["cafe"], ["spot"], ["sunset"], ["food"]]


def _pick_best(
    candidates: list[dict],
    kinds: list[str],
    used: set[str],
    profile: ProfileOut,
    rain: bool,
    last_point: tuple[float, float],
    predicate=None,
    crowd: dict | None = None,
) -> dict | None:
    pool = [p for p in candidates if p["kind"] in kinds and p["id"] not in used]
    if predicate:
        filtered = [p for p in pool if predicate(p)]
        if filtered:
            pool = filtered
    if not pool:
        return None

    def key(p: dict) -> float:
        dist = haversine_km(last_point[0], last_point[1], p["lat"], p["lon"])
        return _place_score(profile, p, rain, crowd) - dist * 1.5  # 가까운 곳을 약간 우대

    return max(pool, key=key)


def plan_course(req: CourseRequest) -> CourseOut:
    origin = REGIONS_BY_ID.get(req.regionId)
    if origin is None:
        raise ApiError(404, "REGION_NOT_FOUND", f"알 수 없는 지역이에요: {req.regionId}")
    rain = req.weather == "rain"
    seafood = req.options.seafood
    crowd = region_crowd()  # 캐시만 읽음 (없으면 None → 혼잡도 0)
    used: set[str] = set()
    stops: list[dict] = []
    last_point = (origin["lat"], origin["lon"])

    for kinds in _category_order(rain):
        predicate = None
        if "food" in kinds and seafood:
            predicate = lambda p: p.get("seafood")
        elif rain:
            predicate = lambda p: p["indoor"]

        place = _pick_best(PLACES, kinds, used, req.profile, rain, last_point, predicate, crowd)
        if not place:
            place = _pick_best(PLACES, kinds, used, req.profile, rain, last_point, None, crowd)
        if place:
            used.add(place["id"])
            stops.append(place)
            last_point = (place["lat"], place["lon"])

    keep = max(2, len(stops) - req.options.removeCount)
    trimmed = stops[:keep]

    h, m = (int(x) for x in req.startTime.split(":"))
    start = h * 60 + m
    hours = req.hours or req.profile.hours
    end_limit = start + hours * 60 if hours else None
    t = start
    out_stops: list[CourseStopOut] = []
    prev: dict | None = None
    for place in trimmed:
        if prev is None:
            move = 0
        else:
            km = haversine_km(prev["lat"], prev["lon"], place["lat"], place["lon"])
            move = travel_minutes(km)
        # 이용 시간(hours)을 넘기는 장소는 뺍니다 (최소 2곳은 유지)
        if end_limit is not None and len(out_stops) >= 2 and t + move + place["stay"] > end_limit:
            break
        t += move
        at = f"{(t // 60) % 24:02d}:{t % 60:02d}"
        t += place["stay"]
        out_stops.append(
            CourseStopOut(
                **{**place, "reasons": _with_real_crowd_reason(place, crowd)},
                at=at,
                move=move,
            )
        )
        prev = place

    return CourseOut(weather=WeatherOut(code=req.weather, **WEATHER[req.weather]), stops=out_stops)


__all__ = ["plan_course", "KIND_LABEL", "WEATHER"]
