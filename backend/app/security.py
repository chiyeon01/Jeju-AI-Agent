# ─────────────────────────────────────────────
# 로그인·권한
#  - 비밀번호: PBKDF2-SHA256 (표준 라이브러리, 솔트 + 210,000회)
#  - 액세스 토큰: JWT(HS256), 기본 30분
#  - 리프레시 토큰: 무작위 문자열, DB에는 해시만 저장, 쓸 때마다 새로 발급(회전)
#  - 역할: USER(관광객) · MERCHANT(상권 주인) · ADMIN(관리자)
# ─────────────────────────────────────────────
from __future__ import annotations

import base64
import hashlib
import hmac
import logging
import secrets
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, Request

from app import db
from app.config import get_settings
from app.errors import ApiError

logger = logging.getLogger("jejuitda.auth")

ROLES = ("USER", "MERCHANT", "ADMIN")
_PBKDF2_ROUNDS = 210_000


# ── 비밀번호 ──────────────────────────────────
def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, _PBKDF2_ROUNDS)
    return f"pbkdf2_sha256${_PBKDF2_ROUNDS}${base64.b64encode(salt).decode()}${base64.b64encode(digest).decode()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        _, rounds, salt_b64, digest_b64 = stored.split("$")
        digest = hashlib.pbkdf2_hmac("sha256", password.encode(), base64.b64decode(salt_b64), int(rounds))
        return hmac.compare_digest(digest, base64.b64decode(digest_b64))
    except (ValueError, TypeError):
        return False


# ── JWT ───────────────────────────────────────
_secret_cache: str | None = None


def _jwt_secret() -> str:
    """JWT_SECRET 이 비어 있으면 storage/.jwt_secret 에 한 번 만들어 계속 씁니다 (재시작해도 로그인 유지)."""
    global _secret_cache
    if _secret_cache:
        return _secret_cache
    settings = get_settings()
    if settings.jwt_secret.strip():
        _secret_cache = settings.jwt_secret.strip()
        return _secret_cache
    path = settings.storage_dir / ".jwt_secret"
    if path.exists():
        _secret_cache = path.read_text(encoding="utf-8").strip()
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        _secret_cache = secrets.token_urlsafe(48)
        path.write_text(_secret_cache, encoding="utf-8")
        logger.info("JWT 비밀키를 새로 만들었어요: %s", path)
    return _secret_cache


def create_access_token(user: dict) -> str:
    minutes = get_settings().access_token_minutes
    now = datetime.now(timezone.utc)
    payload = {"sub": user["id"], "role": user["role"], "iat": now, "exp": now + timedelta(minutes=minutes)}
    return jwt.encode(payload, _jwt_secret(), algorithm="HS256")


def decode_access_token(token: str) -> dict:
    try:
        return jwt.decode(token, _jwt_secret(), algorithms=["HS256"])
    except jwt.ExpiredSignatureError as e:
        raise ApiError(401, "TOKEN_EXPIRED", "로그인이 만료됐어요.") from e
    except jwt.PyJWTError as e:
        raise ApiError(401, "INVALID_TOKEN", "로그인 정보가 올바르지 않아요.") from e


# ── 리프레시 토큰 ─────────────────────────────
def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def issue_refresh_token(user_id: str) -> str:
    token = secrets.token_urlsafe(48)
    expires = datetime.now() + timedelta(days=get_settings().refresh_token_days)
    db.save_refresh_token(_hash_token(token), user_id, expires)
    return token


def rotate_refresh_token(token: str) -> tuple[dict, str]:
    """유효한 리프레시 토큰이면 폐기하고 새 토큰을 발급합니다. 반환: (사용자, 새 리프레시 토큰)."""
    row = db.get_refresh_token(_hash_token(token))
    if not row or row["revoked"] or datetime.fromisoformat(row["expires_at"]) < datetime.now():
        raise ApiError(401, "INVALID_REFRESH_TOKEN", "로그인이 만료됐어요. 다시 로그인해 주세요.")
    user = db.get_user(row["user_id"])
    if not user or user["status"] != "ACTIVE":
        raise ApiError(401, "INVALID_REFRESH_TOKEN", "로그인이 만료됐어요. 다시 로그인해 주세요.")
    db.revoke_refresh_token(row["token_hash"])
    return user, issue_refresh_token(user["id"])


def revoke_refresh_token(token: str) -> None:
    db.revoke_refresh_token(_hash_token(token))


# ── 응답용 사용자 ─────────────────────────────
def public_user(u: dict) -> dict:
    out = {"id": u["id"], "email": u["email"], "name": u["name"], "role": u["role"], "status": u["status"]}
    if u.get("store_id"):
        out["storeId"] = u["store_id"]
    return out


# ── 의존성 (라우터에서 Depends 로 사용) ───────
def current_user(request: Request) -> dict:
    auth = request.headers.get("Authorization", "")
    if not auth.lower().startswith("bearer "):
        raise ApiError(401, "UNAUTHORIZED", "로그인이 필요해요.")
    return user_from_token(auth.split(" ", 1)[1].strip())


def user_from_token(token: str) -> dict:
    payload = decode_access_token(token)
    user = db.get_user(payload.get("sub", ""))
    if not user:
        raise ApiError(401, "INVALID_TOKEN", "로그인 정보가 올바르지 않아요.")
    if user["status"] == "SUSPENDED":
        raise ApiError(403, "ACCOUNT_SUSPENDED", "이용이 정지된 계정이에요.")
    if user["status"] != "ACTIVE":
        raise ApiError(403, "ACCOUNT_PENDING", "관리자 승인 후 이용할 수 있어요.")
    return user


def require_roles(*roles: str):
    def dep(user: dict = Depends(current_user)) -> dict:
        if user["role"] not in roles:
            raise ApiError(403, "FORBIDDEN", "이 기능을 쓸 권한이 없어요.")
        return user
    return dep


# ── 시연 계정 ─────────────────────────────────
DEMO_PASSWORD = "jeju1234"
DEMO_ACCOUNTS = [
    {"id": "u-1", "email": "user@jeju.kr", "name": "김여행", "role": "USER", "status": "ACTIVE"},
    {"id": "m-1", "email": "owner@jeju.kr", "name": "애월 돌담국수", "role": "MERCHANT", "status": "ACTIVE",
     "store_id": "st-aewol-0142", "store_name": "애월 돌담국수"},
    {"id": "m-2", "email": "sehwa@jeju.kr", "name": "세화 바다 카페", "role": "MERCHANT", "status": "PENDING",
     "store_id": "st-gujwa-0031", "store_name": "세화 바다 카페"},
    {"id": "a-1", "email": "admin@jeju.kr", "name": "데이터관리과", "role": "ADMIN", "status": "ACTIVE"},
]

# 테스트용 간단 계정 (아이디 = 비밀번호). 로그인 칸에 이메일 대신 아이디를 그대로 넣습니다.
TEST_ACCOUNTS = [
    ({"id": "t-a123", "email": "a123", "name": "테스트 관광객", "role": "USER", "status": "ACTIVE"}, "a123"),
    ({"id": "t-b123", "email": "b123", "name": "테스트 상권", "role": "MERCHANT", "status": "ACTIVE",
      "store_id": "st-aewol-0142", "store_name": "애월 돌담국수"}, "b123"),
    ({"id": "t-c123", "email": "c123", "name": "테스트 관리자", "role": "ADMIN", "status": "ACTIVE"}, "c123"),
]


def seed_demo_accounts() -> None:
    """프론트 목업과 같은 시연 계정을 없을 때만 만듭니다 (비밀번호 jeju1234)."""
    created = []
    for acc in DEMO_ACCOUNTS:
        if db.get_user_by_email(acc["email"]) or db.get_user(acc["id"]):
            continue
        db.insert_user({**acc, "password_hash": hash_password(DEMO_PASSWORD)})
        created.append(acc["email"])
    if created:
        logger.info("시연 계정을 만들었어요: %s (비밀번호 %s)", ", ".join(created), DEMO_PASSWORD)
    for acc, password in TEST_ACCOUNTS:
        if db.get_user_by_email(acc["email"]) or db.get_user(acc["id"]):
            continue
        db.insert_user({**acc, "password_hash": hash_password(password)})
        logger.info("테스트 계정을 만들었어요: %s (%s)", acc["email"], acc["role"])
