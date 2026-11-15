# 제주잇다 백엔드 (FastAPI)

프론트엔드(`frontend/src/api/client.js`)가 호출하는 API를 제공합니다.
AI 응답(성향 설명, 코스 대화 수정, 상권 Agent 질의)은 **GPT(OpenAI) API**를 쓰고,
키가 없을 때는 자동으로 규칙 기반 응답으로 동작해 서버가 항상 켜져 있습니다.

## 1. 준비물

- Python 3.11 이상
- OpenAI API 키 (https://platform.openai.com/api-keys)

## 2. 실행 (VS Code 터미널)

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate        # Windows PowerShell:  .venv\Scripts\Activate.ps1  /  macOS·Linux: source .venv/bin/activate
pip install -r requirements.txt
copy .env.example .env         # macOS·Linux: cp .env.example .env
```

`.env` 를 열어 `OPENAI_API_KEY=`, `KAKAO_REST_API_KEY=` 뒤에 키를 붙여넣으세요. **이 파일만 채우면 됩니다.**
다른 설정(모델명, CORS 주소 등)은 기본값 그대로 두면 됩니다.

```bash
uvicorn app.main:app --reload --port 8000
```

- API 문서(Swagger): http://localhost:8000/docs
- 헬스체크: http://localhost:8000/api/health → `{"ok": true, "gpt_enabled": true/false, ...}`

## 3. 프론트엔드와 연결

`frontend/.env` 에서 `VITE_USE_MOCK=false` 로 바꾸면, vite dev 서버가 `/api` 요청을
자동으로 `http://localhost:8000` 으로 넘깁니다 (frontend/vite.config.js 의 proxy 설정).
추가로 바꿀 프론트 코드는 없습니다.

## 4. 제공 엔드포인트 (모두 `/api` 하위)

| 메서드 | 경로 | 설명 |
|---|---|---|
| POST | `/tourist/profile` | 성향 테스트 응답 → 4축 점수·16유형 (성향 분석 Agent) |
| POST | `/tourist/course` | 성향·위치·날씨 → 시간표가 있는 추천 코스 (코스 플래너 Agent) |
| POST | `/tourist/course/chat` | 자연어로 코스 수정 (GPT 의도 분류 + 패치) |
| POST | `/tourist/reviews` | 방문 후 평가 저장 → 상권 지표(고객 만족 지수) 실시간 반영 |
| POST | `/owner/ask` | 상권 분석 Agent 질의 (매장 지표·리뷰 근거로 GPT가 답변) |
| POST | `/owner/actions` | 사장님 개선 조치 등록 |
| GET | `/map/regions` | 서비스 지역 10곳 중심 좌표 (지도 지역 마커용) |
| GET | `/map/places?region=&kind=` | 추천 후보 장소 좌표 (지도 마커용) |
| POST | `/map/geocode` | 주소 → 좌표 (카카오 주소 검색) |
| POST | `/map/search` | 키워드 장소 검색 (카카오 키워드 검색, lat/lon 주면 가까운 순) |
| POST | `/map/reverse-geocode` | 현재 위치 좌표 → 가장 가까운 서비스 지역 (+카카오 행정동 주소) |
| GET | `/health` | 서버·GPT·카카오맵 연동 상태 확인 |

### 카카오맵 키 2종

| 키 | 넣는 곳 | 용도 |
|---|---|---|
| **REST API 키** | `backend/.env` 의 `KAKAO_REST_API_KEY` | 주소·키워드 검색, 좌표→행정동 (서버에서만 호출, 비밀 유지) |
| **JavaScript 키** | `frontend/.env` 의 `VITE_MAP_JS_KEY` | 브라우저에서 카카오맵 SDK로 실제 지도 그리기 |

둘 다 [카카오 개발자 콘솔](https://developers.kakao.com/console/app) → 내 애플리케이션 → 앱 키에서 확인합니다.
JavaScript 키는 앱 설정 → 플랫폼 → Web에 `http://localhost:5173` 도메인을 등록해야 지도가 뜹니다.
REST 키가 없으면 `/map/geocode`·`/map/search` 는 빈 목록(`source: "none"`)을, `/map/reverse-geocode` 는
보유 좌표로 계산한 최근접 지역(`source: "local"`)을 돌려줍니다.

## 5. 폴더 구조

```
backend/
  .env.example          .env 로 복사해 키만 채우는 템플릿 (OPENAI_API_KEY 등)
  app/
    main.py             FastAPI 앱, CORS, 라우터 등록
    config.py           .env 로딩 (pydantic-settings)
    schemas.py          요청/응답 모델 (client.js와 1:1)
    db.py               SQLite 저장 (평가, 사장님 조치) — 설치 없이 바로 동작
    data/               장소·매장 마스터 데이터 (지금은 시연용 합성 데이터)
      tourist_data.py     장소(PLACES)·지역(REGIONS)·성향 유형표
      owner_data.py       매장 지표(INDICATORS)·리뷰·주간 리포트
    services/
      llm_service.py      OpenAI(GPT) 호출 래퍼 (키 없으면 자동 비활성화)
      profile_service.py  성향 분석 Agent
      course_service.py   코스 플래너 Agent (장소 점수화 + 이동시간)
      chat_service.py      코스 대화 수정 (GPT JSON 모드 + 규칙 기반 대체)
      owner_service.py     상권 분석 Agent (지표·리뷰를 근거로 GPT 답변)
      review_service.py    평가 저장 + 고객 만족 지수 재계산
      kakao_service.py     카카오 Local REST API 호출 래퍼
      map_service.py       지도 도구 (카카오 + 로컬 최근접 지역 대체)
      geo.py                위경도 거리·이동시간 계산
    routers/
      tourist.py / owner.py / map.py   엔드포인트 정의
  storage/               SQLite 파일 저장 위치 (.env 의 DATABASE_PATH)
```

## 6. 실데이터(제주데이터허브) 연동 시

지금은 `app/data/*.py` 에 시연용 합성 데이터가 들어 있습니다. 실제 데이터로 바꿀 때는:

1. `.env` 의 `JEJU_DATA_HUB_API_KEY` / `JEJU_DATA_HUB_BASE_URL` 을 채웁니다.
2. `app/data/tourist_data.py` 의 `PLACES`/`REGIONS`, `app/data/owner_data.py` 의
   `STORE`/`INDICATORS` 를 실제 DB 조회 함수로 바꿉니다. 위 모듈을 가져다 쓰는
   `services/*.py` 는 함수 시그니처가 같으면 수정할 필요가 없습니다.
3. 숫자 계산(지표, 장소 점수)은 그대로 Python/SQL로 두고, GPT는 설명·대화 생성에만
   쓰는 원칙(기획/서비스_기획서_초안.md 5.4절)을 유지하세요.

## 7. 주의

- `backend/.env` 는 git에 커밋되지 않습니다 (`.gitignore`). API 키는 이 파일에만 넣으세요.
- `OPENAI_API_KEY` 가 비어 있어도 서버는 정상 동작합니다 (규칙 기반 응답으로 대체).
- 센터 PC에서 실데이터로 작업할 때는 기획서의 "원천 데이터는 PC 밖으로 나가지 않음"
  원칙에 따라 GPT에는 집계·요약된 값만 보내고 있는지 `services/owner_service.py`,
  `services/profile_service.py` 의 프롬프트 구성 부분을 리뷰하세요.
