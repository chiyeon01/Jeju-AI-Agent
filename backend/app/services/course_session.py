# ─────────────────────────────────────────────
# 사용자별 코스 대화 상태 (서버 메모리)
#
# 프론트는 /tourist/course/chat 에 메시지만 보내고, 응답 patch 로 /tourist/course 를 다시
# 부릅니다. patch 에 담을 수 없는 요청("카페는 바다 보이는 곳으로", "함덕 해변 빼줘")은
# 여기 사용자별 선호(prefs)로 기억해 두고, 다음 코스 계산 때 course_service 가 반영합니다.
# 또 마지막 코스 요청·결과를 기억해 두어, 대화 요청이 실제로 코스를 바꾸는지 미리 확인합니다.
#
# - 단일 프로세스(uvicorn 1개) 기준 메모리 저장입니다. 서버를 재시작하면 비워집니다.
# - 사용자 id 기준이라 같은 시연 계정을 여러 명이 동시에 쓰면 선호가 섞일 수 있습니다.
# - 새 여행(성향 분석)을 시작하면 reset() 으로 비우고, 6시간 지나도 비웁니다.
# ─────────────────────────────────────────────
from __future__ import annotations

import threading
import time
from dataclasses import dataclass, field

from app.schemas import CourseRequest

TTL_SECONDS = 6 * 3600


@dataclass
class CoursePrefs:
    ocean_kinds: set[str] = field(default_factory=set)   # 바다 보이는 곳을 우선할 장소 종류
    exclude_ids: set[str] = field(default_factory=set)   # 빼 달라고 한 장소
    exclude_kinds: set[str] = field(default_factory=set)  # 빼 달라고 한 장소 종류

    def copy(self) -> "CoursePrefs":
        return CoursePrefs(set(self.ocean_kinds), set(self.exclude_ids), set(self.exclude_kinds))


@dataclass
class CourseSession:
    prefs: CoursePrefs = field(default_factory=CoursePrefs)
    last_req: CourseRequest | None = None
    last_stop_ids: list[str] = field(default_factory=list)
    first_weather: str | None = None  # 이번 여행 첫 코스의 날씨 ("원래대로" 요청 때 되돌릴 값)
    updated: float = field(default_factory=time.time)


_lock = threading.Lock()
_sessions: dict[str, CourseSession] = {}


def get(user_id: str) -> CourseSession:
    with _lock:
        s = _sessions.get(user_id)
        if s is None or time.time() - s.updated > TTL_SECONDS:
            s = _sessions[user_id] = CourseSession()
        return s


def reset(user_id: str) -> None:
    with _lock:
        _sessions.pop(user_id, None)


def save_plan(user_id: str, req: CourseRequest, stop_ids: list[str]) -> None:
    s = get(user_id)
    with _lock:
        s.last_req = req
        s.first_weather = s.first_weather or req.weather
        s.last_stop_ids = stop_ids
        s.updated = time.time()


def save_prefs(user_id: str, prefs: CoursePrefs) -> None:
    s = get(user_id)
    with _lock:
        s.prefs = prefs
        s.updated = time.time()
