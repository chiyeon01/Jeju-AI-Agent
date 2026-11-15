# ─────────────────────────────────────────────
# 방문 후 평가 처리
# 평가가 들어오면 저장하고, 매장의 "고객 만족 지수(csat)"를 다시 계산합니다.
# (기획서 4.3 순환 구조: 관광객 평가 → 상권 고객 만족 지표에 반영)
# ─────────────────────────────────────────────
from __future__ import annotations

from app import db
from app.data.owner_data import INDICATORS, STORE
from app.schemas import ReviewIn, ReviewsOut


def submit_reviews(reviews: list[ReviewIn]) -> ReviewsOut:
    accepted = 0
    for r in reviews:
        if not (1 <= r.stars <= 5):
            continue
        db.insert_review(r.placeId, r.stars, r.text[:100], r.profile)
        accepted += 1

    if accepted:
        _recompute_csat()

    return ReviewsOut(ok=True, accepted=accepted)


def _recompute_csat() -> None:
    """실제 앱 평가 평균으로 고객 만족 지수를 다시 계산해 INDICATORS/STORE에 반영.
    (최근 30일 필터 등은 생략한 단순 평균 — 실데이터 연동 시 윈도우 쿼리로 교체)"""
    count, avg_stars = db.review_stats()
    if count == 0:
        return
    csat = INDICATORS["csat"]
    prev_value = csat["value"]
    new_value = round(avg_stars, 2)
    csat["value"] = new_value
    csat["delta"] = round(new_value - prev_value, 2)
    spark = csat.get("spark") or []
    csat["spark"] = [*spark[-6:], new_value]

    # 종합 상권 건강 점수도 살짝 반영 (고객 만족 지수 변화의 10배를 가산, 0~100 클램프)
    new_score = STORE["score"] + round((new_value - prev_value) * 10)
    STORE["scoreDelta"] = new_score - STORE["score"]
    STORE["score"] = max(0, min(100, new_score))
