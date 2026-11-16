# ─────────────────────────────────────────────
# 제주데이터허브 연동 엔드포인트 (/api/datahub/...)
# 프로젝트 키는 서버에만 두고, 프론트·Agent는 이 경로로 가공된 값을 받습니다.
# 날짜(date)를 비우면 그 데이터의 "가장 최근 날짜"를 자동으로 찾아 씁니다.
# ─────────────────────────────────────────────
from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, HTTPException, Query, Request

from app.data.datahub_catalog import DATASETS
from app.services import datahub_service as svc
from app.services.datahub_client import DataHubError, get_datahub_client

router = APIRouter(prefix="/datahub", tags=["datahub"])

DateQ = Query(None, description="YYYY-MM-DD 또는 YYYYMMDD. 비우면 가장 최근 날짜")


def _run(fn, *args, **kwargs):
    try:
        return fn(*args, **kwargs)
    except DataHubError as e:
        raise HTTPException(status_code=e.status, detail=str(e)) from e


@router.get("/status")
def status() -> dict:
    """키 설정 여부, 오늘 데이터별 호출 수, 연동된 데이터 목록."""
    return svc.status()


@router.get("/population")
def population(date: str | None = DateQ, emd: str | None = Query(None, description="읍면동 (예: 애월읍)")) -> dict:
    """읍면동 단위 내국인 유동인구 — 읍면동별·서비스 지역별 합계 (D2)."""
    return _run(svc.population, date, emd)


@router.get("/population/foreign")
def foreign_population(
    kind: Literal["short", "long"] = Query("short", description="short=단기체류(관광객), long=장기체류"),
    date: str | None = DateQ,
    emd: str | None = None,
    nationality: str | None = Query(None, description="예: 중국, 일본, 미국"),
) -> dict:
    """외국인 유동인구 — 국적별·읍면동별 합계 (D2)."""
    return _run(svc.foreign_population, kind, date, emd, nationality)


@router.get("/crowd")
def crowd(refresh: bool = Query(False, description="true면 허브에서 다시 계산")) -> dict:
    """서비스 지역별 혼잡도 지수(0~1) — 코스 플래너가 쓰는 값."""
    data = _run(svc.region_crowd, refresh)
    if data is None:
        raise HTTPException(status_code=503, detail="아직 혼잡도를 계산하지 않았어요. refresh=true 로 호출해 보세요")
    return data


@router.get("/weather")
def weather(date: str | None = DateQ, observatory: str | None = Query(None, description="관측소명 (예: 중문, 한림, 성산)")) -> dict:
    """일별 기상 (D7). 허브 데이터가 최신이 아니어서 실시간 날씨 대신 과거 기후 참고용입니다."""
    return _run(svc.weather, date, observatory)


@router.get("/sights")
def sights(
    start: str | None = Query(None, description="YYYY-MM. 비우면 최신 달"),
    end: str | None = Query(None, description="YYYY-MM"),
    name: str | None = Query(None, description="관광지명 (예: 비자림)"),
) -> dict:
    """관광지별 내·외국인 유입자 수 (D4, 월 단위)."""
    return _run(svc.sights, start, end, name)


@router.get("/bus/stations")
def bus_stations(name: str | None = Query(None, description="정류소명 (예: 제주국제공항)"), limit: int = Query(200, le=2000)) -> dict:
    """버스 정류소 기본 정보 (D6)."""
    return _run(svc.bus_stations, name, limit)


@router.get("/bus/routes")
def bus_routes(startStationId: str | None = Query(None, description="시작 정류소 ID"), limit: int = Query(200, le=2000)) -> dict:
    """버스 노선 기본 정보 (D6)."""
    return _run(svc.bus_routes, startStationId, limit)


@router.get("/bus/usage")
def bus_usage(date: str | None = DateQ, top: int = Query(30, le=500)) -> dict:
    """정류소별 하루 이용자 수 상위 N곳 (D6). 처음 조회하는 날짜는 40~60회 호출돼 오래 걸립니다."""
    return _run(svc.bus_usage, date, top)


@router.get("/wifi")
def wifi(date: str | None = DateQ, top: int = Query(30, le=2000), name: str | None = Query(None, description="AP그룹명 일부")) -> dict:
    """와이파이 AP그룹별 사용자 수 + 전체 사용자 수 (D3)."""
    return _run(svc.wifi_usage, date, top, name)


@router.get("/raw/{dataset}")
def raw(dataset: str, request: Request, maxRows: int = Query(100, le=5000)) -> dict:
    """원본 그대로 조회 (탐색용). 쿼리 파라미터는 데이터별 요청변수(/datahub/status 참고)를 그대로 넘깁니다."""
    if dataset not in DATASETS:
        raise HTTPException(status_code=404, detail=f"알 수 없는 데이터: {dataset}")
    params = {k: v for k, v in request.query_params.items() if k in DATASETS[dataset]["params"]}
    res = _run(get_datahub_client().fetch, dataset, params, max_rows=maxRows)
    return {"dataset": dataset, "title": DATASETS[dataset]["title"], "total": res.total,
            "returned": len(res.rows), "cached": res.cached, "rows": res.rows}
