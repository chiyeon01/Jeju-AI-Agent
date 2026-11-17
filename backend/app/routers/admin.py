# ─────────────────────────────────────────────
# 관리 콘솔 엔드포인트 (/api/v1/admin/...) — ADMIN 전용
# ─────────────────────────────────────────────
from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app import db
from app.security import require_roles
from app.services import admin_service as svc

router = APIRouter(prefix="/admin", tags=["admin"])
admin = require_roles("ADMIN")


class UserPatch(BaseModel):
    status: Literal["ACTIVE", "PENDING", "SUSPENDED"] | None = None
    role: Literal["USER", "MERCHANT", "ADMIN"] | None = None


@router.get("/overview")
def overview(_: dict = Depends(admin)) -> dict:
    """오늘 집계 { visits, reviews, courses, eventsPerSec }"""
    return svc.overview()


@router.get("/regions/health")
def regions_health(_: dict = Depends(admin)) -> list[dict]:
    """지역별 [{ regionId, name, lat, lon, score, visits, reviews, crowdIndex, crowdDate }]"""
    return svc.regions_health()


@router.get("/sources")
def sources(user: dict = Depends(admin)) -> list[dict]:
    """원천 데이터 적재 이력 (데이터허브 API + 받아 둔 파일)"""
    db.insert_access_log(user["name"], "조회", "원천 데이터 적재 이력", True)
    return svc.sources()


@router.get("/derived")
def derived(_: dict = Depends(admin)) -> list[dict]:
    return svc.derived()


@router.get("/quality")
def quality(_: dict = Depends(admin)) -> list[dict]:
    return svc.quality()


@router.get("/users")
def users(user: dict = Depends(admin)) -> list[dict]:
    db.insert_access_log(user["name"], "조회", "계정 목록", True)
    return svc.users()


@router.patch("/users/{user_id}")
def update_user(user_id: str, body: UserPatch, user: dict = Depends(admin)) -> dict:
    """상권 주인 가입 승인(status=ACTIVE), 정지(SUSPENDED), 역할 변경"""
    return svc.update_user(user, user_id, body.status, body.role)


@router.get("/access-logs")
def access_logs(_: dict = Depends(admin)) -> list[dict]:
    return svc.access_logs()


@router.get("/masking-rules")
def masking_rules(_: dict = Depends(admin)) -> list[dict]:
    return svc.masking_rules()


@router.get("/backups")
def backups(_: dict = Depends(admin)) -> list[dict]:
    return svc.backups()


@router.post("/backups", status_code=201)
def create_backup(user: dict = Depends(admin)) -> dict:
    """지금 SQLite 스냅샷 만들기 → { message, backup }"""
    return svc.create_backup(user)


@router.post("/backups/{backup_id}/restore")
def restore(backup_id: str, user: dict = Depends(admin)) -> dict:
    """복구 요청. 다른 관리자가 24시간 안에 같은 스냅샷을 요청하면 실제로 복구합니다 → { message }"""
    return svc.request_restore(user, backup_id)


@router.get("/retention")
def retention(_: dict = Depends(admin)) -> list[dict]:
    return svc.retention()
