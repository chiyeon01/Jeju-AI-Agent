# ─────────────────────────────────────────────
# 관광객 엔드포인트 (/api/v1/tourist/..., /api/v1/regions...) — USER·ADMIN
# frontend/src/api/client.js · app/lib/api/client.dart 와 1:1로 맞춥니다.
# ─────────────────────────────────────────────
from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app import events
from app.data.tourist_data import REGIONS, REGIONS_BY_ID
from app.schemas import (
    ChatOut,
    ChatRequest,
    CourseOut,
    CourseRequest,
    NearestRegionOut,
    ProfileOut,
    ProfileRequest,
    RegionOut,
    ReviewsOut,
    ReviewsRequest,
)
from app.security import current_user, require_roles
from app.services import course_session
from app.services.chat_service import chat_course as chat_course_service
from app.services.course_service import plan_course as plan_course_service
from app.services.geo import haversine_km
from app.services.profile_service import analyze_profile as analyze_profile_service
from app.services.review_service import submit_reviews as submit_reviews_service

router = APIRouter(prefix="/tourist", tags=["tourist"])
regions_router = APIRouter(prefix="/regions", tags=["regions"])
tourist = require_roles("USER", "ADMIN")


@regions_router.get("", response_model=list[RegionOut])
def regions(_: dict = Depends(current_user)) -> list[RegionOut]:
    """출발 지역 10곳 { id, name, lat, lon }"""
    return [RegionOut(**r) for r in REGIONS]


@regions_router.get("/nearest", response_model=NearestRegionOut)
def nearest(lat: float = Query(..., ge=32.9, le=34.1), lon: float = Query(..., ge=125.9, le=127.1),
            _: dict = Depends(current_user)) -> NearestRegionOut:
    """현재 위치(위경도)에서 가장 가까운 지역. 제주 범위 밖 좌표는 422."""
    best = min(REGIONS, key=lambda r: haversine_km(lat, lon, r["lat"], r["lon"]))
    return NearestRegionOut(**best, distanceKm=round(haversine_km(lat, lon, best["lat"], best["lon"]), 2))


@router.post("/profile", response_model=ProfileOut)
def analyze_profile(req: ProfileRequest, user: dict = Depends(tourist)) -> ProfileOut:
    """성향 분석 Agent: 테스트 응답 → 4축 점수 → 16유형. 새 여행이므로 대화로 쌓인 코스 선호는 비웁니다."""
    course_session.reset(user["id"])
    return analyze_profile_service(req)


@router.post("/course", response_model=CourseOut)
def plan_course(req: CourseRequest, user: dict = Depends(tourist)) -> CourseOut:
    """코스 플래너 Agent: 성향·출발 지역·날씨 → 시간표가 있는 추천 코스."""
    course = plan_course_service(req, course_session.get(user["id"]).prefs)
    course_session.save_plan(user["id"], req, [s.id for s in course.stops])
    region = REGIONS_BY_ID[req.regionId]
    extras = " · ".join(x for x in (req.profile.transport, req.profile.companion) if x)
    events.publish(events.COURSE,
                   f"{region['name']} {len(course.stops)}곳 코스" + (" (비)" if req.weather == "rain" else "")
                   + (f" · {extras}" if extras else ""),
                   region=req.regionId, user_id=user["id"])
    return course


@router.post("/course/chat", response_model=ChatOut, response_model_exclude_none=True)
def chat_course(req: ChatRequest, user: dict = Depends(tourist)) -> ChatOut:
    """대화로 코스 수정 (예: "저녁은 해산물로 바꿔줘", "카페는 바다 보이는 곳으로", "함덕 해변 빼줘").
    patch 로 담을 수 없는 요청은 서버가 사용자별로 기억해 다음 /tourist/course 에 반영합니다."""
    return chat_course_service(req.message, user["id"])


@router.post("/reviews", response_model=ReviewsOut)
def submit_reviews(req: ReviewsRequest, user: dict = Depends(tourist)) -> ReviewsOut:
    """방문 후 평가 저장 → 상권 지표 실시간 반영. 코스 장소만, 계정당 하루 20건까지."""
    return submit_reviews_service(req.reviews, user)
