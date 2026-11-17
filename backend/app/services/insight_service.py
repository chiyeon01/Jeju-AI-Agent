# ─────────────────────────────────────────────
# 실데이터 인사이트 (관광객 ↔ 상권 사이에 실제로 쌓인 데이터)
#  - 지역 점수 0~10 : 요청할 때마다 DB에서 바로 계산 (실시간)
#      만족도 50% : 관광객 별점 평균 (리뷰가 적으면 3.5점 쪽으로 당김)
#      수요   30% : 최근 7일 코스 선택 + 평가 건수 (로그 정규화)
#      쾌적함 20% : 데이터허브 지역 혼잡도 (낮을수록 높음, 없으면 나머지로 다시 배분)
#  - 지역 보고서 Agent : 집계 → GPT가 관리자용 문서 작성 → reports 테이블에 저장
#  - 가게 리뷰 분석 Agent : 가게(장소)의 별점·리뷰 → GPT 분석 → reports 테이블에 저장
# 허브 데이터는 Main PC 밖으로 나가면 안 되므로 GPT에는 "낮음/보통/높음" 등급만 넘깁니다.
# GPT 키가 없거나 실패하면 규칙 기반 문서로 대신 저장합니다.
# ─────────────────────────────────────────────
from __future__ import annotations

import json
import logging
import math
import re
import threading
from datetime import timedelta

from app import db, events
from app.data.tourist_data import ADJ, NOUN, PLACES_BY_ID, REGIONS
from app.errors import ApiError
from app.services.datahub_service import region_crowd
from app.services.llm_service import get_llm_service

logger = logging.getLogger("jejuitda.insight")

PRIOR_N, PRIOR_AVG = 3, 3.5
W_SAT, W_DEMAND, W_COMFORT = 0.5, 0.3, 0.2


def type_name(code: str | None) -> str:
    """성향 코드(예: "ANPJ") → "노을 감성 탐험가". 모르는 코드는 그대로"""
    try:
        return f"{ADJ[f'{code[1]}-{code[2]}']} {NOUN[f'{code[0]}-{code[3]}']}"
    except (KeyError, IndexError, TypeError):
        return code or "-"


def _crowd_grade(index: float | None) -> str | None:
    if index is None:
        return None
    return "높음" if index >= 0.67 else "보통" if index >= 0.34 else "낮음"


def region_scores() -> dict:
    """지역별 0~10 점수와 근거. 매 요청마다 DB를 다시 읽습니다."""
    since = db.now() - timedelta(days=7)
    reviews = db.review_stats_by_region()
    recent_reviews = db.review_stats_by_region(since)
    courses = db.event_counts_by_region(events.COURSE, since)
    crowd = (region_crowd() or {}).get("regions", {})
    demand_raw = {r["id"]: courses.get(r["id"], 0) + recent_reviews.get(r["id"], {}).get("count", 0) for r in REGIONS}
    top = max(demand_raw.values(), default=0)

    out = []
    for r in REGIONS:
        rid = r["id"]
        rv = reviews.get(rid, {"count": 0, "avg": 0.0})
        n = rv["count"]
        smooth = (rv["avg"] * n + PRIOR_AVG * PRIOR_N) / (n + PRIOR_N)
        sat = (smooth - 1) / 4 * 10
        demand = 10 * math.log1p(demand_raw[rid]) / math.log1p(top) if top else 0.0
        c = crowd.get(rid)
        comfort = 10 * (1 - c["index"]) if c else None
        parts = [(sat, W_SAT), (demand, W_DEMAND)] + ([(comfort, W_COMFORT)] if comfort is not None else [])
        score = sum(v * w for v, w in parts) / sum(w for _, w in parts)
        out.append({
            "regionId": rid, "name": r["name"], "score": round(score, 1),
            "satisfaction": round(sat, 1), "demand": round(demand, 1),
            "comfort": None if comfort is None else round(comfort, 1),
            "reviews": n, "avgStars": rv["avg"] if n else None,
            "courses7d": courses.get(rid, 0), "reviews7d": recent_reviews.get(rid, {}).get("count", 0),
            "crowd": _crowd_grade(c["index"]) if c else None,
        })
    out.sort(key=lambda x: -x["score"])
    return {
        "updatedAt": db.now_iso(),
        "crowdDate": (region_crowd() or {}).get("date"),
        "weights": {"satisfaction": W_SAT, "demand": W_DEMAND, "comfort": W_COMFORT},
        "regions": out,
    }


def _recent_texts(place_ids: list[str], per_place: int = 5) -> list[str]:
    texts = []
    for pid in place_ids:
        for rv in db.reviews_for_place(pid, per_place):
            if rv["text"]:
                texts.append(f"[{PLACES_BY_ID[pid]['name']} ★{rv['stars']}] {rv['text']}")
    return texts


# ── 지역 보고서 Agent ─────────────────────────
_REGION_SYS = (
    "너는 제주 관광 데이터 분석가다. 관리자(지자체)가 읽을 짧은 한국어 보고서를 마크다운으로 쓴다. "
    "주어진 숫자만 근거로 쓰고 없는 사실은 지어내지 않는다. 데이터가 적으면 적다고 말한다. "
    "형식: '## 요약' (3줄), '## 지역별 해설' (점수 상위·하위 지역 위주 글머리표), "
    "'## 주의할 지역', '## 상권에 줄 제안' (실행 가능한 2~3개)."
)


def _region_rule_report(scores: dict) -> str:
    rs = scores["regions"]
    total = sum(r["reviews"] for r in rs)
    lines = ["## 요약",
             f"- 누적 관광객 평가 {total}건, 최근 7일 코스 선택 {sum(r['courses7d'] for r in rs)}건을 기준으로 점수를 매겼어요.",
             f"- 가장 높은 지역은 {rs[0]['name']}({rs[0]['score']}점), 가장 낮은 지역은 {rs[-1]['name']}({rs[-1]['score']}점)이에요."]
    if total < 10:
        lines.append("- 아직 평가가 적어 점수 차이가 크지 않아요. 데이터가 쌓이면 더 정확해져요.")
    lines += ["", "## 지역별 해설"]
    for r in rs:
        bits = [f"만족도 {r['satisfaction']}", f"수요 {r['demand']}"]
        if r["comfort"] is not None:
            bits.append(f"쾌적함 {r['comfort']} (혼잡 {r['crowd']})")
        lines.append(f"- **{r['name']} {r['score']}점**: " + ", ".join(bits) + f" · 평가 {r['reviews']}건")
    weak = [r for r in rs if r["reviews"] >= 3 and (r["avgStars"] or 5) < 3.5]
    busy = [r for r in rs if r["crowd"] == "높음"]
    lines += ["", "## 주의할 지역"]
    lines += [f"- {r['name']}: 평균 별점 {r['avgStars']}점으로 낮아요." for r in weak]
    lines += [f"- {r['name']}: 혼잡도가 높아요. 분산 동선을 안내하면 좋아요." for r in busy]
    if not weak and not busy:
        lines.append("- 지금은 눈에 띄는 문제 지역이 없어요.")
    lines += ["", "## 상권에 줄 제안",
              f"- 수요가 많은 {rs[0]['name']} 상권은 피크 시간대 대기 안내를 준비해 보세요.",
              "- 평가가 적은 지역은 방문 인증·평가 참여를 늘리는 이벤트가 필요해요."]
    return "\n".join(lines)


def create_region_report(user_id: str | None) -> dict:
    scores = region_scores()
    # GPT에는 허브 숫자 대신 등급만 넘깁니다
    rows = [{k: r[k] for k in ("name", "score", "satisfaction", "demand", "reviews", "avgStars",
                               "courses7d", "reviews7d", "crowd")} for r in scores["regions"]]
    top_places = sorted(db.review_stats_by_place().items(), key=lambda kv: -kv[1]["count"])[:6]
    prompt = json.dumps({
        "점수 기준": "0~10, 만족도 50% + 수요 30% + 쾌적함(혼잡 등급) 20%",
        "지역": rows,
        "최근 리뷰": _recent_texts([pid for pid, _ in top_places if pid in PLACES_BY_ID], 3)[:15],
    }, ensure_ascii=False)
    res = get_llm_service().chat(_REGION_SYS, prompt, temperature=0.3)
    body, source = (res.text, "gpt") if res.ok and res.text else (_region_rule_report(scores), "rule")
    if not res.ok:
        logger.info("지역 보고서 규칙 기반으로 작성: %s", res.error)
    title = f"지역 점수 보고서 · {scores['updatedAt'][:16].replace('T', ' ')}"
    report = db.insert_report("REGION", None, title, body, json.dumps(scores, ensure_ascii=False), source, user_id)
    events.publish(events.REPORT, f"{title} 저장", user_id=user_id)
    return report


# ── 가게 리뷰 분석 Agent ──────────────────────
def place_or_404(place_id: str | None) -> dict:
    if not place_id or place_id not in PLACES_BY_ID:
        raise ApiError(404, "PLACE_NOT_LINKED", "내 가게와 연결된 장소가 없어요. 먼저 가게를 연결해 주세요.")
    return PLACES_BY_ID[place_id]


def my_reviews(place_id: str) -> dict:
    p = place_or_404(place_id)
    no = db.place_no(p["id"], p["name"], p["region"], p["kind"])
    summary = db.review_summary_for_place(place_id)
    region = next((r for r in region_scores()["regions"] if r["regionId"] == p["region"]), None)
    latest = db.list_reports("STORE", place_id, 1)
    return {
        "place": {"id": p["id"], "no": no, "name": p["name"], "region": p["region"], "kind": p["kind"]},
        "summary": {**summary, "byType": [{"code": k, "name": type_name(k), "count": v}
                                         for k, v in summary["byType"].items()]},
        "reviews": [{"id": r["id"], "placeNo": r["place_no"] or no, "stars": r["stars"], "text": r["text"], "profile": r["profile_code"],
                     "createdAt": r["created_at"]} for r in db.reviews_for_place(place_id, 50)],
        "regionScore": region,
        "analysis": latest[0] if latest else None,
    }


_STORE_SYS = (
    "너는 제주 소상공인을 돕는 리뷰 분석가다. 가게 주인이 읽을 짧은 한국어 분석을 마크다운으로 쓴다. "
    "주어진 별점·리뷰만 근거로 쓰고, 리뷰가 적으면 그렇다고 말한다. "
    "형식: '## 한 줄 요약', '## 강점', '## 개선할 점', '## 어떤 손님이 오나요', '## 다음 주에 해 볼 일' (2~3개)."
)
_GOOD = re.compile(r"좋|맛있|친절|예쁘|최고|깨끗|추천|만족|뷰|분위기")
_BAD = re.compile(r"별로|아쉽|불친절|비싸|느리|대기|기다|더럽|좁|시끄|짜|실망")


def _store_rule_analysis(name: str, s: dict, texts: list[str]) -> str:
    if not s["count"]:
        return f"## 한 줄 요약\n- '{name}'에 아직 관광객 평가가 없어요. 첫 평가가 들어오면 분석해 드릴게요."
    good = sum(1 for t in texts if _GOOD.search(t))
    bad = sum(1 for t in texts if _BAD.search(t))
    low = s["dist"][1] + s["dist"][2]
    lines = ["## 한 줄 요약", f"- 평가 {s['count']}건, 평균 {s['avg']}점이에요."
             + (" 아직 건수가 적어 참고용으로 봐 주세요." if s["count"] < 5 else ""),
             "", "## 강점", f"- 칭찬 표현이 담긴 리뷰 {good}건" if good else "- 아직 뚜렷한 칭찬 키워드는 없어요.",
             "", "## 개선할 점"]
    lines.append(f"- 불만 표현이 담긴 리뷰 {bad}건, 1~2점 평가 {low}건이 있어요." if bad or low else "- 낮은 평가가 거의 없어요.")
    lines += ["", "## 어떤 손님이 오나요"]
    lines += [f"- {t['name']} 성향 {t['count']}명" for t in s["byType"][:3]] or ["- 성향 정보가 아직 없어요."]
    lines += ["", "## 다음 주에 해 볼 일", "- 낮은 평가 리뷰에 직접 답하고 원인을 확인해 보세요.",
              "- 많이 오는 성향에 맞춘 메뉴·사진 포인트를 안내해 보세요."]
    return "\n".join(lines)


def analyze_my_reviews(place_id: str, user_id: str) -> dict:
    data = my_reviews(place_id)
    p, s = data["place"], data["summary"]
    texts = [f"★{r['stars']} {r['text']}" for r in data["reviews"] if r["text"]][:30]
    prompt = json.dumps({"가게": p["name"], "평가 수": s["count"], "평균 별점": s["avg"], "별점 분포": s["dist"],
                         "손님 성향": s["byType"], "리뷰": texts,
                         "지역 점수(0~10)": data["regionScore"]["score"] if data["regionScore"] else None},
                        ensure_ascii=False)
    res = get_llm_service().chat(_STORE_SYS, prompt, temperature=0.3) if s["count"] else None
    if res and res.ok and res.text:
        body, source = res.text, "gpt"
    else:
        body, source = _store_rule_analysis(p["name"], s, texts), "rule"
    title = f"{p['name']} 리뷰 분석 · {db.now_iso()[:16].replace('T', ' ')}"
    return db.insert_report("STORE", place_id, title, body,
                            json.dumps({"summary": s}, ensure_ascii=False), source, user_id)


def merchant_places() -> list[dict]:
    """가게 연결용 장소 목록 (식당·카페 위주), 고유 번호 순"""
    nos = db.place_nos()
    return [{"id": p["id"], "no": nos.get(p["id"], p["no"]), "name": p["name"], "region": p["region"], "kind": p["kind"]}
            for p in PLACES_BY_ID.values() if p["kind"] in ("food", "cafe", "indoor")]


# ── 새 평가가 들어오면 자동 분석 ────────────────
# 같은 장소에 평가가 몰려 들어오면 AUTO_DELAY 초 동안 모았다가 한 번만 분석합니다.
AUTO_DELAY = 8.0
_timers: dict[str, threading.Timer] = {}
_timer_lock = threading.Lock()


def _auto_analyze(place_id: str) -> None:
    with _timer_lock:
        _timers.pop(place_id, None)
    owners = db.owners_of_place(place_id)
    if not owners:
        return
    try:
        report = analyze_my_reviews(place_id, owners[0])
    except Exception:  # noqa: BLE001 - 백그라운드 분석이 서버를 멈추지 않게
        logger.exception("자동 리뷰 분석 실패 (%s)", place_id)
        return
    p = PLACES_BY_ID[place_id]
    events.publish(events.ANALYSIS, f"#{db.place_no(place_id)} {p['name']} 리뷰 분석을 새로 저장했어요",
                   region=p["region"], place_id=place_id, extra={"reportId": report["id"]})


def schedule_store_analysis(place_id: str) -> None:
    if place_id not in PLACES_BY_ID or not db.owners_of_place(place_id):
        return
    with _timer_lock:
        old = _timers.get(place_id)
        if old:
            old.cancel()
        t = threading.Timer(AUTO_DELAY, _auto_analyze, args=(place_id,))
        t.daemon = True
        _timers[place_id] = t
        t.start()


def place_overview() -> list[dict]:
    """Main PC: 장소(고유 번호)별 평가 수·평균·사장님 연결 여부·최근 분석"""
    stats = db.review_stats_by_place()
    nos = db.place_nos()
    out = []
    for p in PLACES_BY_ID.values():
        s = stats.get(p["id"], {"count": 0, "avg": 0.0})
        last = db.list_reports("STORE", p["id"], 1)
        out.append({"no": nos.get(p["id"], p["no"]), "id": p["id"], "name": p["name"], "region": p["region"],
                    "kind": p["kind"], "reviews": s["count"], "avgStars": s["avg"] if s["count"] else None,
                    "owner": bool(db.owners_of_place(p["id"])),
                    "lastAnalysis": {"title": last[0]["title"], "createdAt": last[0]["createdAt"]} if last else None})
    out.sort(key=lambda x: x["no"])
    return out
