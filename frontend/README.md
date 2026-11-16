# frontend (React) · 제주잇다

제주 AI·빅데이터 활용 AI Agent 서비스의 웹 화면입니다. React 18 + Vite 5 로 만들었고, 지금은 목업 데이터로 동작합니다.

## 실행 (VS Code)

```bash
cd frontend
npm install
copy .env.example .env      # macOS/Linux: cp .env.example .env
npm run dev                 # http://localhost:5173
```

목업 모드에서는 로그인 화면의 시연 계정 버튼으로 바로 들어갈 수 있습니다. (비밀번호 `jeju1234`)

| 계정 | 역할 | 보이는 화면 |
| --- | --- | --- |
| user@jeju.kr | 관광객 (USER) | 여행 코스: 성향 테스트 → 출발 지역 → AI 코스 → 방문 평가 |
| owner@jeju.kr | 상권 주인 (MERCHANT) | 내 가게: 건강 점수, 주간 추이, AI 제안, 지표, 리뷰, AI 질문, 메뉴·이벤트 등록 |
| admin@jeju.kr | 관리자 (ADMIN) | 모든 화면 + 통합 관리(현황, 데이터, 계정·보안, 백업) |

회원가입은 관광객과 상권 주인만 할 수 있고, 상권 주인은 관리자가 승인해야 로그인됩니다. 관리자 계정은 백엔드에서 만듭니다.

## 환경 변수 (`frontend/.env`)

| 변수 | 넣을 값 |
| --- | --- |
| `VITE_USE_MOCK` | `true` 목업, `false` 실제 백엔드 |
| `VITE_API_BASE_URL` | 백엔드 주소. 기본 `/api/v1` (vite 프록시가 `localhost:8000` 으로 넘김) |
| `VITE_KAKAO_MAP_KEY` | 카카오 developers 의 **JavaScript 키**. 플랫폼 > Web 에 `http://localhost:5173` 등록, 카카오맵 활성화 |
| `VITE_EVENT_STREAM_URL` | 관리 콘솔 실시간 이벤트 WebSocket. 예: `ws://localhost:8000/ws/events` |

`.env` 는 Git 에 올라가지 않습니다. 키가 비어 있으면 지도 자리에 안내 문구가 나옵니다.
Claude API 키, 데이터허브 키, JWT 비밀키는 브라우저에 노출되므로 여기 넣지 말고 백엔드에 둡니다.

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
