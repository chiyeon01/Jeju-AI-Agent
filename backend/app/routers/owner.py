# ─────────────────────────────────────────────
# 상권 주인 엔드포인트 (/api/v1/owner/...) — MERCHANT·ADMIN
# 모두 사장님이 연결한 내 가게(PUT /owner/place)의 실제 관광객 평가로 계산합니다. 연결 전이면 404 PLACE_NOT_LINKED.
#  GET  /owner/store            내 가게 { id, no, name, region, regionName, kind, category }
#  GET  /owner/reviews/topics   리뷰 주제별 반응 (GPT) { topics:[{ topic, pos, mentions, summary }], source, reviewCount, textCount, createdAt }
#  GET  /owner/reviews?limit=   최근 리뷰 [{ id, stars, text, profile, createdAt }]
#  POST /owner/ask              상권 분석 Agent 질문
#  POST /owner/actions          메뉴·이벤트 등록
# ─────────────────────────────────────────────
from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.schemas import OwnerActionOut, OwnerActionRequest, OwnerAskOut, OwnerAskRequest
from app.security import require_roles
from app.services import owner_service as svc

router = APIRouter(prefix="/owner", tags=["owner"])
merchant = require_roles("MERCHANT", "ADMIN")


def place_of(user: dict = Depends(merchant)) -> str:
    return svc.resolve_place(user)


@router.get("/store")
def store(place_id: str = Depends(place_of)) -> dict:
    return svc.store_info(place_id)


@router.get("/reviews/topics")
def review_topics(place_id: str = Depends(place_of)) -> dict:
    return svc.review_topics(place_id)


@router.get("/reviews")
def reviews(limit: int = Query(10, ge=1, le=50), place_id: str = Depends(place_of)) -> list[dict]:
    return svc.recent_reviews(place_id, limit)


@router.post("/ask", response_model=OwnerAskOut)
def ask(req: OwnerAskRequest, place_id: str = Depends(place_of)) -> OwnerAskOut:
    return svc.ask_owner_agent(place_id, req.question)


@router.post("/actions", response_model=OwnerActionOut, status_code=201)
def register(req: OwnerActionRequest, place_id: str = Depends(place_of), user: dict = Depends(merchant)) -> OwnerActionOut:
    return svc.register_action(req, place_id, user)
