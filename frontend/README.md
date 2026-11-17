# frontend (React) · 제주잇다

제주 AI·빅데이터 활용 AI Agent 서비스의 웹 화면입니다. React 18 + Vite 5 로 만들었고, 지금은 목업 데이터로 동작합니다.

## 실행 (VS Code)

```bash
cd frontend
npm install
copy .env.example .env      # macOS/Linux: cp .env.example .env
npm run dev                 # http://localhost:5173
```

로그인 화면에는 시연 계정 버튼이 없습니다. `회원가입` 으로 계정을 만들면 백엔드(`POST /auth/signup`)에 저장되고, 관광객은 가입 직후 바로 로그인됩니다.
목업 모드(`VITE_USE_MOCK=true`)에서 가입한 계정은 이 브라우저에만 저장됩니다.

회원가입은 관광객과 상권 주인만 할 수 있고, 상권 주인은 관리자가 승인해야 로그인됩니다. 관리자 계정은 백엔드에서 만듭니다.

## 환경 변수 (`frontend/.env`)

| 변수 | 넣을 값 |
| --- | --- |
| `VITE_USE_MOCK` | `true` 목업, `false` 실제 백엔드 |
| `VITE_PROXY_TARGET` | 개발 서버가 `/api`, `/ws` 를 넘길 백엔드. 배포 서버 `https://jejuai.duckdns.org`, 내 PC 백엔드 `http://localhost:8000` (기본) |
| `VITE_API_BASE_URL` | 브라우저가 부르는 API 주소. 기본 `/api/v1` (위 프록시를 거치므로 CORS 설정이 필요 없음) |
| `VITE_KAKAO_MAP_KEY` | 카카오 developers 의 **JavaScript 키**. 플랫폼 > Web 에 `http://localhost:5173` 등록, 카카오맵 활성화 |
| `VITE_KMA_SERVICE_KEY` | 실시간 날씨용 기상청 서비스키 (선택). 비우면 키 없이 Open-Meteo 로 가져옴. 발급 방법은 `.env.example` 참고 |
| `VITE_GPT_RELAY` | 백엔드에 `/tourist/ai/json` 이 있을 때만 `true`. 기본은 비워 둠 |
| `VITE_EVENT_STREAM_URL` | 관리 화면 실시간 이벤트 WebSocket. 기본 `/ws/events` (프록시 경유). 전체 주소 `wss://jejuai.duckdns.org/ws/events` 도 가능 |

**코스와 GPT**: 웹은 GPT 키를 갖지 않습니다.
- 처음 코스는 백엔드 `POST /tourist/course` 가 짭니다. 백엔드가 제주데이터허브 지역 혼잡도(D2)를 점수에 반영합니다.
- 대화로 고치기는 백엔드 `POST /tourist/course/chat` 이 백엔드 GPT 로 답합니다 ("저녁은 해산물로", "1곳 줄여줘", "실내로").
- 백엔드 대화 API 는 위 세 가지만 바꿀 수 있어서, "코스를 더 늘려줘", "카페 하나 추가해줘" 같은 요청은 화면이 직접 장소를 골라 넣습니다 (`src/api/courseEdit.js`, 최대 7곳). 시간 흐름(낮 → 노을 → 저녁)에 맞는 자리에 넣고, 백엔드가 코스를 다시 짜도 추가한 장소는 유지됩니다.
- 코스 화면은 백엔드 `GET /datahub/crowd`, `GET /datahub/sights` 로 허브 혼잡도·관광지 방문객을 받아 각 장소 근거에 보여 줍니다. 허브 원본과 키는 백엔드(Main PC)에만 있습니다.
- `src/prompts/`, `src/api/planner.js` 는 백엔드에 GPT 중계 API(`/tourist/ai/json`)가 생겼을 때만 쓰는 GPT 플래너입니다. `VITE_GPT_RELAY=true` 일 때만 켜지고, 그때도 허브 값은 숫자 없이 등급만 GPT 에 보냅니다.

**관광객 홈 (내 기록)**: 관광객이 로그인하면 `/tourist` 에서 지금까지의 기록(내 여행 유형, 만든 코스, 보낸 평가, 평균 별점)을 먼저 봅니다. `지난 성향으로 코스 만들기` 는 성향 테스트를 건너뛰고 출발 지역부터, `성향 테스트부터 새로 시작` 은 `/tourist/new` 에서 처음부터 시작합니다. 백엔드는 성향 결과와 코스를 저장하지 않아서 기록은 이 브라우저에 계정별로 저장됩니다 (`src/api/history.js`).

**내 정보·설정**: 상단의 이름을 누르면 `/me` 가 열립니다. 서버(`/auth/me`)의 내 정보, 화면 밝기(40~100%, `src/settings.js`), 기록 지우기, 로그아웃이 있습니다.

**뒤로가기**: 모든 화면 왼쪽 위에 있습니다. 여행 코스 화면에서는 이전 단계(성향 테스트는 이전 문항)로, 그 밖에는 이전 페이지로 갑니다.

**현재 위치와 실시간 날씨**: 출발 지역 화면의 `현재 위치 사용` 은 브라우저 위치 권한으로 가장 가까운 지역을 고릅니다 (제주 밖이거나 권한이 없으면 애월읍). 코스 화면은 그 좌표의 실시간 날씨를 가져와 보여 주고(맑음/비를 직접 고르는 버튼은 없음), 비나 눈이 오면 실내 코스로 시작합니다. 날씨를 못 가져오면 `다시 불러오기` 버튼이 나옵니다. 날씨 코드는 `src/api/weather.js` 에 있습니다.
기상청 API 는 브라우저에서 직접 부를 수 없어(CORS) 개발 서버 프록시(`/kma`)를 거칩니다. 빌드해서 따로 배포할 때는 프록시가 없으므로 Open-Meteo 로 자동 전환되며, 

배포 서버에 바로 붙이려면 `.env.example` 을 그대로 복사해 카카오 키만 넣고 `npm run dev` 하면 됩니다.
빌드 결과물(`npm run build`)을 다른 도메인에 올릴 때는 `VITE_API_BASE_URL` 에 `https://jejuai.duckdns.org/api/v1` 처럼 전체 주소를 넣고 그 도메인이 백엔드 `CORS_ORIGINS` 에 들어 있어야 합니다.

`.env` 는 Git 에 올라가지 않습니다. 키가 비어 있으면 지도 자리에 안내 문구가 나옵니다.
OpenAI API 키, 데이터허브 키, JWT 비밀키는 브라우저에 노출되므로 여기 넣지 말고 백엔드에 둡니다.

## 백엔드 연동

화면은 `src/api/client.js` 의 함수만 부릅니다. `VITE_USE_MOCK=false` 로 바꾸면 같은 함수가 백엔드를 호출합니다.
엔드포인트, 요청·응답 형식, 인증 방식은 「제주잇다 BE 연동 명세」 PDF 에 정리돼 있습니다.

- 로그인하면 `accessToken` / `refreshToken` 을 브라우저에 저장하고, 모든 요청에 `Authorization: Bearer` 를 붙입니다.
- 401 이 오면 `/auth/refresh` 로 한 번 갱신하고, 실패하면 로그인 화면으로 돌아갑니다.

## 폴더 구조

```
src/
├─ config.js              # 환경 변수는 여기서만 읽음
├─ api/client.js          # 백엔드 호출 함수 (목업/실서버 전환)
├─ auth/AuthContext.jsx   # 로그인 상태, 역할별 접근 제한
├─ components/            # Shell(상단 바), KakaoMap, Charts
├─ mock/                  # 목업 데이터 (auth, tourist, owner, console)
├─ pages/                 # Login, Signup, tourist/, owner/, console/
└─ styles.css             # 색: #87CEEB · #87DBEB · #E4FBFF
```
