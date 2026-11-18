# ─────────────────────────────────────────────
# 방문 후 평가 처리
# 평가가 들어오면 장소 고유 번호와 함께 DB(reviews)에 저장합니다.
# 사장님 대시보드(별점·리뷰·주제별 반응)는 이 저장된 평가로만 계산합니다 (기획서 4.3 순환 구조).
# 허위 평가 방지: 코스에 있는 장소만, 계정당 하루 DAILY_LIMIT 건까지.
# ─────────────────────────────────────────────
from __future__ import annotations

from datetime import datetime

from app import db, events
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

    return ReviewsOut(accepted=accepted, rejected=rejected)
