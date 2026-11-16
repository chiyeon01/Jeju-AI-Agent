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
- 헬스체크: http://localhost:8000/api/v1/health → `{"ok": true, "gpt_enabled": ..., "region_crowd_date": ...}`

### 시연 계정 (처음 실행 때 자동 생성, 비밀번호 `jeju1234`)

| 이메일 | 역할 | 비고 |
|---|---|---|
| `user@jeju.kr` | USER (관광객) | |
| `owner@jeju.kr` | MERCHANT (상권 주인) | 시연 매장 "애월 돌담국수" 연결 |
| `sehwa@jeju.kr` | MERCHANT | 승인 대기(PENDING) — 관리 콘솔에서 승인 시연용 |
| `admin@jeju.kr` | ADMIN (관리자) | |

운영에서는 `.env` 에 `SEED_DEMO_ACCOUNTS=false` 로 두세요.

## 3. 프론트엔드·앱과 연결

- **React** (`frontend/`): `frontend/.env` 에서 `VITE_USE_MOCK=false`. API 주소 `VITE_API_BASE_URL=/api/v1` 은
  vite 프록시가 `http://localhost:8000` 으로 넘깁니다. 관리 콘솔 실시간 피드는 `VITE_EVENT_STREAM_URL=ws://localhost:8000/ws/events`.
- **Flutter** (`app/`): `env.json` 의 `USE_MOCK=false`, `API_BASE_URL=http://10.0.2.2:8000/api/v1`
  (안드로이드 에뮬레이터 기준), `EVENT_STREAM_URL=ws://10.0.2.2:8000/ws/events`.

두 클라이언트 모두 `src/api/client.js` · `lib/api/client.dart` 에 적힌 「제주잇다 BE 연동 명세」와 같은 경로·형식을 씁니다.

## 4. 제공 엔드포인트 (모두 `/api/v1` 하위)

**공통 규칙**
- 인증: `Authorization: Bearer <accessToken>` (30분). 만료되면 `POST /auth/refresh` 로 새 토큰(리프레시 토큰은 매번 교체).
- 오류: `{ "error": { "code": "INVALID_CREDENTIALS", "message": "…" } }` 형식, HTTP 상태코드 함께.
- 권한: 관광객 화면 USER·ADMIN, 사장님 화면 MERCHANT·ADMIN, 관리 콘솔 ADMIN. 지도·데이터허브 조회는 로그인만 하면 됨.

| 메서드 | 경로 | 권한 | 설명 |
|---|---|---|---|
| POST | `/auth/signup` | 누구나 | 회원가입 `{email,password(8자+),name,role:USER\|MERCHANT,storeName?,businessNo?}` → `{user}`. MERCHANT 는 PENDING |
| POST | `/auth/login` | 누구나 | → `{accessToken, refreshToken, user}`. PENDING·SUSPENDED 계정은 403 |
| POST | `/auth/refresh` | 누구나 | `{refreshToken}` → `{accessToken, refreshToken}` |
| POST | `/auth/logout` | 누구나 | `{refreshToken}` 폐기 → 204 |
| GET | `/auth/me` | 로그인 | 내 정보 `{id,email,name,role,status,storeId?}` |
| GET | `/regions` | 로그인 | 출발 지역 10곳 `{id,name,lat,lon}` |
| GET | `/regions/nearest?lat=&lon=` | 로그인 | 현재 위치에서 가장 가까운 지역 (+distanceKm) |
| POST | `/tourist/profile` | USER·ADMIN | 성향 테스트 → 4축 점수·16유형 (성향 분석 Agent) |
| POST | `/tourist/course` | USER·ADMIN | `{profile,regionId,startTime,hours,weather,options:{seafood,removeCount}}` → `{weather:{code,label,temp,icon,note}, stops[]}`. hours 를 넘는 장소는 뺌 |
| POST | `/tourist/course/chat` | USER·ADMIN | 자연어로 코스 수정 → `{reply, patch}` |
| POST | `/tourist/reviews` | USER·ADMIN | 방문 후 평가 → `{accepted, rejected}`. 코스 장소만, 계정당 하루 20건 |
| GET | `/owner/store` · `/owner/score` · `/owner/score/trend?weeks=` | MERCHANT·ADMIN | 매장 정보 · 상권 건강 점수 · 주간 추이 |
| GET | `/owner/indicators` · `/owner/report/weekly` | MERCHANT·ADMIN | 세부 지표 6종 · 주간 AI 개선 제안 |
| GET | `/owner/reviews/topics` · `/owner/reviews?limit=` | MERCHANT·ADMIN | 리뷰 주제별 긍정률 · 최근 리뷰 |
| POST | `/owner/ask` | MERCHANT·ADMIN | 상권 분석 Agent 질의 (지표·리뷰 근거로 GPT 답변) |
| POST | `/owner/actions` | MERCHANT·ADMIN | 개선 조치 등록 → `{id,kind,title,status:"MEASURING",createdAt}` |
| GET | `/admin/overview` · `/admin/regions/health` | ADMIN | 오늘 방문·평가·코스·이벤트/초 · 지역별 점수·방문인구·평가 수 |
| GET | `/admin/sources` · `/admin/derived` · `/admin/quality` | ADMIN | 원천 데이터 적재 이력(허브 API 11종 + data/ 파일) · 생성 데이터 · 품질 점검 |
| GET | `/admin/users` · `/admin/access-logs` · `/admin/masking-rules` | ADMIN | 계정 목록 · 조회·로그인 기록 · 마스킹 규칙 |
| PATCH | `/admin/users/{id}` | ADMIN | `{status?, role?}` — 상권 주인 가입 승인, 정지 |
| GET | `/admin/backups` · `/admin/retention` | ADMIN | SQLite 스냅샷 목록 · 보관 정책 |
| POST | `/admin/backups` | ADMIN | 지금 스냅샷 만들기 (최근 14개 보관) |
| POST | `/admin/backups/{id}/restore` | ADMIN | 복구 요청 — **서로 다른 관리자 2명**이 24시간 안에 요청하면 실제 복구 |
| WS | `/ws/events?token=<관리자 토큰>` | ADMIN | 실시간 이벤트 `{type,text,at}` (코스 선택·평가 등록·매장 등록) |
| GET | `/map/regions` | 로그인 | 서비스 지역 10곳 중심 좌표 (지도 지역 마커용) |
| GET | `/map/places?region=&kind=` | 로그인 | 추천 후보 장소 좌표 (지도 마커용) |
| POST | `/map/geocode` | 로그인 | 주소 → 좌표 (카카오 주소 검색) |
| POST | `/map/search` | 로그인 | 키워드 장소 검색 (카카오 키워드 검색, lat/lon 주면 가까운 순) |
| POST | `/map/reverse-geocode` | 로그인 | 현재 위치 좌표 → 가장 가까운 서비스 지역 (+카카오 행정동 주소) |
| GET | `/datahub/status` | 로그인 | 데이터허브 연동 상태, 오늘 데이터별 호출 수, 데이터 목록 |
| GET | `/datahub/population?date=&emd=` | 로그인 | 내국인 유동인구 — 읍면동별·서비스 지역별 합계 (D2) |
| GET | `/datahub/population/foreign?kind=short\|long` | 로그인 | 외국인 단기/장기체류 유동인구 — 국적별·읍면동별 (D2) |
| GET | `/datahub/crowd?refresh=` | 로그인 | 서비스 지역별 혼잡도 지수 0~1 (코스 플래너가 사용) |
| GET | `/datahub/weather?date=&observatory=` | 로그인 | 관측소별 일별 기상 (D7, 허브 데이터가 오래돼 참고용) |
| GET | `/datahub/sights?start=&end=&name=` | 로그인 | 관광지별 내·외국인 유입자 수, 월 단위 (D4) |
| GET | `/datahub/bus/stations?name=` | 로그인 | 버스 정류소 (D6) |
| GET | `/datahub/bus/routes?startStationId=` | 로그인 | 버스 노선 (D6) |
| GET | `/datahub/bus/usage?date=&top=` | 로그인 | 정류소별 하루 이용자 수 상위 (D6) |
| GET | `/datahub/wifi?date=&name=&top=` | 로그인 | 와이파이 AP그룹별 사용자 수 + 전체 사용자 수 (D3) |
| GET | `/datahub/raw/{dataset}?...` | 로그인 | 허브 원본 그대로 (탐색용) |
| GET | `/health` | 누구나 | 서버·GPT·카카오맵·혼잡도 상태 |

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
    main.py             FastAPI 앱, CORS, /api/v1 라우터·WebSocket 등록
    config.py           .env 로딩 (pydantic-settings)
    errors.py           오류 응답 형식 { error: { code, message } }
    security.py         비밀번호 해시, JWT·리프레시 토큰, 역할 검사, 시연 계정
    events.py           실시간 이벤트 저장 + /ws/events 방송
    schemas.py          요청/응답 모델 (client.js · client.dart 와 1:1)
    db.py               SQLite 저장 (계정, 토큰, 평가, 조치, 이벤트, 접근 기록) — 설치 없이 바로 동작
    data/               장소·매장 마스터 데이터 (지금은 시연용 합성 데이터)
      tourist_data.py     장소(PLACES)·지역(REGIONS)·성향 유형표
      owner_data.py       매장 지표(INDICATORS)·리뷰·주간 리포트
      console_data.py     지역 점수 기준값·마스킹 규칙
    services/
      admin_service.py    관리 콘솔 (집계, 적재 이력, 품질 점검, 계정, 백업·복구)
      llm_service.py      OpenAI(GPT) 호출 래퍼 (키 없으면 자동 비활성화)
      profile_service.py  성향 분석 Agent
      course_service.py   코스 플래너 Agent (장소 점수화 + 이동시간)
      chat_service.py      코스 대화 수정 (GPT JSON 모드 + 규칙 기반 대체)
      owner_service.py     상권 분석 Agent (지표·리뷰를 근거로 GPT 답변)
      review_service.py    평가 저장 + 고객 만족 지수 재계산
      kakao_service.py     카카오 Local REST API 호출 래퍼
      map_service.py       지도 도구 (카카오 + 로컬 최근접 지역 대체)
      datahub_client.py    제주데이터허브 호출 (재시도·페이지·쿼터·디스크 캐시)
      datahub_service.py   허브 데이터 가공 (최신 날짜 찾기, 읍면동·지역 합계, 혼잡도)
      geo.py                위경도 거리·이동시간 계산
    data/datahub_catalog.py  허브 API 11종 코드·요청변수, 서비스 지역 ↔ 읍면동 매핑
    routers/
      auth.py / tourist.py / owner.py / admin.py / map.py / datahub.py   엔드포인트 정의
  storage/               SQLite 파일, backups/, datahub_cache/, .jwt_secret (모두 git 제외)
```

## 6. 제주데이터허브 연동

`.env` 의 `JEJU_DATA_HUB_API_KEY` 에 허브 **프로젝트 키**를 넣으면 켜집니다
(허브 마이페이지 → 프로젝트 관리 → 프로젝트 → 프로젝트키). 데이터는 그 프로젝트에
"프로젝트 담기"가 되어 있어야 호출됩니다. 지금 담긴 API 11종은 `app/data/datahub_catalog.py` 에 있습니다.

**지금 실데이터를 쓰는 곳**
- 관리 콘솔: 원천 데이터 적재 이력(허브 11종의 최신 날짜·받은 시각·건수·오류), 지역별 방문인구
- 코스 플래너의 혼잡도(w4): 최신 날짜 유동인구로 지역 혼잡도 지수를 계산해 점수에서 빼고,
  각 장소의 D2 근거 문장을 실측값("읍면동 방문인구 하루 98,418명 · 제주 평균 대비 -12% …")으로 바꿉니다.
  서버 시작 시 백그라운드에서 계산하며, 실패하면 1분 간격으로 다시 시도하고 그동안 코스는 혼잡도 없이 동작합니다.
- 나머지는 `/api/datahub/*` 로 조회만 가능 (상권 지표 등은 아직 합성 데이터).

**허브 API 특성 (2026-11 실제 호출로 확인)**
- 같은 요청도 500/502가 자주 섞임 → 6회 재시도. 특정 날짜는 계속 실패하기도 해서, 날짜를 비운 요청은 하루씩 앞 날짜로 최대 3번 물러납니다.
- 한 번에 최대 100건 (`limit` 100 초과 시 오류) → `number` 로 페이지를 넘깁니다.
- 데이터마다 하루 1,000회 쿼터 → 950회에서 멈춤. 지난 날짜 결과는 `storage/datahub_cache/` 에 영구 캐시.
- 데이터 시점: 유동인구 약 2~3개월 지연, 와이파이·버스는 거의 최신, 관광지 유입은 2024-12까지,
  기상은 오래된 데이터만 있어 실시간 날씨로는 못 씁니다 (날씨 전환은 여전히 프론트가 보내는 값 사용).
- 처음 조회하는 날짜는 느립니다 (유동인구 하루치 7회, 버스 이용 하루치 40~60회 호출).

숫자 계산(지표, 장소 점수)은 Python으로 하고, GPT는 설명·대화 생성에만 쓰는 원칙
(기획/서비스_기획서_초안.md 5.4절)을 유지하세요.

## 7. 주의

- `backend/.env` 는 git에 커밋되지 않습니다 (`.gitignore`). API 키는 이 파일에만 넣으세요.
- `OPENAI_API_KEY` 가 비어 있거나 틀려도 서버는 정상 동작합니다 (규칙 기반 응답으로 대체).
- 로그인 비밀키(`storage/.jwt_secret`)·백업(`storage/backups/`)·허브 캐시도 git에 올라가지 않습니다.
- 센터 PC에서 실데이터로 작업할 때는 기획서의 "원천 데이터는 PC 밖으로 나가지 않음"
  원칙에 따라 GPT에는 집계·요약된 값만 보내고 있는지 `services/owner_service.py`,
  `services/profile_service.py` 의 프롬프트 구성 부분을 리뷰하세요.
