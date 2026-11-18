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

import json
import logging

from app.data.tourist_data import KIND_LABEL, PLACES, REGIONS_BY_ID, WEATHER
from app.errors import ApiError
from app.schemas import AlternativeRequest, CourseOut, CourseRequest, CourseStopOut, ProfileOut, WeatherOut
from app.services.course_session import CoursePrefs
from app.services.datahub_service import region_crowd
from app.services.geo import haversine_km, travel_minutes
from app.services.llm_service import get_llm_service
from app.services.rating import live_rating

logger = logging.getLogger("jejuitda.course")

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
    rating = live_rating(place)
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
    text = f"혼잡도 {level} · 평소보다 {abs(pct)}% {'붐벼요' if pct > 0 else '한산해요'}" if pct else f"혼잡도 {level} · 평소 수준이에요"
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
    # predicate 는 함수 하나 또는 우선순위 순서의 함수 목록. 전부 만족하는 후보가 없으면
    # 뒤쪽 조건부터 하나씩 풀어 봅니다.
    preds = [predicate] if callable(predicate) else [f for f in (predicate or []) if f]
    for n in range(len(preds), 0, -1):
        filtered = [p for p in pool if all(f(p) for f in preds[:n])]
        if filtered:
            pool = filtered
            break
    if not pool:
        return None

    def key(p: dict) -> float:
        dist = haversine_km(last_point[0], last_point[1], p["lat"], p["lon"])
        return _place_score(profile, p, rain, crowd) - dist * 1.5  # 가까운 곳을 약간 우대

    return max(pool, key=key)


def plan_course(req: CourseRequest, prefs: CoursePrefs | None = None) -> CourseOut:
    return CourseOut(weather=WeatherOut(code=req.weather, **WEATHER[req.weather]), stops=_plan_stops(req, prefs))


def _plan_stops(req: CourseRequest, prefs: CoursePrefs | None = None) -> list[CourseStopOut]:
    origin = REGIONS_BY_ID.get(req.regionId)
    if origin is None:
        raise ApiError(404, "REGION_NOT_FOUND", f"알 수 없는 지역이에요: {req.regionId}")
    rain = req.weather == "rain"
    seafood = req.options.seafood
    crowd = region_crowd()  # 캐시만 읽음 (없으면 None → 혼잡도 0)
    used: set[str] = set()
    stops: list[dict] = []
    last_point = (origin["lat"], origin["lon"])

    prefs = prefs or CoursePrefs()
    candidates = [p for p in PLACES if p["id"] not in prefs.exclude_ids]

    order = _category_order(rain)
    if prefs.kids:  # 아이와 함께면 노을 명소 대신 산책·체험
        order = [["indoor", "spot"] if k == ["sunset"] else k for k in order]
    for kinds in order:
        kinds = [k for k in kinds if k not in prefs.exclude_kinds]
        if not kinds:
            continue
        predicate = None
        if "food" in kinds and seafood:
            predicate = lambda p: p.get("seafood")
        elif rain:
            predicate = lambda p: p["indoor"]
        # 대화로 요청한 "바다 보이는 곳"을 가장 먼저 지키고, 없으면 풀어 줌
        ocean = (lambda p: p.get("ocean") or p["kind"] not in prefs.ocean_kinds) if prefs.ocean_kinds else None
        kids = (lambda p: p.get("kids")) if prefs.kids else None
        mood = (lambda p: p.get("mood") or p["kind"] != "cafe") if prefs.mood_cafe else None
        predicates = [kids, mood, ocean, predicate]

        place = _pick_best(candidates, kinds, used, req.profile, rain, last_point, predicates, crowd)
        if not place:
            place = _pick_best(candidates, kinds, used, req.profile, rain, last_point, None, crowd)
        if place:
            used.add(place["id"])
            stops.append(place)
            last_point = (place["lat"], place["lon"])

    keep = max(2, len(stops) - req.options.removeCount)
    return _schedule(stops[:keep], req, crowd)


def _minutes(hhmm: str) -> int:
    h, m = (int(x) for x in hhmm.split(":"))
    return h * 60 + m


def _move_factor(profile: ProfileOut) -> float:
    """버스·배만 타면 자동차보다 이동이 오래 걸립니다 (자동차·택시·렌터카가 하나라도 있으면 1배)"""
    t = profile.transport or ""
    if not t or any(w in t for w in ("자동차", "택시", "렌터카", "차")):
        return 1.0
    return 1.6


def _schedule(places: list[dict], req: CourseRequest, crowd: dict | None, why: dict[str, str] | None = None) -> list[CourseStopOut]:
    start = _minutes(req.startTime)
    if req.endTime:
        end_limit = _minutes(req.endTime)
        if end_limit <= start:
            end_limit += 24 * 60  # 자정을 넘기는 여행
    else:
        hours = req.hours or req.profile.hours
        end_limit = start + hours * 60 if hours else None
    factor = _move_factor(req.profile)
    t = start
    out_stops: list[CourseStopOut] = []
    prev: dict | None = None
    for place in places:
        if prev is None:
            move = 0
        else:
            km = haversine_km(prev["lat"], prev["lon"], place["lat"], place["lon"])
            move = round(travel_minutes(km) * factor)
        # 여행 끝 시각을 넘기는 장소는 뺍니다 (최소 2곳은 유지)
        if end_limit is not None and len(out_stops) >= 2 and t + move + place["stay"] > end_limit:
            break
        t += move
        at = f"{(t // 60) % 24:02d}:{t % 60:02d}"
        t += place["stay"]
        reasons = _with_real_crowd_reason(place, crowd)
        if why and why.get(place["id"]):
            reasons = [["AI", why[place["id"]]], *reasons]
        out_stops.append(CourseStopOut(**{**place, "rating": live_rating(place), "reasons": reasons}, at=at, move=move))
        prev = place
    return out_stops


# ── 다른 코스 보기 (GPT) ─────────────────────────
PHASE = {"cafe": 0, "spot": 0, "indoor": 0, "sunset": 1, "food": 2}

_ALT_SYSTEM = """너는 제주 여행 코스 플래너 Agent야. 사용자가 "다른 코스 보기"를 눌렀어.
지금까지 보여 준 코스와 겹치지 않는 새 코스를 후보 장소 중에서만 골라 JSON 으로 답해.
{"summary": "<새 코스를 한 문장으로 소개 (어떤 점이 달라졌는지)>",
 "stops": [{"id": "<후보 id>", "why": "<이 사람에게 고른 이유, 25자 이내>"}]}
규칙:
- 3~5곳. 하루 흐름은 낮(카페·산책·실내) → 노을 → 저녁 식사 순서.
- 출발 지역에서 너무 멀지 않게 (후보의 km 참고), 이동 수단과 동행·성향을 고려해.
- 비가 오면 실내(indoor=true) 위주. 해산물·아이 동반·분위기 좋은 카페 같은 요청(prefs)이 있으면 지켜.
- 꼭 필요할 때만 이전 코스 장소를 1곳까지 다시 써도 돼.
- 후보 목록에 없는 id 는 쓰지 마."""


def plan_alternative(req: AlternativeRequest, prefs: CoursePrefs | None = None) -> CourseOut:
    """지금까지 본 코스(avoid)를 피해 새 코스. GPT 가 고르고, 안 되면 규칙 기반으로 avoid 를 뺀 코스."""
    origin = REGIONS_BY_ID.get(req.regionId)
    if origin is None:
        raise ApiError(404, "REGION_NOT_FOUND", f"알 수 없는 지역이에요: {req.regionId}")
    prefs = prefs or CoursePrefs()
    crowd = region_crowd()
    rain = req.weather == "rain"
    avoid = set(req.avoid)
    pool = [p for p in PLACES if p["id"] not in prefs.exclude_ids]
    near = sorted(pool, key=lambda p: haversine_km(origin["lat"], origin["lon"], p["lat"], p["lon"]))[:18]
    weather = WeatherOut(code=req.weather, **WEATHER[req.weather])

    llm = get_llm_service()
    if llm.is_enabled:
        cands = [{"id": p["id"], "name": p["name"], "kind": p["kind"], "indoor": p["indoor"], "seafood": p["seafood"],
                  "kids": p.get("kids", False), "moodCafe": p.get("mood", False), "rating": live_rating(p),
                  "km": round(haversine_km(origin["lat"], origin["lon"], p["lat"], p["lon"]), 1),
                  "shownBefore": p["id"] in avoid} for p in near]
        prof = req.profile
        prompt = json.dumps({
            "출발": origin["name"], "성향": f"{prof.name} ({prof.code})", "태그": prof.tags,
            "동행": prof.companion, "이동 수단": prof.transport, "시간": f"{req.startTime}~{req.endTime or ''}",
            "날씨": "비" if rain else "맑음", "해산물 저녁": req.options.seafood,
            "prefs": {"아이 동반": prefs.kids, "분위기 좋은 카페": prefs.mood_cafe, "뺄 종류": sorted(prefs.exclude_kinds)},
            "이전 코스": [PLACES_BY_ID_LOCAL[i]["name"] for i in req.avoid if i in PLACES_BY_ID_LOCAL],
            "후보": cands,
        }, ensure_ascii=False)
        res = llm.chat(_ALT_SYSTEM, prompt, json_mode=True, temperature=0.8)
        if res.ok and res.data:
            ids, why = [], {}
            valid = {p["id"] for p in near}
            for s in res.data.get("stops") or []:
                pid = s.get("id") if isinstance(s, dict) else None
                if pid in valid and pid not in ids:
                    ids.append(pid)
                    why[pid] = str(s.get("why") or "")[:40]
            if len(ids) >= 2 and len([i for i in ids if i in avoid]) <= 1:
                places = sorted((PLACES_BY_ID_LOCAL[i] for i in ids[:5]), key=lambda p: PHASE.get(p["kind"], 0))
                stops = _schedule(places, req, crowd, why)
                if len(stops) >= 2:
                    return CourseOut(weather=weather, stops=stops, source="gpt",
                                     summary=str(res.data.get("summary") or "").strip() or None)
        logger.info("다른 코스: GPT 결과를 쓸 수 없어 규칙 기반으로 짭니다 (%s)", res.error if not res.ok else "형식 오류")

    # 규칙 기반: 이전 장소를 빼고 다시 (후보가 모자라면 덜 빼고)
    alt = prefs.copy()
    alt.exclude_ids |= avoid
    stops = _plan_stops(req, alt)
    if len(stops) < 3:
        alt.exclude_ids = prefs.exclude_ids | set(req.avoid[-len(req.avoid) // 2:] if req.avoid else [])
        stops = _plan_stops(req, alt)
    return CourseOut(weather=weather, stops=stops, source="rule",
                     summary="이전에 본 코스와 다른 장소 위주로 다시 골랐어요.")


PLACES_BY_ID_LOCAL = {p["id"]: p for p in PLACES}


# ── 대화로 코스 고치기 (GPT) ─────────────────────
_EDIT_SYSTEM = """너는 제주 여행 코스 플래너 Agent야. 사용자가 지금 코스를 보고 자유롭게 말하면,
그 말대로 코스를 고쳐서 JSON 으로만 답해.
{"reply": "<사용자에게 보여줄 한국어 답변 1~2문장. 무엇을 어떻게 바꿨는지, 넣은 장소 이름을 그대로>",
 "stops": [{"id": "<후보 id>", "why": "<고른 이유 25자 이내>"}] 또는 null}
규칙:
- stops 에는 고친 뒤의 코스 전체를 방문 순서대로 적어 (그대로 두는 장소도 포함).
- 장소는 반드시 후보 목록의 id 만 써. 후보에 없는 장소나 이름을 지어내지 마.
- 사용자가 원하는 종류(예: 미술관, 기념품샵, 아이와 갈 곳, 해산물, 바다 보이는 카페)는 후보의 kind·label·tags·desc 를 보고 골라.
  같은 조건이면 지금 코스와 가까운(km) 곳을 골라.
- 넣어 달라는 요청은 기존 장소를 지우지 말고 알맞은 자리에 끼워 넣어. 빼 달라는 장소만 빼.
- 하루 흐름은 낮(카페·산책·실내) → 노을 → 저녁 식사. 여행 시간(시작~끝) 안에 다 돌 수 있게 2~7곳.
- 비가 오면 실내(indoor=true) 위주.
- 코스를 바꿀 필요가 없는 질문(예: 여기 주차돼?)이면 stops 는 null 로 두고 reply 로만 답해.
- 후보 중에 원하는 종류가 없으면 stops 는 null, reply 에서 없다고 솔직하게 말해."""


def edit_course_by_chat(message: str, history: list[tuple[str, str]], current_ids: list[str],
                        req: CourseRequest) -> tuple[str, CourseOut | None] | None:
    """사용자 말 그대로 GPT 에게 코스 수정을 맡깁니다. GPT 가 꺼져 있거나 실패하면 None (규칙 기반으로)."""
    llm = get_llm_service()
    if not llm.is_enabled:
        return None
    origin = REGIONS_BY_ID.get(req.regionId)
    if origin is None:
        return None
    cur = [PLACES_BY_ID_LOCAL[i] for i in current_ids if i in PLACES_BY_ID_LOCAL]
    anchors = cur or [origin]

    def km(p: dict) -> float:
        return round(min(haversine_km(a["lat"], a["lon"], p["lat"], p["lon"]) for a in anchors), 1)

    cands = [{"id": p["id"], "name": p["name"], "kind": p["kind"], "label": p.get("label") or KIND_LABEL[p["kind"]],
              "addr": p.get("addr", ""), "tags": p.get("tags", []), "desc": p["reasons"][0][1] if p["reasons"] else "",
              "indoor": p["indoor"], "seafood": p["seafood"], "kids": p.get("kids", False),
              "oceanView": p.get("ocean", False), "stayMin": p["stay"], "km": km(p)} for p in PLACES]
    prof = req.profile
    prompt = json.dumps({
        "출발": origin["name"], "성향": f"{prof.name} ({prof.code})", "동행": prof.companion, "이동 수단": prof.transport,
        "여행 시간": f"{req.startTime}~{req.endTime or ''}", "날씨": "비" if req.weather == "rain" else "맑음",
        "지금 코스": [{"id": p["id"], "name": p["name"], "label": p.get("label") or KIND_LABEL[p["kind"]]} for p in cur],
        "앞선 대화": [f"{'사용자' if who == 'me' else 'Agent'}: {text}" for who, text in history[-6:]],
        "후보(km 는 지금 코스에서 가장 가까운 거리)": sorted(cands, key=lambda c: c["km"]),
    }, ensure_ascii=False)
    res = llm.chat(_EDIT_SYSTEM, f"{prompt}\n\n사용자: {message}", json_mode=True, temperature=0.4)
    if not (res.ok and res.data):
        logger.info("대화 수정: GPT 실패, 규칙 기반으로 (%s)", res.error)
        return None
    reply = str(res.data.get("reply") or "").strip()
    raw = res.data.get("stops")
    if not reply:
        return None
    if raw is None:
        return reply, None
    ids, why = [], {}
    for s in raw if isinstance(raw, list) else []:
        pid = s.get("id") if isinstance(s, dict) else s if isinstance(s, str) else None
        if pid in PLACES_BY_ID_LOCAL and pid not in ids:
            ids.append(pid)
            if isinstance(s, dict) and s.get("why"):
                why[pid] = str(s["why"])[:40]
    if len(ids) < 2:
        logger.info("대화 수정: GPT 가 고른 장소가 2곳 미만이라 쓰지 않습니다 (%s)", raw)
        return None
    stops = _schedule([PLACES_BY_ID_LOCAL[i] for i in ids[:7]], req, region_crowd(), why)
    weather = WeatherOut(code=req.weather, **WEATHER[req.weather])
    return reply, CourseOut(weather=weather, stops=stops, source="gpt", summary=None)


__all__ = ["plan_course", "plan_alternative", "edit_course_by_chat", "KIND_LABEL", "WEATHER"]
