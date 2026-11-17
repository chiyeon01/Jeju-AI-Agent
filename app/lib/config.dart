// ─────────────────────────────────────────────
// 환경 변수 모음. 값은 app/env.json 에 넣고 실행할 때 넘깁니다 (env.example.json 참고).
//   flutter run --dart-define-from-file=env.json
// Android Studio: Run > Edit Configurations > Additional run args 에 위 옵션을 넣습니다.
// 여기 말고 다른 파일에서 fromEnvironment 를 직접 읽지 마세요.
// ─────────────────────────────────────────────

class AppConfig {
  /// true(기본): 목업 데이터로 동작, false: 실제 백엔드 호출
  static const bool useMock = String.fromEnvironment('USE_MOCK', defaultValue: 'true') != 'false';

  /// 백엔드 주소. 기본은 배포 서버. 내 PC 백엔드는 에뮬레이터 기준 http://10.0.2.2:8000/api/v1
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://jejuai.duckdns.org/api/v1');

  /// 카카오맵 JavaScript 키 (앱 안 WebView 로 지도를 그립니다)
  static const String kakaoJsKey = String.fromEnvironment('KAKAO_JS_KEY');

  /// 관리 화면 실시간 이벤트 WebSocket. 기본은 배포 서버. 내 PC 백엔드는 ws://10.0.2.2:8000/ws/events
  static const String eventStreamUrl = String.fromEnvironment('EVENT_STREAM_URL', defaultValue: 'wss://jejuai.duckdns.org/ws/events');

  /// 기상청 초단기실황 서비스키 (공공데이터포털). 비우면 키 없는 Open-Meteo 로 실시간 날씨를 가져옵니다
  static const String kmaServiceKey = String.fromEnvironment('KMA_SERVICE_KEY');

  /// 백엔드에 GPT 중계 API(/tourist/ai/json)가 있을 때만 "true".
  /// 지금 백엔드에는 없으므로 기본 false: 처음 코스는 /tourist/course(허브 혼잡도 반영),
  /// 대화 수정은 /tourist/course/chat(백엔드 GPT)이 맡습니다.
  static const bool gptRelay = String.fromEnvironment('GPT_RELAY') == 'true';
}
