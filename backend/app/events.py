# ─────────────────────────────────────────────
# 실시간 이벤트 (관리 콘솔 피드)
# 코스 선택·평가 등록·가입·조치 등록이 일어나면 events 테이블에 쌓고,
# WebSocket /ws/events?token=<관리자 액세스 토큰> 에 연결된 콘솔로 { type, text, at } 를 보냅니다.
# 엔드포인트는 동기 함수(스레드풀)라서 이벤트 루프로 넘길 때 call_soon_threadsafe 를 씁니다.
# ─────────────────────────────────────────────
from __future__ import annotations

import asyncio
import logging
from datetime import datetime

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app import db
from app.errors import ApiError
from app.security import user_from_token

logger = logging.getLogger("jejuitda.events")

# 프론트 화면이 쓰는 이벤트 종류
VISIT, REVIEW, COURSE, REVIEW_TAG, STORE = "방문 인증", "평가 등록", "코스 선택", "리뷰 분류", "매장 등록"
ANALYSIS, REPORT = "리뷰 분석", "보고서"

_loop: asyncio.AbstractEventLoop | None = None
# 구독자 → 받을 장소 id (None 이면 관리자: 전부). 상권 주인은 자기 가게 장소의 이벤트만 받습니다
_subscribers: dict[asyncio.Queue, set[str] | None] = {}


def bind_loop(loop: asyncio.AbstractEventLoop) -> None:
    global _loop
    _loop = loop


def publish(type_: str, text: str, *, region: str | None = None, user_id: str | None = None,
            place_id: str | None = None, extra: dict | None = None) -> None:
    """이벤트를 저장하고 연결된 콘솔·사장님 화면에 보냅니다. 어느 스레드에서 불러도 됩니다.
    place_id 가 있으면 그 장소를 가진 상권 주인에게도 갑니다."""
    created = db.insert_event(type_, text, region, user_id)
    msg = {"type": type_, "text": text, "at": datetime.fromisoformat(created).strftime("%H:%M:%S"),
           **({"placeId": place_id} if place_id else {}), **(extra or {})}
    if _loop is None or not _subscribers:
        return
    for q, places in list(_subscribers.items()):
        if places is None or (place_id and place_id in places):
            _loop.call_soon_threadsafe(_put_nowait, q, msg)


def _put_nowait(q: asyncio.Queue, msg: dict) -> None:
    try:
        q.put_nowait(msg)
    except asyncio.QueueFull:
        pass  # 느린 구독자는 건너뜀


ws_router = APIRouter()


@ws_router.websocket("/ws/events")
async def events_ws(ws: WebSocket, token: str = "") -> None:
    try:
        user = user_from_token(token)
        if user["role"] not in ("ADMIN", "MERCHANT"):
            raise ApiError(403, "FORBIDDEN", "관리자와 상권 주인만 볼 수 있어요.")
    except ApiError:
        await ws.close(code=4401)
        return
    await ws.accept()
    q: asyncio.Queue = asyncio.Queue(maxsize=200)
    admin = user["role"] == "ADMIN"
    _subscribers[q] = None if admin else {p for p in [db.get_store_place(user["id"])] if p}
    try:
        # 관리자는 접속하자마자 최근 이벤트를 오래된 순으로 받아 피드를 채움
        for e in reversed(db.recent_events(10) if admin else []):
            await ws.send_json({"type": e["type"], "text": e["text"],
                                "at": datetime.fromisoformat(e["created_at"]).strftime("%H:%M:%S")})
        while True:
            await ws.send_json(await q.get())
    except (WebSocketDisconnect, RuntimeError):
        pass
    finally:
        _subscribers.pop(q, None)
