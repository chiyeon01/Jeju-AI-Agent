# ─────────────────────────────────────────────
# 제주데이터허브 API 목록 (프로젝트 "제주상권"에 담은 11종)
#
# 호출 주소: {JEJU_DATA_HUB_BASE_URL}/{code}/{JEJU_DATA_HUB_API_KEY}?{params}
# 응답 형식: {"totCnt": 전체 건수, "hasMore": bool, "data": [...]}
# 페이지: number(1부터) + limit(한 번에 최대 100건, 그 이상은 허브가 5xx를 돌려줌)
# 일일 쿼터: 데이터마다 프로젝트당 1,000회
#
# code·요청변수·응답항목은 https://jejudatahub.net/api/data/view?id={hub_id} 에서 확인한 값입니다.
# freshness 는 2026-11 기준 실제 호출로 확인한 데이터 제공 범위입니다.
# ─────────────────────────────────────────────
from __future__ import annotations

DATASETS: dict[str, dict] = {
    "population": {
        "hub_id": 583,
        "code": "Daaa1t3at3tt8a8DD3t55538t35Dab1t",
        "title": "읍면동 단위 내국인 유동인구",
        "source": "D2",
        "params": ["startDate", "endDate", "city", "emd", "gender", "ageGroup"],
        "required": ["startDate", "endDate"],
        "date_param": "startDate",
        "date_format": "%Y%m%d",
        "fields": ["baseDate", "city", "emd", "gender", "ageGroup", "resdPop", "workPop", "visitPop"],
        "freshness": "일 단위, 약 2~3개월 지연 (확인 시 최신 2026-08-31)",
    },
    "foreign_short": {
        "hub_id": 589,
        "code": "t18b1bttt8abaDt51b8aat85ttaa8t5b",
        "title": "읍면동 단위 외국인 단기체류 유동인구",
        "source": "D2",
        "params": ["startDate", "endDate", "city", "emd", "nationality"],
        "required": ["startDate", "endDate"],
        "date_param": "startDate",
        "date_format": "%Y%m%d",
        "fields": ["baseDate", "nationality", "city", "emd", "visitPop"],
        "freshness": "일 단위, 약 2~3개월 지연",
    },
    "foreign_long": {
        "hub_id": 590,
        "code": "1aabbD515b0t9ataDD055551D5b0t1t1",
        "title": "읍면동 단위 외국인 장기체류 유동인구",
        "source": "D2",
        "params": ["startDate", "endDate", "city", "emd", "nationality"],
        "required": ["startDate", "endDate"],
        "date_param": "startDate",
        "date_format": "%Y%m%d",
        "fields": ["baseDate", "nationality", "city", "emd", "resdPop", "workPop", "visitPop"],
        "freshness": "일 단위, 지연 있음",
    },
    "weather": {
        "hub_id": 579,
        "code": "1aD5taat1attaa51Db1511b51ab9Da19",
        "title": "일별 기상 정보",
        "source": "D7",
        "params": ["searchDate", "observatoryName"],
        "required": ["searchDate"],
        "date_param": "searchDate",
        "date_format": "%Y%m%d",
        "fields": ["observatoryName", "baseDate", "averageTemperature", "lowestTemperature", "highestTemperature",
                   "dailyRainfall", "maximumWindSpeed", "averageWindSpeed", "maximumWindSpeedDirection"],
        "freshness": "일 단위이나 최근 데이터 없음 (2024-06 있음, 2025-11 없음) → 실시간 날씨로는 부족",
    },
    "sights_domestic": {
        "hub_id": 591,
        "code": "bt11Daa5at1tat515DDtaa9D5aa99t11",
        "title": "관광지별 내국인 유입자 수",
        "source": "D4",
        "params": ["startDate", "endDate", "sightsName", "payType"],
        "required": ["startDate", "endDate"],
        "date_param": "startDate",
        "date_format": "%Y%m",
        "fields": ["dtYearMonth", "sightsName", "payType", "userCnt"],
        "freshness": "월 단위, 2009-01 ~ 2024-12",
    },
    "sights_foreign": {
        "hub_id": 592,
        "code": "12ta2a2t291tDbbabtbD9t1a219tbDbt",
        "title": "관광지별 외국인 유입자 수",
        "source": "D4",
        "params": ["startDate", "endDate", "sightsName", "payType"],
        "required": ["startDate", "endDate"],
        "date_param": "startDate",
        "date_format": "%Y%m",
        "fields": ["dtYearMonth", "sightsName", "payType", "userCnt"],
        "freshness": "월 단위, 2009-01 ~ 2024-12",
    },
    "bus_stations": {
        "hub_id": 612,
        "code": "DD11ab6a6t11D16baaa1a2tD26ata161",
        "title": "버스 정류소 기본 정보",
        "source": "D6",
        "params": ["stationName"],
        "required": [],
        "date_param": None,
        "fields": ["stationId", "stationType", "stationName", "stationAddress", "direction", "longitude", "latitude", "localInfo"],
        "freshness": "기준 정보 (매일 갱신)",
    },
    "bus_routes": {
        "hub_id": 611,
        "code": "aaatD6D1atta1611at1t6a1b6at1b11a",
        "title": "버스 노선 기본 정보",
        "source": "D6",
        "params": ["startStationId"],
        "required": [],
        "date_param": None,
        "fields": ["routeId", "routeName", "routeNumber", "startStationId", "endStationId", "startStationName",
                   "endStationName", "stationCount", "routeLength"],
        "freshness": "기준 정보 (매일 갱신)",
    },
    "bus_usage": {
        "hub_id": 613,
        "code": "1b1ta1a1ba6t6a1ttt3bD6b1tb1t1D3t",
        "title": "일일 정류소별 버스 이용자 정보",
        "source": "D6",
        "params": ["startDate", "endDate", "moveType", "priceType", "payType"],
        "required": ["startDate", "endDate"],
        "date_param": "startDate",
        "date_format": "%Y%m%d",
        "fields": ["baseDate", "stationId", "stationName", "moveType", "priceType", "payType", "userCount"],
        "freshness": "일 단위, 약 2~3개월 지연 · 하루 4~6천 건(40~60회 호출)",
    },
    "wifi_usage": {
        "hub_id": 593,
        "code": "1aa9D5DabtDt1at935b1tt5t1D95t5at",
        "title": "와이파이 AP그룹별 일일 사용량",
        "source": "D3",
        "params": ["searchDate"],
        "required": ["searchDate"],
        "date_param": "searchDate",
        "date_format": "%Y%m%d",
        "fields": ["apGroupName", "baseDate", "uploadBytes", "downloadBytes", "sessionTime", "userCount"],
        "freshness": "일 단위, 약 2~3개월 지연",
    },
    "wifi_users": {
        "hub_id": 586,
        "code": "tDtb1taa8aat816att6at6tba1aDtbba",
        "title": "와이파이 일일 사용자수",
        "source": "D3",
        "params": ["searchDate"],
        "required": ["searchDate"],
        "date_param": "searchDate",
        "date_format": "%Y%m%d",
        "fields": ["baseDate", "userCount"],
        "freshness": "일 단위, 약 2~3개월 지연",
    },
}

# 서비스 지역(tourist_data.REGIONS) → 유동인구 데이터의 읍면동 이름
# (추자면은 서비스 지역에 없어 제외)
REGION_EMD: dict[str, list[str]] = {
    "jeju-city": ["건입동", "노형동", "도두동", "봉개동", "삼도1동", "삼도2동", "삼양동", "아라동", "연동", "오라동",
                  "외도동", "용담1동", "용담2동", "이도1동", "이도2동", "이호동", "일도1동", "일도2동", "화북동"],
    "aewol": ["애월읍"],
    "hallim": ["한림읍", "한경면"],
    "daejeong": ["대정읍", "안덕면"],
    "jungmun": ["중문동", "예래동", "대천동"],
    "seogwipo": ["대륜동", "동홍동", "서홍동", "송산동", "영천동", "정방동", "중앙동", "천지동", "효돈동"],
    "namwon": ["남원읍", "표선면"],
    "seongsan": ["성산읍"],
    "gujwa": ["구좌읍", "우도면"],
    "jocheon": ["조천읍"],
}
EMD_REGION: dict[str, str] = {emd: rid for rid, emds in REGION_EMD.items() for emd in emds}
