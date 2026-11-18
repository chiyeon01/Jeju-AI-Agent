# ─────────────────────────────────────────────
# 실데이터 인사이트 · 실시간 날씨
#  GET  /weather/now?lat&lon                 로그인한 누구나 (서버가 대신 날씨를 가져옴)
#  GET  /places/photo?q=                     장소 대표 사진 (네이버 이미지 검색, 키 있을 때)
#  GET  /admin/insights/regions              지역 점수 0~10 (요청마다 새로 계산)
#  GET  /admin/insights/places              장소(고유 번호)별 평가·사장님 연결·최근 분석
#  GET  /admin/reports  · POST /admin/reports  Agent 지역 보고서 목록 · 새로 만들기
#  GET  /owner/places?q=                     가게 연결용 장소 검색 (관광객이 평점을 남긴 곳만)
#  GET  /owner/place  · PUT /owner/place      내 가게와 연결된 장소
#  GET  /owner/my-reviews                    내 가게 별점·리뷰·최근 분석
#  POST /owner/my-reviews/analysis           Agent 리뷰 분석 (저장)
#  GET  /owner/my-reviews/analysis           지난 분석 목록
# ─────────────────────────────────────────────
from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel

from app import db
from app.errors import ApiError
from app.security import current_user, require_roles
from app.services import insight_service as svc
from app.services.photo_service import place_photo
from app.services.weather_service import live_weather

router = APIRouter(tags=["insights"])
admin = require_roles("ADMIN")
merchant = require_roles("MERCHANT", "ADMIN")


@router.get("/weather/now")
def weather_now(lat: float = Query(..., ge=32, le=35), lon: float = Query(..., ge=125, le=128),
                _: dict = Depends(current_user)) -> dict:
    return live_weather(lat, lon)


@router.get("/places/photo")
def photo(q: str = Query(..., min_length=1, max_length=60), _: dict = Depends(current_user)) -> dict:
    """장소 대표 사진 (네이버 이미지 검색 첫 결과). 키가 없거나 결과가 없으면 { photo: null }"""
    return {"photo": place_photo(q)}


@router.get("/admin/insights/regions")
def region_scores(_: dict = Depends(admin)) -> dict:
    return svc.region_scores()


@router.get("/admin/insights/places")
def place_overview(_: dict = Depends(admin)) -> list[dict]:
    """장소 고유 번호별 평가 수·평균·사장님 연결·최근 Agent 분석"""
    return svc.place_overview()


@router.get("/admin/reports")
def reports(limit: int = Query(20, ge=1, le=100), _: dict = Depends(admin)) -> list[dict]:
    return db.list_reports("REGION", None, limit)


@router.post("/admin/reports", status_code=201)
def create_report(user: dict = Depends(admin)) -> dict:
    return svc.create_region_report(user["id"])


class PlaceLink(BaseModel):
    placeId: str


@router.get("/owner/places")
def places(q: str = Query("", max_length=40), limit: int = Query(50, ge=1, le=200),
           _: dict = Depends(merchant)) -> list[dict]:
    """관광객이 실제로 평점을 남긴 가게만 [{ id, no, name, region, kind, reviews, avgStars, lastReviewAt }] (최근 평가 순)"""
    return svc.merchant_places(q, limit)


@router.get("/owner/place")
def my_place(user: dict = Depends(merchant)) -> dict:
    pid = db.get_store_place(user["id"])
    p = svc.PLACES_BY_ID.get(pid) if pid else None
    return {"placeId": pid if p else None,
            "place": {**{k: p[k] for k in ("id", "name", "region", "kind")}, "no": db.place_no(p["id"])} if p else None}


@router.put("/owner/place")
def link_place(req: PlaceLink, user: dict = Depends(merchant)) -> dict:
    p = svc.place_or_404(req.placeId)
    if p["kind"] not in svc.STORE_KINDS or not db.is_rated_place(p["id"]):
        raise ApiError(400, "PLACE_NOT_RATED", "아직 관광객 평점이 없는 장소예요. 평점을 받은 가게만 연결할 수 있어요.")
    db.set_store_place(user["id"], req.placeId)
    return my_place(user)


@router.get("/owner/my-reviews")
def my_reviews(user: dict = Depends(merchant)) -> dict:
    return svc.my_reviews(db.get_store_place(user["id"]))


@router.post("/owner/my-reviews/analysis", status_code=201)
def analyze(user: dict = Depends(merchant)) -> dict:
    return svc.analyze_my_reviews(svc.place_or_404(db.get_store_place(user["id"]))["id"], user["id"])


@router.get("/owner/my-reviews/analysis")
def analyses(user: dict = Depends(merchant)) -> list[dict]:
    pid = svc.place_or_404(db.get_store_place(user["id"]))["id"]
    return db.list_reports("STORE", pid, 10)
