# ─────────────────────────────────────────────
# 자체 생성 데이터 저장소 (방문 후 평가, 사장님 개선 조치)
#
# 지금은 설치 없이 바로 동작해야 하는 데모 범위라 SQLite 파일 하나로 둡니다.
# 기획서(6장)의 운영 환경(PostgreSQL + PostGIS 등)으로 옮길 때는
# 이 모듈의 함수 시그니처만 유지한 채 구현을 교체하면 됩니다.
# ─────────────────────────────────────────────
from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone

from app.config import get_settings

_SCHEMA = """
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
"""


def _connect() -> sqlite3.Connection:
    settings = get_settings()
    db_path = settings.database_file
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with _connect() as conn:
        conn.executescript(_SCHEMA)


@contextmanager
def get_conn():
    conn = _connect()
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def insert_review(place_id: str, stars: int, text: str, profile_code: str | None) -> int:
    with get_conn() as conn:
        cur = conn.execute(
            "INSERT INTO reviews (place_id, stars, text, profile_code, created_at) VALUES (?, ?, ?, ?, ?)",
            (place_id, stars, text, profile_code, datetime.now(timezone.utc).isoformat()),
        )
        return cur.lastrowid


def insert_owner_action(kind: str, title: str) -> int:
    with get_conn() as conn:
        cur = conn.execute(
            "INSERT INTO owner_actions (kind, title, created_at) VALUES (?, ?, ?)",
            (kind, title, datetime.now(timezone.utc).isoformat()),
        )
        return cur.lastrowid


def review_stats() -> tuple[int, float]:
    """(총 리뷰 수, 평균 별점). 리뷰가 없으면 (0, 0.0)."""
    with get_conn() as conn:
        row = conn.execute("SELECT COUNT(*) AS n, AVG(stars) AS avg_stars FROM reviews").fetchone()
        n = row["n"] or 0
        avg_stars = row["avg_stars"] or 0.0
        return n, round(avg_stars, 2)
