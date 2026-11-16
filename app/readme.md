# app (Flutter) · 제주잇다

제주 AI·빅데이터 활용 AI Agent 서비스의 모바일 앱입니다. 이 `app/` 폴더 자체가 하나의 Flutter 프로젝트 루트입니다.
`frontend/`(React)와 같은 화면·기능·디자인이고, 지금은 목업 데이터로 동작합니다.

## 로그인과 화면

목업 모드에서는 로그인 화면의 시연 계정 버튼으로 바로 들어갈 수 있습니다. (비밀번호 `jeju1234`)

| 계정 | 역할 | 보이는 화면 |
| --- | --- | --- |
| user@jeju.kr | 관광객 (USER) | 여행 코스: 성향 테스트 → 출발 지역 → AI 코스 → 방문 평가 |
| owner@jeju.kr | 상권 주인 (MERCHANT) | 내 가게: 건강 점수, 주간 추이, AI 제안, 지표, 리뷰, AI 질문, 메뉴·이벤트 등록 |
| admin@jeju.kr | 관리자 (ADMIN) | 모든 화면 + 관리(현황, 데이터, 계정·보안, 백업) |

회원가입은 관광객과 상권 주인만 할 수 있고, 상권 주인은 관리자가 승인해야 로그인됩니다.
화면 폭이 720 이하이면 하단 탭, 넓으면 상단 메뉴가 나옵니다. 안드로이드 뒤로 가기는 첫 화면으로 돌아갑니다.

## 환경 변수 (`app/env.json`)

1. `env.example.json` 을 복사해 `env.json` 을 만들고 값을 채웁니다. (`env.json` 은 Git 에 올라가지 않습니다)
2. Android Studio: Run > Edit Configurations > **Additional run args** 에 `--dart-define-from-file=env.json`
   터미널: `flutter run --dart-define-from-file=env.json`

| 변수 | 넣을 값 |
| --- | --- |
| `USE_MOCK` | `"true"` 목업, `"false"` 실제 백엔드 |
| `API_BASE_URL` | 백엔드 주소. 에뮬레이터에서 PC 의 localhost 는 `http://10.0.2.2:8000/api/v1` |
| `KAKAO_JS_KEY` | 카카오 developers 의 **JavaScript 키**. 플랫폼 > Web 사이트 도메인에 `http://localhost` 등록, 카카오맵 활성화 |
| `EVENT_STREAM_URL` | 관리 화면 실시간 이벤트 WebSocket. 예: `ws://10.0.2.2:8000/ws/events` |

지도는 앱 안 WebView 에서 카카오맵 JavaScript SDK 로 그립니다. 키가 비어 있으면 지도 자리에 안내 문구가 나옵니다.
값은 `lib/config.dart` 에서만 읽습니다. Claude API 키, 데이터허브 키, JWT 비밀키는 앱에 넣지 말고 백엔드에 둡니다.

## 백엔드 연동

화면은 `lib/api/client.dart` 의 함수만 부릅니다 (React 의 `src/api/client.js` 와 같은 구조). `USE_MOCK` 을 `"false"` 로 바꾸면 같은 함수가 백엔드를 호출합니다.
로그인 토큰은 기기에 저장하고 모든 요청에 `Authorization: Bearer` 를 붙이며, 401 이 오면 `/auth/refresh` 로 한 번 갱신합니다.
엔드포인트와 응답 형식은 「제주잇다 BE 연동 명세」 PDF 와 같습니다.

- 패키지 이름: `jeju_ai_agent`
- Android applicationId: `com.jejuagent.jeju_ai_agent`
- 플랫폼: Android, iOS
- 생성 시 Flutter 버전: 3.50.0 (stable)

## Android Studio에서 열기

1. Android Studio에 **Flutter** 플러그인과 **Dart** 플러그인을 설치합니다. (Settings > Plugins)
2. `File > Open` 에서 저장소 안의 **`Jeju-AI-Agent/app` 폴더**를 선택합니다. (저장소 루트가 아니라 `app` 폴더)
3. `Settings > Languages & Frameworks > Flutter > Flutter SDK path` 에 본인 PC의 Flutter SDK 폴더(예: `C:\src\flutter`)를 넣습니다.
4. 터미널에서 `flutter pub get` 을 실행하거나, `pubspec.yaml` 을 열었을 때 나오는 **Pub get** 을 누릅니다.
5. 위 환경 변수 설정을 한 뒤 에뮬레이터 또는 실기기를 선택하고 ▶ Run 으로 `lib/main.dart` 를 실행합니다.

## Git에 올라가지 않는 파일

아래 파일은 PC마다 다르거나 개인 키가 들어가 `.gitignore` 로 제외되어 있습니다.

- `env.json` (카카오 키 등 실행 설정)
- `android/local.properties` (Flutter SDK, Android SDK 경로)
- `.idea/`, `*.iml` (Android Studio 설정)
- `.dart_tool/`, `build/`
- `ios/Flutter/Generated.xcconfig`, `ios/Flutter/flutter_export_environment.sh`

## 폴더 구조

```
app/
├─ lib/
│  ├─ main.dart            # 시작점, 로그인 상태
│  ├─ config.dart          # 환경 변수 (env.json)
│  ├─ shell.dart           # 상단 바 · 하단 탭 · 역할별 메뉴
│  ├─ theme.dart           # 색 (#87CEEB · #87DBEB · #E4FBFF)
│  ├─ api/client.dart      # 백엔드 호출 함수 (목업/실서버 전환, 토큰)
│  ├─ data/                # 목업 데이터 (auth, tourist, owner, console)
│  ├─ widgets/             # 공통 UI, 차트, 카카오맵
│  └─ pages/               # login, tourist/, owner/, console/
├─ assets/fonts/           # Pretendard (SIL OFL)
├─ env.example.json        # 환경 변수 예시
├─ test/                   # 위젯 테스트
├─ android/ · ios/         # 네이티브 프로젝트
└─ pubspec.yaml
```
