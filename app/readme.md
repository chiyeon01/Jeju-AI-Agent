# app (Flutter) · 제주잇다

제주 AI·빅데이터 활용 AI Agent 서비스의 모바일 앱입니다. 이 `app/` 폴더 자체가 하나의 Flutter 프로젝트 루트입니다.
`frontend/`(React)와 **같은 화면·기능·디자인**을 Flutter로 옮겼고, 지금은 목업 데이터로 동작합니다.

## 화면

| 메뉴 | 대상 | 내용 |
| --- | --- | --- |
| 홈 | 공통 | 역할 선택, 지역 점수 지도, 데이터 순환 구조 |
| 여행 코스 | 관광객 | 성향 테스트(12문항·4축·16유형) → 위치 선택(지도/현재 위치) → AI 코스(시간표·데이터 근거·날씨 전환·대화 수정) → 방문 후 평가 |
| 사장님 | 상권 주인 | 상권 건강 점수 게이지, 주간 추이, AI 개선 제안, 세부 지표 6종, 리뷰 인사이트, 성향 적합도, AI 질문, 개선 조치 등록 |
| Main PC | 제주시 | 통합 현황(실시간 이벤트·지역 점수 지도·인기 코스), 데이터 관리, 접근·보안, 백업·복구 |

화면 폭이 720 이하이면 하단 탭, 넓으면 상단 메뉴가 나옵니다. 오른쪽 위 ☾/☀ 버튼으로 밝은/어두운 화면을 바꾸고, 선택은 기기에 저장됩니다.
안드로이드 뒤로 가기 버튼은 홈으로 돌아갑니다.

## 목업 / 백엔드 전환

화면은 `lib/api/client.dart` 의 함수만 부릅니다 (React 의 `src/api/client.js` 와 같은 구조).
기본은 목업이고, FastAPI 백엔드를 붙일 때는 실행 설정에 아래를 넣습니다.
Android Studio: Run > Edit Configurations > Additional run args

```
--dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

에뮬레이터에서 PC 의 `localhost` 는 `10.0.2.2` 입니다. 엔드포인트는 `frontend/README.md` 와 같습니다.

- 패키지 이름: `jeju_ai_agent`
- Android applicationId: `com.jejuagent.jeju_ai_agent`
- 플랫폼: Android, iOS
- 생성 시 Flutter 버전: 3.50.0 (stable)

## Android Studio에서 열기

1. Android Studio에 **Flutter** 플러그인과 **Dart** 플러그인을 설치합니다. (Settings > Plugins)
2. `File > Open` 에서 저장소 안의 **`Jeju-AI-Agent/app` 폴더**를 선택합니다. (저장소 루트가 아니라 `app` 폴더)
3. Flutter SDK 경로를 지정합니다. `Settings > Languages & Frameworks > Flutter > Flutter SDK path` 에 본인 PC의 Flutter SDK 폴더(예: `C:\src\flutter`)를 넣습니다.
4. 터미널에서 `flutter pub get` 을 실행하거나, `pubspec.yaml` 을 열었을 때 나오는 **Pub get** 을 누릅니다.
5. 에뮬레이터 또는 실기기를 선택하고 ▶ Run 으로 `lib/main.dart` 를 실행합니다.

## Git에 올라가지 않는 파일

아래 파일은 PC마다 경로가 달라 `.gitignore` 로 제외되어 있으며, 처음 열거나 빌드할 때 자동으로 생성됩니다.

- `android/local.properties` (Flutter SDK, Android SDK 경로)
- `.idea/`, `*.iml` (Android Studio 설정)
- `.dart_tool/`, `build/`
- `ios/Flutter/Generated.xcconfig`, `ios/Flutter/flutter_export_environment.sh`

## 폴더 구조

```
app/
├─ lib/
│  ├─ main.dart            # 시작점, 테마 전환
│  ├─ shell.dart           # 상단 바 · 하단 탭 · 화면 이동
│  ├─ theme.dart           # 색·글꼴 토큰 (styles.css 의 :root 변수와 같은 값)
│  ├─ api/client.dart      # 백엔드 호출 함수 (USE_MOCK=true 면 목업 응답)
│  ├─ data/                # 관광객·상권·콘솔 목업 데이터, 제주 지도 경계
│  ├─ widgets/             # 공통 UI, 차트(스파크라인·게이지·선 그래프·별점), 제주 지도
│  └─ pages/               # home, tourist/, owner/, console/
├─ assets/
│  ├─ data/jeju_geo.json   # 읍면동 경계 (frontend/src/mock/jejuGeo.js 와 같은 데이터)
│  └─ fonts/               # Pretendard, Do Hyeon, IBM Plex Mono (모두 SIL OFL)
├─ test/           # 위젯 테스트
├─ android/        # Android 네이티브 프로젝트
├─ ios/            # iOS 네이티브 프로젝트
├─ pubspec.yaml    # 패키지 의존성
└─ analysis_options.yaml
```
