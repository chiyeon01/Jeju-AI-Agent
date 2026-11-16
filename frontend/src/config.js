// ─────────────────────────────────────────────
// 환경 변수 모음. 값은 frontend/.env 에 넣습니다 (.env.example 참고).
// 여기 말고 다른 파일에서 import.meta.env 를 직접 읽지 마세요.
// ─────────────────────────────────────────────
const env = import.meta.env;

export const config = {
  /** true(기본): 목업 데이터로 동작, false: 실제 백엔드 호출 */
  useMock: (env.VITE_USE_MOCK ?? 'true') !== 'false',
  /** 백엔드 주소. 개발 중에는 vite 프록시가 /api → localhost:8000 으로 넘깁니다 */
  apiBaseUrl: env.VITE_API_BASE_URL || '/api/v1',
  /** 카카오맵 JavaScript 키 (developers.kakao.com > 내 애플리케이션 > 앱 키 > JavaScript 키) */
  kakaoMapKey: env.VITE_KAKAO_MAP_KEY || '',
  /** Main PC 콘솔 실시간 이벤트 (WebSocket) */
  eventStreamUrl: env.VITE_EVENT_STREAM_URL || '',
};
