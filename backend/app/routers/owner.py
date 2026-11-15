# ─────────────────────────────────────────────
# 상권 주인 Agent 엔드포인트
# ─────────────────────────────────────────────
from __future__ import annotations

from fastapi import APIRouter

from app.schemas import OwnerActionOut, OwnerActionRequest, OwnerAskOut, OwnerAskRequest
from app.services.owner_service import ask_owner_agent, register_action

router = APIRouter(prefix="/owner", tags=["owner"])


@router.post("/ask", response_model=OwnerAskOut)
def ask(req: OwnerAskRequest) -> OwnerAskOut:
    """상권 분석 Agent 질의: 매장 지표·리뷰를 근거로 답변."""
    return ask_owner_agent(req.question)


@router.post("/actions", response_model=OwnerActionOut)
def register(req: OwnerActionRequest) -> OwnerActionOut:
    """사장님 개선 조치 등록."""
    new_id = register_action(req)
    return OwnerActionOut(ok=True, id=new_id)
