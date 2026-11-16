// ─────────────────────────────────────────────
// 환경 변수 모음. 값은 app/env.json 에 넣고 실행할 때 넘깁니다 (env.example.json 참고).
//   flutter run --dart-define-from-file=env.json
// Android Studio: Run > Edit Configurations > Additional run args 에 위 옵션을 넣습니다.
// 여기 말고 다른 파일에서 fromEnvironment 를 직접 읽지 마세요.
// ─────────────────────────────────────────────

class AppConfig {
  /// true(기본): 목업 데이터로 동작, false: 실제 백엔드 호출
  static const bool useMock = String.fromEnvironment('USE_MOCK', defaultValue: 'true') != 'false';

  /// 백엔드 주소. Android 에뮬레이터에서 PC 의 localhost 는 10.0.2.2 입니다.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000/api/v1');

  /// 카카오맵 JavaScript 키 (앱 안 WebView 로 지도를 그립니다)
  static const String kakaoJsKey = String.fromEnvironment('KAKAO_JS_KEY');

  /// 관리 콘솔 실시간 이벤트 WebSocket. 예: ws://10.0.2.2:8000/ws/events
  static const String eventStreamUrl = String.fromEnvironment('EVENT_STREAM_URL');
}
