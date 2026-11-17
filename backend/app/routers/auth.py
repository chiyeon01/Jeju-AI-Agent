# ─────────────────────────────────────────────
# 로그인·회원가입 (/api/v1/auth/...)
# ─────────────────────────────────────────────
from __future__ import annotations

import re
from typing import Literal

from fastapi import APIRouter, Depends, Response
from pydantic import BaseModel, Field

from app import db, events
from app.data.tourist_data import PLACES_BY_ID
from app.errors import ApiError
from app.security import (
    create_access_token,
    current_user,
    hash_password,
    issue_refresh_token,
    public_user,
    revoke_refresh_token,
    rotate_refresh_token,
    verify_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])

_EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class SignupRequest(BaseModel):
    email: str
    password: str = Field(min_length=8, max_length=128)
    name: str = Field(min_length=1, max_length=50)
    role: Literal["USER", "MERCHANT"] = "USER"
    storeName: str | None = Field(None, max_length=80)
    businessNo: str | None = Field(None, max_length=20)
    placeId: str | None = Field(None, max_length=10)  # 상권 주인: 관광객 평가를 받는 장소와 내 가게 연결


class LoginRequest(BaseModel):
    email: str
    password: str


class RefreshRequest(BaseModel):
    refreshToken: str


@router.post("/signup", status_code=201)
def signup(req: SignupRequest) -> dict:
    """회원가입. 상권 주인(MERCHANT)은 관리자 승인 전까지 PENDING."""
    email = req.email.strip().lower()
    if not _EMAIL.match(email):
        raise ApiError(422, "INVALID_EMAIL", "이메일 형식이 올바르지 않아요.")
    if db.get_user_by_email(email):
        raise ApiError(409, "EMAIL_TAKEN", "이미 가입된 이메일이에요.")
    merchant = req.role == "MERCHANT"
    business_no = re.sub(r"\D", "", req.businessNo or "")
    if merchant and not (req.storeName or "").strip():
        raise ApiError(422, "MERCHANT_INFO_REQUIRED", "상호를 입력해 주세요.")
    if merchant and business_no and len(business_no) != 10:
        raise ApiError(422, "INVALID_BUSINESS_NO", "사업자등록번호는 숫자 10자리예요.")

    user_id = db.next_user_id("m" if merchant else "u")
    user = {
        "id": user_id, "email": email, "name": req.name.strip(), "role": req.role,
        "status": "PENDING" if merchant else "ACTIVE", "password_hash": hash_password(req.password),
        "store_id": f"st-{user_id}" if merchant else None,
        "store_name": (req.storeName or "").strip() or None,
        "business_no": business_no or None,
    }
    db.insert_user(user)
    if merchant and req.placeId in PLACES_BY_ID:
        db.set_store_place(user_id, req.placeId)
    if merchant:
        events.publish(events.STORE, f"{user['store_name']} · 가입 신청 (승인 대기)", user_id=user_id)
    return {"user": public_user(user)}


@router.post("/login")
def login(req: LoginRequest) -> dict:
    email = req.email.strip().lower()
    user = db.get_user_by_email(email)
    if not user or not verify_password(req.password, user["password_hash"]):
        db.insert_access_log(email, "로그인", "계정", False)
        raise ApiError(401, "INVALID_CREDENTIALS", "이메일 또는 비밀번호가 맞지 않아요.")
    if user["status"] == "PENDING":
        raise ApiError(403, "ACCOUNT_PENDING", "관리자 승인 후 이용할 수 있어요.")
    if user["status"] == "SUSPENDED":
        raise ApiError(403, "ACCOUNT_SUSPENDED", "이용이 정지된 계정이에요.")
    db.update_user(user["id"], {"last_login_at": db.now_iso()})
    db.insert_access_log(user["name"], "로그인", "계정", True)
    return {
        "accessToken": create_access_token(user),
        "refreshToken": issue_refresh_token(user["id"]),
        "user": public_user(user),
    }


@router.post("/refresh")
def refresh(req: RefreshRequest) -> dict:
    """리프레시 토큰으로 새 액세스·리프레시 토큰 발급 (이전 리프레시 토큰은 폐기)."""
    user, new_refresh = rotate_refresh_token(req.refreshToken)
    return {"accessToken": create_access_token(user), "refreshToken": new_refresh}


@router.post("/logout", status_code=204)
def logout(req: RefreshRequest) -> Response:
    revoke_refresh_token(req.refreshToken)
    return Response(status_code=204)


@router.get("/me")
def me(user: dict = Depends(current_user)) -> dict:
    return public_user(user)
