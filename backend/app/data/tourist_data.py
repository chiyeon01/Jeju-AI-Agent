# ─────────────────────────────────────────────
# 관광객 Agent용 장소·지역 마스터 데이터
#
# 장소는 실제로 있는 제주 장소입니다 (frontend/src/mock/tourist.js, app 의 tourist_mock.dart 와 같은 목록). 실데이터 연동 시에는 이 파일의 REGIONS/PLACES를
# 제주데이터허브 D4(관광지 유입자)·D5(상가 정보)·D8(VISIT JEJU 장소) 등으로
# 적재한 DB 조회 결과로 바꾸면 됩니다 (조회 함수의 시그니처는 그대로 유지).
# ─────────────────────────────────────────────
from __future__ import annotations

# 4개 축: 활동성(A 액티비티 ↔ H 힐링), 공간(N 자연·바다 ↔ C 도심·핫플),
#         취향(F 미식 ↔ P 풍경·사진), 스타일(J 계획형 ↔ S 즉흥형)
AXES = [
    {"key": "act", "left": "액티비티", "right": "힐링", "lc": "A", "rc": "H"},
    {"key": "space", "left": "자연·바다", "right": "도심·핫플", "lc": "N", "rc": "C"},
    {"key": "taste", "left": "미식 중심", "right": "풍경·사진", "lc": "F", "rc": "P"},
    {"key": "style", "left": "계획형", "right": "즉흥형", "lc": "J", "rc": "S"},
]

# 문항 순서 i(0-base) → 해당 문항이 속한 축. 프론트 QUESTIONS 순서와 동일해야 합니다.
QUESTION_AXES = ["act", "space", "taste", "style"] * 3

ADJ = {
    "N-P": "노을 감성",
    "N-F": "해녀밥상",
    "C-P": "골목 사진",
    "C-F": "핫플 미식",
}
NOUN = {
    "A-J": "탐험가",
    "A-S": "모험가",
    "H-J": "산책가",
    "H-S": "여행자",
}
TYPE_DESC = {
    "노을 감성": "바다와 하늘이 바뀌는 순간을 좋아합니다. 해 지는 시간에 맞춰 코스를 짭니다.",
    "해녀밥상": "바다 가까운 곳에서 제철 음식을 먹는 것이 여행의 이유입니다.",
    "골목 사진": "오래된 돌담길과 작은 가게 사이에서 장면을 찾습니다.",
    "핫플 미식": "요즘 뜨는 식당과 카페를 먼저 알아보고 찾아갑니다.",
}

COMPANIONS = ["연인", "친구", "가족", "혼자"]
TRANSPORTS = ["렌터카", "대중교통"]
BUDGETS = ["5만원 이하", "5~10만원", "10~20만원", "20만원 이상"]


def _ll(region_id: str, name: str, lat: float, lon: float) -> dict:
    return {"id": region_id, "name": name, "lat": lat, "lon": lon}


REGIONS = [
    _ll("jeju-city", "제주시 동지역", 33.489, 126.51),
    _ll("aewol", "애월읍", 33.43, 126.37),
    _ll("hallim", "한림·한경", 33.37, 126.23),
    _ll("daejeong", "대정·안덕", 33.25, 126.3),
    _ll("jungmun", "중문", 33.27, 126.43),
    _ll("seogwipo", "서귀포 동지역", 33.285, 126.57),
    _ll("namwon", "남원·표선", 33.32, 126.75),
    _ll("seongsan", "성산", 33.425, 126.88),
    _ll("gujwa", "구좌", 33.495, 126.8),
    _ll("jocheon", "조천", 33.49, 126.67),
]
REGIONS_BY_ID = {r["id"]: r for r in REGIONS}


def _place(
    pid: str,
    name: str,
    region: str,
    kind: str,
    lat: float,
    lon: float,
    indoor: bool,
    rating: float,
    stay: int,
    reasons: list[tuple[str, str]],
    seafood: bool = False,
    addr: str = "",
    label: str | None = None,
    tags: list[str] | None = None,
) -> dict:
    return {
        "id": pid,
        "name": name,
        "region": region,
        "kind": kind,  # cafe | spot | sunset | food | indoor
        "lat": lat,
        "lon": lon,
        "indoor": indoor,
        "rating": rating,
        "stay": stay,
        "seafood": seafood,
        "reasons": [list(r) for r in reasons],
        "addr": addr,  # 읍·면·동 (같은 이름의 다른 가게와 헷갈리지 않게)
        "label": label,  # 화면에 보일 종류 (미술관·기념품샵 등, 없으면 kind 이름)
        "tags": tags or [],  # 대화 요청("미술관 넣어줘")에 맞는 장소를 찾을 때 씁니다
    }


# kind: cafe | spot | sunset | food | indoor
# 실제로 있는 장소만 씁니다. 이름(+읍·면·동)으로 한 곳이 특정됩니다. 위도·경도는 지도 표시용 대략값입니다.
PLACES = [
    _place("p1", "봄날카페", "aewol", "cafe", 33.4627, 126.3097, True, 4.5, 60, [("소개", "한담 해안 바로 앞, 바다가 보이는 카페")], seafood=False, addr="제주시 애월읍 애월리", label=None, tags=["바다뷰", "카페"]),
    _place("p2", "한담해안산책로", "aewol", "spot", 33.4614, 126.3118, False, 4.7, 50, [("소개", "애월 바닷가를 따라 걷는 1.2km 해안 산책로")], seafood=False, addr="제주시 애월읍 애월리", label=None, tags=["산책", "바다"]),
    _place("p3", "곽지해수욕장", "aewol", "sunset", 33.4507, 126.3049, False, 4.6, 45, [("소개", "서쪽 바다로 해가 지는 모래 해변")], seafood=False, addr="제주시 애월읍 곽지리", label=None, tags=["해변", "노을"]),
    _place("p4", "애월연어", "aewol", "food", 33.4645, 126.3192, True, 4.4, 60, [("소개", "연어 덮밥·회를 파는 애월 식당")], seafood=True, addr="제주시 애월읍 애월리", label=None, tags=["연어", "해산물"]),
    _place("p5", "아르떼뮤지엄 제주", "aewol", "indoor", 33.3963, 126.3448, True, 4.6, 80, [("소개", "옛 공장을 고친 몰입형 미디어아트 전시관")], seafood=False, addr="제주시 애월읍 어림비로", label="미디어아트 전시관", tags=["미술관", "전시", "미디어아트"]),
    _place("p6", "협재해수욕장", "hallim", "spot", 33.394, 126.2396, False, 4.8, 60, [("소개", "비양도가 보이는 에메랄드빛 얕은 해변")], seafood=False, addr="제주시 한림읍 협재리", label=None, tags=["해변", "바다"]),
    _place("p7", "앤트러사이트 제주 한림점", "hallim", "cafe", 33.4117, 126.2693, True, 4.4, 50, [("소개", "옛 전분 공장을 고친 커피 로스터리")], seafood=False, addr="제주시 한림읍 한림로", label=None, tags=["카페", "공장 개조"]),
    _place("p8", "수월봉", "hallim", "sunset", 33.2956, 126.1628, False, 4.7, 40, [("소개", "서쪽 끝 해안 절벽, 노을 명소")], seafood=False, addr="제주시 한경면 고산리", label=None, tags=["노을", "지질공원"]),
    _place("p9", "한림칼국수 제주본점", "hallim", "food", 33.4129, 126.2586, True, 4.3, 50, [("소개", "보말칼국수로 알려진 한림 식당")], seafood=True, addr="제주시 한림읍 한림리", label=None, tags=["보말칼국수", "해산물"]),
    _place("p10", "동문재래시장", "jeju-city", "food", 33.5121, 126.5262, True, 4.5, 60, [("소개", "제주 최대 상설시장, 회·먹거리·기념품")], seafood=True, addr="제주시 관덕로14길", label=None, tags=["시장", "회", "기념품"]),
    _place("p11", "카페 델문도", "jocheon", "cafe", 33.5434, 126.6687, True, 4.5, 50, [("소개", "함덕 해변 바로 옆 바다 카페")], seafood=False, addr="제주시 조천읍 함덕리", label=None, tags=["바다뷰", "카페"]),
    _place("p12", "사라봉공원", "jeju-city", "sunset", 33.5176, 126.545, False, 4.5, 40, [("소개", "제주항과 바다 너머 노을을 보는 오름 공원")], seafood=False, addr="제주시 건입동", label=None, tags=["노을", "산책"]),
    _place("p13", "국립제주박물관", "jeju-city", "indoor", 33.5133, 126.5491, True, 4.5, 70, [("소개", "제주 역사·문화를 보여 주는 국립박물관")], seafood=False, addr="제주시 일주동로", label="박물관", tags=["박물관", "전시"]),
    _place("p14", "함덕해수욕장", "jocheon", "spot", 33.5432, 126.6694, False, 4.8, 60, [("소개", "서우봉 옆 얕고 맑은 해변")], seafood=False, addr="제주시 조천읍 함덕리", label=None, tags=["해변", "바다"]),
    _place("p15", "도두해녀의집", "jeju-city", "food", 33.506, 126.466, True, 4.3, 60, [("소개", "해녀가 운영하는 물회 식당")], seafood=True, addr="제주시 도두일동", label=None, tags=["물회", "해산물"]),
    _place("p16", "풍림다방 송당점", "gujwa", "cafe", 33.4708, 126.7822, True, 4.5, 50, [("소개", "송당 마을의 작은 감성 카페")], seafood=False, addr="제주시 구좌읍 송당리", label=None, tags=["카페", "감성"]),
    _place("p17", "월정리해변", "gujwa", "spot", 33.5563, 126.7956, False, 4.6, 50, [("소개", "카페가 늘어선 하얀 모래 해변")], seafood=False, addr="제주시 구좌읍 월정리", label=None, tags=["해변", "카페거리"]),
    _place("p18", "성산일출봉", "seongsan", "spot", 33.4581, 126.9425, False, 4.8, 80, [("소개", "유네스코 세계자연유산 화산 분화구")], seafood=False, addr="서귀포시 성산읍 성산리", label=None, tags=["오름", "유네스코"]),
    _place("p19", "섭지코지", "seongsan", "sunset", 33.4243, 126.9306, False, 4.6, 50, [("소개", "성산일출봉이 보이는 해안 언덕")], seafood=False, addr="서귀포시 성산읍 고성리", label=None, tags=["해안", "풍경"]),
    _place("p20", "맛나식당", "seongsan", "food", 33.4627, 126.9332, True, 4.4, 50, [("소개", "갈치·고등어조림으로 알려진 성산 식당")], seafood=True, addr="서귀포시 성산읍 성산리", label=None, tags=["갈치조림", "해산물"]),
    _place("p21", "중문색달해수욕장", "jungmun", "spot", 33.2445, 126.412, False, 4.6, 60, [("소개", "파도가 좋아 서핑을 많이 하는 해변")], seafood=False, addr="서귀포시 색달동", label=None, tags=["해변", "서핑"]),
    _place("p22", "테디베어뮤지엄 제주", "jungmun", "indoor", 33.2497, 126.4123, True, 4.3, 70, [("소개", "테디베어 전시관, 아이와 가기 좋은 실내")], seafood=False, addr="서귀포시 중문관광로", label="박물관", tags=["박물관", "전시", "아이"]),
    _place("p23", "허니문하우스", "seogwipo", "cafe", 33.2436, 126.5806, True, 4.5, 50, [("소개", "소정방폭포 위 절벽의 바다 카페")], seafood=False, addr="서귀포시 토평동", label=None, tags=["바다뷰", "카페"]),
    _place("p24", "쇠소깍", "seogwipo", "spot", 33.2522, 126.6234, False, 4.6, 50, [("소개", "민물과 바다가 만나는 계곡, 투명카약")], seafood=False, addr="서귀포시 하효동", label=None, tags=["계곡", "카약"]),
    _place("p25", "서귀포매일올레시장", "seogwipo", "food", 33.2497, 126.5636, True, 4.5, 60, [("소개", "서귀포 상설시장, 회·먹거리·기념품")], seafood=True, addr="서귀포시 중앙로62번길", label=None, tags=["시장", "회", "기념품"]),
    _place("p26", "표선해수욕장", "namwon", "sunset", 33.3264, 126.8414, False, 4.5, 40, [("소개", "넓은 백사장이 펼쳐지는 해변")], seafood=False, addr="서귀포시 표선면 표선리", label=None, tags=["해변", "산책"]),
    _place("p27", "큰엉해안경승지", "namwon", "spot", 33.277, 126.711, False, 4.6, 50, [("소개", "한반도 모양 숲길로 알려진 해안 절벽 산책로")], seafood=False, addr="서귀포시 남원읍 남원리", label=None, tags=["해안", "산책"]),
    _place("p28", "부두식당", "daejeong", "food", 33.2172, 126.2507, True, 4.4, 60, [("소개", "모슬포항 방어회 식당 (제철 11~2월)")], seafood=True, addr="서귀포시 대정읍 하모리", label=None, tags=["방어", "해산물"]),
    _place("p29", "송악산", "daejeong", "spot", 33.1997, 126.2895, False, 4.7, 60, [("소개", "마라도·형제섬이 보이는 해안 둘레길")], seafood=False, addr="서귀포시 대정읍 상모리", label=None, tags=["오름", "둘레길"]),
    _place("p30", "오설록 티뮤지엄", "daejeong", "cafe", 33.3059, 126.2895, True, 4.5, 60, [("소개", "녹차밭 옆 차 박물관 겸 카페")], seafood=False, addr="서귀포시 안덕면 서광리", label=None, tags=["녹차", "카페"]),
    _place("p31", "제주도립미술관", "jeju-city", "indoor", 33.4524, 126.489, True, 4.5, 70, [("소개", "제주 작가와 기획전을 볼 수 있는 도립 미술관")], seafood=False, addr="제주시 1100로", label="미술관", tags=["미술관", "전시"]),
    _place("p32", "이중섭미술관", "seogwipo", "indoor", 33.2468, 126.5652, True, 4.4, 50, [("소개", "화가 이중섭이 살던 곳 옆 미술관")], seafood=False, addr="서귀포시 서귀동", label="미술관", tags=["미술관", "전시"]),
    _place("p33", "제주도립 김창열미술관", "hallim", "indoor", 33.336, 126.269, True, 4.5, 60, [("소개", "물방울 작가 김창열의 미술관")], seafood=False, addr="제주시 한경면 저지리", label="미술관", tags=["미술관", "전시"]),
    _place("p34", "본태박물관", "daejeong", "indoor", 33.3008, 126.393, True, 4.5, 70, [("소개", "안도 다다오가 설계한 미술관·박물관")], seafood=False, addr="서귀포시 안덕면 상천리", label="미술관", tags=["미술관", "박물관", "건축"]),
    _place("p35", "아라리오뮤지엄 탑동시네마", "jeju-city", "indoor", 33.5161, 126.5199, True, 4.4, 60, [("소개", "옛 극장을 고친 현대미술관")], seafood=False, addr="제주시 탑동로", label="미술관", tags=["미술관", "전시"]),
    _place("p36", "이니스프리 제주하우스", "daejeong", "indoor", 33.3054, 126.2884, True, 4.3, 30, [("소개", "오설록 옆, 제주 한정 기념품·화장품 가게")], seafood=False, addr="서귀포시 안덕면 서광리", label="기념품샵", tags=["기념품", "소품샵", "쇼핑"]),
    _place("p37", "소심한책방", "gujwa", "indoor", 33.4911, 126.898, True, 4.5, 30, [("소개", "종달리 마을의 작은 책방 겸 소품샵")], seafood=False, addr="제주시 구좌읍 종달리", label="소품샵", tags=["기념품", "소품샵", "책방"]),
]
# 바다가 보이는 장소 (대화로 "바다 보이는 카페로" 같은 요청을 받을 때 사용)
OCEAN_VIEW_IDS = {"p1", "p2", "p3", "p6", "p8", "p11", "p12", "p14", "p15", "p17", "p18", "p19", "p21", "p23", "p24", "p26", "p27", "p29"}
# 아이와 가기 좋은 장소 (대화로 "아기가 놀기 좋은 곳으로" 요청을 받을 때 사용)
KIDS_IDS = {"p2", "p5", "p6", "p9", "p10", "p12", "p13", "p14", "p17", "p20", "p21", "p22", "p25", "p26", "p30", "p31"}
# 분위기 좋은 카페 ("분좋카", "감성 카페")
MOOD_CAFE_IDS = {"p1", "p7", "p11", "p16", "p23"}

for _no, _p in enumerate(PLACES, start=1):
    _p["ocean"] = _p["id"] in OCEAN_VIEW_IDS
    _p["kids"] = _p["id"] in KIDS_IDS
    _p["mood"] = _p["id"] in MOOD_CAFE_IDS
    # 장소 고유 번호 (1부터 차례대로, 중복 없음). DB places 테이블의 no 와 같습니다
    _p["no"] = _no

PLACES_BY_ID = {p["id"]: p for p in PLACES}

KIND_LABEL = {"cafe": "카페", "spot": "산책·관광", "sunset": "노을 명소", "food": "저녁 식사", "indoor": "실내 체험"}

WEATHER = {
    "clear": {"label": "맑음", "temp": 17, "icon": "☀️", "note": "강수 확률 10% · 풍속 3m/s"},
    "rain": {"label": "비", "temp": 14, "icon": "🌧️", "note": "강수 확률 80% · 실내 코스로 전환했어요"},
}
