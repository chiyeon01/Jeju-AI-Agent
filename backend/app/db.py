# ─────────────────────────────────────────────
# 자체 생성 데이터 저장소 (SQLite 파일 하나)
#  - users / refresh_tokens : 로그인
#  - reviews                : 방문 후 평가
#  - owner_actions          : 사장님 개선 조치
#  - events                 : 실시간 이벤트(관리 콘솔 피드·오늘 집계)
#  - access_logs            : 조회·반출·로그인 기록 (관리 콘솔 접근·보안)
#
# 설치 없이 바로 동작해야 하는 데모 범위라 SQLite로 둡니다. 기획서(6장)의 PostgreSQL로
# 옮길 때는 이 모듈 함수의 시그니처만 유지하고 구현을 바꾸면 됩니다.
# ─────────────────────────────────────────────
from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from datetime import datetime, timedelta

from app.config import get_settings

_SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    role TEXT NOT NULL,              -- USER | MERCHANT | ADMIN
    status TEXT NOT NULL,            -- ACTIVE | PENDING | SUSPENDED
    password_hash TEXT NOT NULL,
    store_id TEXT,
    store_name TEXT,
    business_no TEXT,
    created_at TEXT NOT NULL,
    last_login_at TEXT
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
    token_hash TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    revoked INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS reviews (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    place_id TEXT NOT NULL,
    stars INTEGER NOT NULL,
    text TEXT DEFAULT '',
    profile_code TEXT,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS owner_actions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    kind TEXT NOT NULL,
    title TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL,
    text TEXT NOT NULL,
    region TEXT,
    user_id TEXT,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS access_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    who TEXT NOT NULL,
    action TEXT NOT NULL,
    target TEXT NOT NULL,
    ok INTEGER NOT NULL,
    created_at TEXT NOT NULL
);
"""

# 예전 버전 DB에 없던 컬럼을 덧붙입니다 (있으면 건너뜀).
_MIGRATIONS = [
    ("reviews", "user_id", "TEXT"),
    ("reviews", "region", "TEXT"),
    ("owner_actions", "store_id", "TEXT"),
    ("owner_actions", "user_id", "TEXT"),
    ("owner_actions", "status", "TEXT DEFAULT 'MEASURING'"),
]


def now() -> datetime:
    return datetime.now()


def now_iso() -> str:
    return now().isoformat(timespec="seconds")


def _connect() -> sqlite3.Connection:
    db_path = get_settings().database_file
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path, timeout=10)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with _connect() as conn:
        conn.executescript(_SCHEMA)
        for table, col, decl in _MIGRATIONS:
            cols = {r["name"] for r in conn.execute(f"PRAGMA table_info({table})")}
            if col not in cols:
                conn.execute(f"ALTER TABLE {table} ADD COLUMN {col} {decl}")


@contextmanager
def get_conn():
    conn = _connect()
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


# ── 사용자 ────────────────────────────────────
def get_user_by_email(email: str) -> dict | None:
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM users WHERE email = ?", (email.strip().lower(),)).fetchone()
        return dict(row) if row else None


def get_user(user_id: str) -> dict | None:
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
        return dict(row) if row else None


def list_users() -> list[dict]:
    with get_conn() as conn:
        return [dict(r) for r in conn.execute(
            "SELECT * FROM users ORDER BY CASE role WHEN 'ADMIN' THEN 0 WHEN 'MERCHANT' THEN 1 ELSE 2 END, created_at")]


def insert_user(user: dict) -> None:
    with get_conn() as conn:
        conn.execute(
            "INSERT INTO users (id, email, name, role, status, password_hash, store_id, store_name, business_no, created_at)"
            " VALUES (:id, :email, :name, :role, :status, :password_hash, :store_id, :store_name, :business_no, :created_at)",
            {"store_id": None, "store_name": None, "business_no": None, "created_at": now_iso(), **user},
        )


def next_user_id(prefix: str) -> str:
    with get_conn() as conn:
        rows = conn.execute("SELECT id FROM users WHERE id LIKE ?", (f"{prefix}-%",)).fetchall()
    nums = [int(r["id"].split("-", 1)[1]) for r in rows if r["id"].split("-", 1)[1].isdigit()]
    return f"{prefix}-{max(nums, default=0) + 1}"


def update_user(user_id: str, fields: dict) -> None:
    if not fields:
        return
    sets = ", ".join(f"{k} = :{k}" for k in fields)
    with get_conn() as conn:
        conn.execute(f"UPDATE users SET {sets} WHERE id = :id", {**fields, "id": user_id})


# ── 리프레시 토큰 ─────────────────────────────
def save_refresh_token(token_hash: str, user_id: str, expires_at: datetime) -> None:
    with get_conn() as conn:
        conn.execute("INSERT INTO refresh_tokens (token_hash, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)",
                     (token_hash, user_id, expires_at.isoformat(timespec="seconds"), now_iso()))


def get_refresh_token(token_hash: str) -> dict | None:
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM refresh_tokens WHERE token_hash = ?", (token_hash,)).fetchone()
        return dict(row) if row else None


def revoke_refresh_token(token_hash: str) -> None:
    with get_conn() as conn:
        conn.execute("UPDATE refresh_tokens SET revoked = 1 WHERE token_hash = ?", (token_hash,))


def revoke_user_tokens(user_id: str) -> None:
    with get_conn() as conn:
        conn.execute("UPDATE refresh_tokens SET revoked = 1 WHERE user_id = ?", (user_id,))


# ── 평가 ──────────────────────────────────────
def insert_review(place_id: str, stars: int, text: str, profile_code: str | None,
                  user_id: str | None = None, region: str | None = None) -> int:
    with get_conn() as conn:
        cur = conn.execute(
            "INSERT INTO reviews (place_id, stars, text, profile_code, user_id, region, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (place_id, stars, text, profile_code, user_id, region, now_iso()),
        )
        return cur.lastrowid


def review_stats() -> tuple[int, float]:
    """(총 리뷰 수, 평균 별점). 리뷰가 없으면 (0, 0.0)."""
    with get_conn() as conn:
        row = conn.execute("SELECT COUNT(*) AS n, AVG(stars) AS avg_stars FROM reviews").fetchone()
        return row["n"] or 0, round(row["avg_stars"] or 0.0, 2)


def reviews_by_user_since(user_id: str, since: datetime) -> int:
    with get_conn() as conn:
        return conn.execute("SELECT COUNT(*) FROM reviews WHERE user_id = ? AND created_at >= ?",
                            (user_id, since.isoformat(timespec="seconds"))).fetchone()[0]


def review_counts_by_region() -> dict[str, int]:
    with get_conn() as conn:
        return {r["region"]: r["n"] for r in conn.execute(
            "SELECT region, COUNT(*) AS n FROM reviews WHERE region IS NOT NULL GROUP BY region")}


def heavy_reviewers(window: timedelta, limit: int) -> list[dict]:
    """같은 계정이 window 안에 limit건을 넘게 평가한 경우 (허위 평가 의심)."""
    since = (now() - window).isoformat(timespec="seconds")
    with get_conn() as conn:
        return [dict(r) for r in conn.execute(
            "SELECT user_id, COUNT(*) AS n FROM reviews WHERE created_at >= ? AND user_id IS NOT NULL"
            " GROUP BY user_id HAVING n > ?", (since, limit))]


# ── 사장님 조치 ───────────────────────────────
def insert_owner_action(kind: str, title: str, store_id: str | None = None, user_id: str | None = None) -> dict:
    created = now_iso()
    with get_conn() as conn:
        cur = conn.execute(
            "INSERT INTO owner_actions (kind, title, store_id, user_id, status, created_at) VALUES (?, ?, ?, ?, 'MEASURING', ?)",
            (kind, title, store_id, user_id, created),
        )
        return {"id": cur.lastrowid, "kind": kind, "title": title, "status": "MEASURING", "createdAt": created}


# ── 이벤트 ────────────────────────────────────
def insert_event(type_: str, text: str, region: str | None = None, user_id: str | None = None) -> str:
    created = now_iso()
    with get_conn() as conn:
        conn.execute("INSERT INTO events (type, text, region, user_id, created_at) VALUES (?, ?, ?, ?, ?)",
                     (type_, text, region, user_id, created))
    return created


def event_counts_since(since: datetime) -> dict[str, int]:
    with get_conn() as conn:
        return {r["type"]: r["n"] for r in conn.execute(
            "SELECT type, COUNT(*) AS n FROM events WHERE created_at >= ? GROUP BY type",
            (since.isoformat(timespec="seconds"),))}


def recent_events(limit: int = 30) -> list[dict]:
    with get_conn() as conn:
        return [dict(r) for r in conn.execute("SELECT * FROM events ORDER BY id DESC LIMIT ?", (limit,))]


# ── 접근 기록 ─────────────────────────────────
def insert_access_log(who: str, action: str, target: str, ok: bool) -> None:
    with get_conn() as conn:
        conn.execute("INSERT INTO access_logs (who, action, target, ok, created_at) VALUES (?, ?, ?, ?, ?)",
                     (who, action, target, 1 if ok else 0, now_iso()))


def recent_access_logs(limit: int = 50) -> list[dict]:
    with get_conn() as conn:
        return [dict(r) for r in conn.execute("SELECT * FROM access_logs ORDER BY id DESC LIMIT ?", (limit,))]
