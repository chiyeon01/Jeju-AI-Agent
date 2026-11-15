# ─────────────────────────────────────────────
# 제주잇다 백엔드 (FastAPI)
# 실행: uvicorn app.main:app --reload --port 8000  (backend/ 폴더에서)
# 프론트는 vite가 /api → http://localhost:8000 으로 프록시합니다.
# ─────────────────────────────────────────────
from __future__ import annotations

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.db import init_db
from app.routers import map as map_router
from app.routers import owner, tourist

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("jejuitda")

settings = get_settings()

app = FastAPI(
    title="제주잇다 API",
    description="관광객의 취향과 제주 상권을 데이터로 잇는 AI Agent 서비스 백엔드",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(tourist.router, prefix="/api")
app.include_router(owner.router, prefix="/api")
app.include_router(map_router.router, prefix="/api")


@app.on_event("startup")
def on_startup() -> None:
    init_db()
    if settings.has_openai_key:
        logger.info("GPT(OpenAI) 연동 활성화 (model=%s)", settings.openai_model)
    else:
        logger.warning(
            "OPENAI_API_KEY가 없어 GPT 없이 규칙 기반 응답으로 동작합니다. "
            "backend/.env 에 키를 넣으면 자동으로 켜집니다."
        )


@app.get("/api/health")
def health() -> dict:
    return {
        "ok": True,
        "gpt_enabled": settings.has_openai_key,
        "jeju_data_hub_connected": bool(settings.jeju_data_hub_api_key.strip()),
        "kakao_map_enabled": settings.has_kakao_key,
    }
