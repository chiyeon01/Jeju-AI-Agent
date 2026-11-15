# ─────────────────────────────────────────────
# 관광객 Agent 엔드포인트
# frontend/src/api/client.js 가 호출하는 경로와 1:1로 맞춥니다.
# ─────────────────────────────────────────────
from __future__ import annotations

from fastapi import APIRouter

from app.schemas import (
    ChatOut,
    ChatRequest,
    CourseOut,
    CourseRequest,
    ProfileOut,
    ProfileRequest,
    ReviewsOut,
    ReviewsRequest,
)
from app.services.chat_service import chat_course as chat_course_service
from app.services.course_service import plan_course as plan_course_service
from app.services.profile_service import analyze_profile as analyze_profile_service
from app.services.review_service import submit_reviews as submit_reviews_service

router = APIRouter(prefix="/tourist", tags=["tourist"])


@router.post("/profile", response_model=ProfileOut)
def analyze_profile(req: ProfileRequest) -> ProfileOut:
    """성향 분석 Agent: 테스트 응답 → 4축 점수 → 16유형."""
    return analyze_profile_service(req)


@router.post("/course", response_model=CourseOut)
def plan_course(req: CourseRequest) -> CourseOut:
    """코스 플래너 Agent: 성향·위치·날씨 → 시간표가 있는 추천 코스."""
    return plan_course_service(req)


@router.post("/course/chat", response_model=ChatOut)
def chat_course(req: ChatRequest) -> ChatOut:
    """대화로 코스 수정 (예: "저녁은 해산물로 바꿔줘")."""
    return chat_course_service(req.message)


@router.post("/reviews", response_model=ReviewsOut)
def submit_reviews(req: ReviewsRequest) -> ReviewsOut:
    """방문 후 평가 저장 → 상권 지표 실시간 반영."""
    return submit_reviews_service(req.reviews)
