# ─────────────────────────────────────────────
# 제주잇다 백엔드 (FastAPI)
# 실행: uvicorn app.main:app --reload --port 8000  (backend/ 폴더에서)
# 프론트는 vite가 /api → http://localhost:8000 으로 프록시합니다.
# ─────────────────────────────────────────────
from __future__ import annotations

import logging
import threading
import time

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.db import init_db
from app.routers import datahub, owner, tourist
from app.routers import map as map_router
from app.services.datahub_client import DataHubError
from app.services.datahub_service import region_crowd

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
app.include_router(datahub.router, prefix="/api")


def _warm_region_crowd(attempts: int = 5, wait_seconds: int = 60) -> None:
    """코스 플래너가 쓰는 지역 혼잡도를 미리 계산 (허브가 느려 요청 중에 부르지 않음).
    허브가 일시적으로 실패하면 1분 간격으로 몇 번 더 시도합니다."""
    for i in range(1, attempts + 1):
        try:
            region_crowd(refresh=True)
            return
        except DataHubError as e:
            logger.warning("지역 혼잡도 계산 실패 (%d/%d) — 그동안 코스는 혼잡도 없이 동작합니다: %s", i, attempts, e)
        except Exception:  # noqa: BLE001 - 백그라운드 작업이 서버를 멈추지 않게
            logger.exception("지역 혼잡도 계산 중 예상치 못한 오류")
            return
        time.sleep(wait_seconds)


@app.on_event("startup")
def on_startup() -> None:
    init_db()
    if settings.jeju_data_hub_api_key.strip():
        threading.Thread(target=_warm_region_crowd, name="datahub-warmup", daemon=True).start()
    else:
        logger.warning("JEJU_DATA_HUB_API_KEY가 없어 데이터허브 실데이터 없이 동작합니다.")
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
