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

-- 장소 고유 번호: 1부터 차례대로, 중복 없음 (key 는 코스 데이터의 장소 id, 예: p1)
CREATE TABLE IF NOT EXISTS places (
    no INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    region TEXT,
    kind TEXT,
    created_at TEXT NOT NULL
);

-- 상권자 계정 ↔ 관광객 코스에 나오는 장소 (가게 리뷰를 모아 보기 위함)
CREATE TABLE IF NOT EXISTS store_places (
    user_id TEXT PRIMARY KEY,
    place_id TEXT NOT NULL,
    created_at TEXT NOT NULL
);

-- Agent 가 만든 문서 (Main PC 지역 보고서, 가게 리뷰 분석)
CREATE TABLE IF NOT EXISTS reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    kind TEXT NOT NULL,              -- REGION | STORE
    scope TEXT,                      -- STORE 면 place_id
    title TEXT NOT NULL,
    body TEXT NOT NULL,              -- 마크다운
    data TEXT,                       -- 근거 수치 (JSON)
    source TEXT NOT NULL,            -- gpt | rule
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
    ("reviews", "place_no", "INTEGER"),
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
    seed_places()


def seed_places() -> None:
    """코스 장소 목록을 순서대로 places 에 등록 (이미 있으면 번호 유지). 예전 리뷰에도 번호를 채웁니다."""
    from app.data.tourist_data import PLACES
    with get_conn() as conn:
        have = {r["key"] for r in conn.execute("SELECT key FROM places")}
        for p in PLACES:
            if p["id"] not in have:  # 없는 것만 넣어야 번호가 건너뛰지 않음
                conn.execute("INSERT INTO places (key, name, region, kind, created_at) VALUES (?, ?, ?, ?, ?)",
                             (p["id"], p["name"], p["region"], p["kind"], now_iso()))
            else:  # 장소 이름이 바뀌었으면 (예: 실제 장소로 교체) 번호는 그대로 두고 이름만 맞춥니다
                conn.execute("UPDATE places SET name = ?, region = ?, kind = ? WHERE key = ?",
                             (p["name"], p["region"], p["kind"], p["id"]))
        conn.execute("UPDATE reviews SET place_no = (SELECT no FROM places WHERE places.key = reviews.place_id)"
                     " WHERE place_no IS NULL")
    _place_nos.clear()


_place_nos: dict[str, int] = {}


def place_no(key: str, name: str | None = None, region: str | None = None, kind: str | None = None) -> int:
    """장소의 고유 번호. 처음 보는 장소면 다음 번호로 등록합니다."""
    if key in _place_nos:
        return _place_nos[key]
    with get_conn() as conn:
        row = conn.execute("SELECT no FROM places WHERE key = ?", (key,)).fetchone()
        if row:
            no = row["no"]
        else:
            no = conn.execute("INSERT INTO places (key, name, region, kind, created_at) VALUES (?, ?, ?, ?, ?)",
                              (key, name or key, region, kind, now_iso())).lastrowid
    _place_nos[key] = no
    return no


def place_nos() -> dict[str, int]:
    with get_conn() as conn:
        return {r["key"]: r["no"] for r in conn.execute("SELECT key, no FROM places")}


def owners_of_place(place_id: str) -> list[str]:
    with get_conn() as conn:
        return [r["user_id"] for r in conn.execute("SELECT user_id FROM store_places WHERE place_id = ?", (place_id,))]


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
                  user_id: str | None = None, region: str | None = None, place_no_: int | None = None) -> int:
    with get_conn() as conn:
        cur = conn.execute(
            "INSERT INTO reviews (place_id, place_no, stars, text, profile_code, user_id, region, created_at)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (place_id, place_no_, stars, text, profile_code, user_id, region, now_iso()),
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


# ── 상권자 가게 ↔ 장소 ─────────────────────────
def get_store_place(user_id: str) -> str | None:
    with get_conn() as conn:
        row = conn.execute("SELECT place_id FROM store_places WHERE user_id = ?", (user_id,)).fetchone()
        return row["place_id"] if row else None


def set_store_place(user_id: str, place_id: str) -> None:
    with get_conn() as conn:
        conn.execute("INSERT INTO store_places (user_id, place_id, created_at) VALUES (?, ?, ?)"
                     " ON CONFLICT(user_id) DO UPDATE SET place_id = excluded.place_id", (user_id, place_id, now_iso()))


# ── 실데이터 집계 (관광객 평가·코스 선택) ─────────
def reviews_for_place(place_id: str, limit: int = 50) -> list[dict]:
    with get_conn() as conn:
        return [dict(r) for r in conn.execute(
            "SELECT id, place_no, stars, text, profile_code, created_at FROM reviews WHERE place_id = ? ORDER BY id DESC LIMIT ?",
            (place_id, limit))]


def review_summary_for_place(place_id: str) -> dict:
    with get_conn() as conn:
        row = conn.execute("SELECT COUNT(*) AS n, AVG(stars) AS avg FROM reviews WHERE place_id = ?", (place_id,)).fetchone()
        dist = {r["stars"]: r["n"] for r in conn.execute(
            "SELECT stars, COUNT(*) AS n FROM reviews WHERE place_id = ? GROUP BY stars", (place_id,))}
        types = {r["profile_code"]: r["n"] for r in conn.execute(
            "SELECT profile_code, COUNT(*) AS n FROM reviews WHERE place_id = ? AND profile_code IS NOT NULL"
            " GROUP BY profile_code ORDER BY n DESC", (place_id,))}
    return {"count": row["n"] or 0, "avg": round(row["avg"] or 0.0, 2),
            "dist": {s: dist.get(s, 0) for s in range(1, 6)}, "byType": types}


def review_stats_by_region(since: datetime | None = None) -> dict[str, dict]:
    q = "SELECT region, COUNT(*) AS n, AVG(stars) AS avg FROM reviews WHERE region IS NOT NULL"
    args: tuple = ()
    if since:
        q += " AND created_at >= ?"
        args = (since.isoformat(timespec="seconds"),)
    with get_conn() as conn:
        return {r["region"]: {"count": r["n"], "avg": round(r["avg"] or 0.0, 2)} for r in conn.execute(q + " GROUP BY region", args)}


def rated_places(q: str = "", kinds: tuple[str, ...] = (), limit: int = 50) -> list[dict]:
    """관광객이 실제로 평점을 남긴 장소만 (places 고유 번호·이름 기준). 최근 평가 순.
    q 는 이름 부분 검색, kinds 를 주면 그 종류만."""
    sql = ("SELECT p.key AS id, p.no AS no, p.name AS name, p.region AS region, p.kind AS kind,"
           " COUNT(r.id) AS n, AVG(r.stars) AS avg, MAX(r.created_at) AS last_at"
           " FROM reviews r JOIN places p ON p.key = r.place_id WHERE 1 = 1")
    args: list = []
    if q:
        sql += " AND REPLACE(p.name, ' ', '') LIKE ?"
        args.append(f"%{q.replace(' ', '')}%")
    if kinds:
        sql += f" AND p.kind IN ({', '.join('?' * len(kinds))})"
        args.extend(kinds)
    sql += " GROUP BY p.key ORDER BY last_at DESC LIMIT ?"
    args.append(limit)
    with get_conn() as conn:
        return [{"id": r["id"], "no": r["no"], "name": r["name"], "region": r["region"], "kind": r["kind"],
                 "reviews": r["n"], "avgStars": round(r["avg"] or 0.0, 2), "lastReviewAt": r["last_at"]}
                for r in conn.execute(sql, args)]


def is_rated_place(place_id: str) -> bool:
    with get_conn() as conn:
        return conn.execute("SELECT 1 FROM reviews WHERE place_id = ? LIMIT 1", (place_id,)).fetchone() is not None


def review_stats_by_place() -> dict[str, dict]:
    with get_conn() as conn:
        return {r["place_id"]: {"count": r["n"], "avg": round(r["avg"] or 0.0, 2)} for r in conn.execute(
            "SELECT place_id, COUNT(*) AS n, AVG(stars) AS avg FROM reviews GROUP BY place_id")}


def event_counts_by_region(type_: str, since: datetime) -> dict[str, int]:
    with get_conn() as conn:
        return {r["region"]: r["n"] for r in conn.execute(
            "SELECT region, COUNT(*) AS n FROM events WHERE type = ? AND region IS NOT NULL AND created_at >= ? GROUP BY region",
            (type_, since.isoformat(timespec="seconds")))}


# ── Agent 문서 ────────────────────────────────
def insert_report(kind: str, scope: str | None, title: str, body: str, data: str, source: str, user_id: str | None) -> dict:
    created = now_iso()
    with get_conn() as conn:
        cur = conn.execute(
            "INSERT INTO reports (kind, scope, title, body, data, source, user_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (kind, scope, title, body, data, source, user_id, created))
        return {"id": cur.lastrowid, "kind": kind, "scope": scope, "title": title, "body": body,
                "source": source, "createdAt": created}


def list_reports(kind: str, scope: str | None = None, limit: int = 20) -> list[dict]:
    q, args = "SELECT * FROM reports WHERE kind = ?", [kind]
    if scope is not None:
        q += " AND scope = ?"
        args.append(scope)
    with get_conn() as conn:
        rows = conn.execute(q + " ORDER BY id DESC LIMIT ?", (*args, limit)).fetchall()
    return [{"id": r["id"], "kind": r["kind"], "scope": r["scope"], "title": r["title"], "body": r["body"],
             "source": r["source"], "createdAt": r["created_at"]} for r in rows]
