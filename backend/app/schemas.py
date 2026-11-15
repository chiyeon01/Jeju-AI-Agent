# ─────────────────────────────────────────────
# 요청/응답 스키마
# frontend/src/api/client.js 가 보내는 body, 받는 응답 형태와 1:1로 맞춥니다.
# ─────────────────────────────────────────────
from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


# ── 공통 ──────────────────────────────────────
class PlaceOut(BaseModel):
    id: str
    name: str
    region: str
    kind: str
    lat: float
    lon: float
    indoor: bool
    rating: float
    stay: int
    seafood: bool = False
    reasons: list[list[str]]


class RegionOut(BaseModel):
    id: str
    name: str
    lat: float
    lon: float


# ── POST /tourist/profile ───────────────────────
class ProfileRequest(BaseModel):
    answers: dict[str, Literal["a", "b"]] = Field(default_factory=dict)
    companion: str | None = None
    transport: str | None = None
    budget: str | None = None
    startTime: str | None = None
    hours: int | None = None


class ProfileOut(BaseModel):
    code: str
    name: str
    desc: str
    scores: dict[str, int]
    tags: list[str]
    # 프론트가 넘긴 추가 입력을 그대로 돌려줘서, 다음 단계(코스 플래너)가 이 객체 하나로 동작하게 함
    companion: str | None = None
    transport: str | None = None
    budget: str | None = None
    startTime: str | None = None
    hours: int | None = None


# ── POST /tourist/course ────────────────────────
class OriginIn(BaseModel):
    id: str | None = None
    name: str | None = None
    lat: float
    lon: float


class CourseRequest(BaseModel):
    profile: ProfileOut
    origin: OriginIn
    weather: Literal["clear", "rain"] = "clear"
    startTime: str = "15:00"
    removeCount: int = 0
    seafood: bool = False


class CourseStopOut(PlaceOut):
    at: str
    move: int


class CourseOut(BaseModel):
    weather: str
    stops: list[CourseStopOut]


# ── POST /tourist/course/chat ───────────────────
class ChatRequest(BaseModel):
    message: str


class ChatPatch(BaseModel):
    seafood: bool | None = None
    removeCount: int | None = None
    weather: Literal["clear", "rain"] | None = None


class ChatOut(BaseModel):
    reply: str
    patch: ChatPatch | None = None


# ── POST /tourist/reviews ───────────────────────
class ReviewIn(BaseModel):
    placeId: str
    stars: int = Field(ge=1, le=5)
    text: str = ""
    profile: str | None = None  # 성향 코드 (예: "NPAJ")


class ReviewsRequest(BaseModel):
    reviews: list[ReviewIn]


class ReviewsOut(BaseModel):
    ok: bool
    accepted: int


# ── POST /owner/ask ─────────────────────────────
class OwnerAskRequest(BaseModel):
    question: str


class OwnerAskOut(BaseModel):
    answer: str


# ── POST /owner/actions ─────────────────────────
class OwnerActionRequest(BaseModel):
    kind: str = "메뉴"
    title: str


class OwnerActionOut(BaseModel):
    ok: bool
    id: int | None = None


# ── 지도(Kakao) ──────────────────────────────────
class GeocodeRequest(BaseModel):
    query: str


class GeocodeItem(BaseModel):
    address: str | None = None
    roadAddress: str | None = None
    lat: float
    lon: float


class GeocodeOut(BaseModel):
    source: Literal["kakao", "none"]
    items: list[GeocodeItem]


class PlaceSearchRequest(BaseModel):
    query: str
    lat: float | None = None
    lon: float | None = None


class PlaceSearchItem(BaseModel):
    name: str | None = None
    address: str | None = None
    roadAddress: str | None = None
    category: str | None = None
    lat: float
    lon: float


class PlaceSearchOut(BaseModel):
    source: Literal["kakao", "none"]
    items: list[PlaceSearchItem]


class ReverseGeocodeRequest(BaseModel):
    lat: float
    lon: float


class ReverseGeocodeOut(BaseModel):
    source: Literal["kakao", "local"]
    regionId: str
    regionName: str
    distanceKm: float
    fullAddress: str | None = None
