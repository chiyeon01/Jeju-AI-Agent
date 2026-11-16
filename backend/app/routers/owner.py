# ─────────────────────────────────────────────
# 상권 주인 엔드포인트 (/api/v1/owner/...) — MERCHANT·ADMIN
# ─────────────────────────────────────────────
from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.schemas import OwnerActionOut, OwnerActionRequest, OwnerAskOut, OwnerAskRequest
from app.security import require_roles
from app.services import owner_service as svc

router = APIRouter(prefix="/owner", tags=["owner"])
merchant = require_roles("MERCHANT", "ADMIN")


def store_of(user: dict = Depends(merchant)) -> str:
    return svc.resolve_store(user)


@router.get("/store")
def store(_: str = Depends(store_of)) -> dict:
    """매장 기본 정보 { id, name, category, dong }"""
    return svc.store_info()


@router.get("/score")
def score(_: str = Depends(store_of)) -> dict:
    """상권 건강 점수 { score, delta, percentile, peers, basis }"""
    return svc.score()


@router.get("/score/trend")
def score_trend(weeks: int = Query(12, ge=1, le=52), _: str = Depends(store_of)) -> dict:
    """주간 점수 추이 { values, labels }"""
    return svc.score_trend(weeks)


@router.get("/indicators")
def indicators(_: str = Depends(store_of)) -> list[dict]:
    """세부 지표 [{ key, name, value, unit, delta, good, src, desc, basis, spark }]"""
    return svc.indicators()


@router.get("/report/weekly")
def weekly_report(_: str = Depends(store_of)) -> dict:
    """주간 AI 개선 제안 { week, summary, actions[] }"""
    return svc.weekly_report()


@router.get("/reviews/topics")
def review_topics(_: str = Depends(store_of)) -> list[dict]:
    """리뷰 주제별 긍정률 [{ topic, pos, mentions }]"""
    return svc.review_topics()


@router.get("/reviews")
def reviews(limit: int = Query(4, ge=1, le=50), _: str = Depends(store_of)) -> list[dict]:
    """최근 리뷰 [{ stars, text, type, at, tags }]"""
    return svc.recent_reviews(limit)


@router.post("/ask", response_model=OwnerAskOut)
def ask(req: OwnerAskRequest, _: str = Depends(store_of)) -> OwnerAskOut:
    """상권 분석 Agent 질의: 매장 지표·리뷰를 근거로 답변."""
    return svc.ask_owner_agent(req.question)


@router.post("/actions", response_model=OwnerActionOut, status_code=201)
def register(req: OwnerActionRequest, store_id: str = Depends(store_of), user: dict = Depends(merchant)) -> OwnerActionOut:
    """사장님 개선 조치 등록 → 효과 측정(MEASURING) 상태로 저장."""
    return svc.register_action(req, store_id, user)
