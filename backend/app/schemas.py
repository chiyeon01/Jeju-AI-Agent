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


# ── GET /regions/nearest ────────────────────────
class NearestRegionOut(RegionOut):
    distanceKm: float


# ── POST /tourist/course ────────────────────────
class CourseOptions(BaseModel):
    seafood: bool = False
    removeCount: int = Field(0, ge=0, le=5)


class CourseRequest(BaseModel):
    profile: ProfileOut
    regionId: str
    startTime: str = Field("15:00", pattern=r"^\d{1,2}:\d{2}$")
    hours: int | None = Field(None, ge=1, le=12)
    weather: Literal["clear", "rain"] = "clear"
    options: CourseOptions = Field(default_factory=CourseOptions)


class CourseStopOut(PlaceOut):
    at: str
    move: int


class WeatherOut(BaseModel):
    code: Literal["clear", "rain"]
    label: str
    temp: int
    icon: str
    note: str


class CourseOut(BaseModel):
    weather: WeatherOut
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
    reviews: list[ReviewIn] = Field(max_length=10)


class ReviewsOut(BaseModel):
    accepted: int
    rejected: int = 0


# ── POST /owner/ask ─────────────────────────────
class OwnerAskRequest(BaseModel):
    question: str


class OwnerAskOut(BaseModel):
    answer: str


# ── POST /owner/actions ─────────────────────────
class OwnerActionRequest(BaseModel):
    kind: str = Field("메뉴", max_length=20)
    title: str = Field(min_length=1, max_length=100)


class OwnerActionOut(BaseModel):
    id: int
    kind: str
    title: str
    status: str
    createdAt: str


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
