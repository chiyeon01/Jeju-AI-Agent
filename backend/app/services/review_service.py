# ─────────────────────────────────────────────
# 방문 후 평가 처리
# 평가가 들어오면 저장하고, 매장의 "고객 만족 지수(csat)"를 다시 계산합니다.
# (기획서 4.3 순환 구조: 관광객 평가 → 상권 고객 만족 지표에 반영)
# 허위 평가 방지: 코스에 있는 장소만, 계정당 하루 DAILY_LIMIT 건까지.
# ─────────────────────────────────────────────
from __future__ import annotations

from datetime import datetime

from app import db, events
from app.data.owner_data import INDICATORS, STORE
from app.data.tourist_data import PLACES_BY_ID
from app.schemas import ReviewIn, ReviewsOut
from app.services import insight_service

DAILY_LIMIT = 20


def submit_reviews(reviews: list[ReviewIn], user: dict | None = None) -> ReviewsOut:
    user_id = user["id"] if user else None
    today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    used_today = db.reviews_by_user_since(user_id, today_start) if user_id else 0

    accepted = rejected = 0
    for r in reviews:
        place = PLACES_BY_ID.get(r.placeId)
        if place is None or used_today >= DAILY_LIMIT:
            rejected += 1
            continue
        no = db.place_no(place["id"], place["name"], place["region"], place["kind"])
        db.insert_review(r.placeId, r.stars, r.text[:100], r.profile, user_id, place["region"], no)
        used_today += 1
        accepted += 1
        # 관리 콘솔과 이 장소를 가진 사장님 화면에 실시간으로 알림
        events.publish(events.REVIEW, f"#{no} {place['name']} ★{r.stars}" + (f" · 성향 {r.profile}" if r.profile else ""),
                       region=place["region"], user_id=user_id, place_id=place["id"],
                       extra={"placeNo": no, "stars": r.stars, "profile": r.profile})
        # 사장님이 연결된 장소면 Agent 가 리뷰를 다시 분석해 저장하고 알려 줍니다 (잠시 모아서 한 번)
        insight_service.schedule_store_analysis(place["id"])

    if accepted:
        _recompute_csat()
    return ReviewsOut(accepted=accepted, rejected=rejected)


def _recompute_csat() -> None:
    """실제 앱 평가 평균으로 고객 만족 지수를 다시 계산해 INDICATORS/STORE에 반영.
    (최근 30일 필터 등은 생략한 단순 평균 — 실데이터 연동 시 윈도우 쿼리로 교체)"""
    count, avg_stars = db.review_stats()
    if count == 0:
        return
    csat = next(i for i in INDICATORS if i["key"] == "csat")
    prev_value = csat["value"]
    new_value = round(avg_stars, 2)
    csat["value"] = new_value
    csat["delta"] = round(new_value - prev_value, 2)
    csat["desc"] = f"앱 평가 평균 (리뷰 {count}건)"
    csat["spark"] = [*(csat.get("spark") or [])[-6:], new_value]

    # 종합 상권 건강 점수도 살짝 반영 (고객 만족 지수 변화의 10배를 가산, 0~100 클램프)
    new_score = max(0, min(100, STORE["score"] + round((new_value - prev_value) * 10)))
    STORE["scoreDelta"] = new_score - STORE["score"]
    STORE["score"] = new_score
