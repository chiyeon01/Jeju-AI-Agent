// ─────────────────────────────────────────────
// 환경 변수 모음. 값은 frontend/.env 에 넣습니다 (.env.example 참고).
// 여기 말고 다른 파일에서 import.meta.env 를 직접 읽지 마세요.
// ─────────────────────────────────────────────
const env = import.meta.env;

function toWsUrl(url) {
  if (!url || !url.startsWith('/') || typeof window === 'undefined') return url;
  const scheme = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  return `${scheme}//${window.location.host}${url}`;
}

export const config = {
  /** true(기본): 목업 데이터로 동작, false: 실제 백엔드 호출 */
  useMock: (env.VITE_USE_MOCK ?? 'true') !== 'false',
  /** 백엔드 주소. 기본 /api/v1 은 vite 프록시가 VITE_PROXY_TARGET(기본 localhost:8000) 으로 넘깁니다 */
  apiBaseUrl: env.VITE_API_BASE_URL || '/api/v1',
  /** 카카오맵 JavaScript 키 (developers.kakao.com > 내 애플리케이션 > 앱 키 > JavaScript 키) */
  kakaoMapKey: env.VITE_KAKAO_MAP_KEY || env.VITE_MAP_JS_KEY || '', // 백엔드 README 의 VITE_MAP_JS_KEY 이름도 받습니다
  /** Main PC 콘솔 실시간 이벤트 (WebSocket). '/ws/events' 처럼 경로만 넣으면 지금 접속한 주소 기준 ws(s):// 로 바꿉니다 */
  eventStreamUrl: toWsUrl(env.VITE_EVENT_STREAM_URL || ''),
  /** 기상청 초단기실황 서비스키 (공공데이터포털). 비우면 키 없는 Open-Meteo 로 실시간 날씨를 가져옵니다 */
  kmaServiceKey: (env.VITE_KMA_SERVICE_KEY || '').trim(),
  /** 기상청 API 주소. 기본 /kma 는 vite 프록시가 https://apis.data.go.kr 로 넘깁니다 (브라우저 CORS 회피) */
  kmaBaseUrl: env.VITE_KMA_BASE_URL || '/kma',
  /**
   * 백엔드에 GPT 중계 API(/tourist/ai/json)가 있을 때만 true.
   * 지금 백엔드에는 없으므로 기본 false: 처음 코스는 /tourist/course(허브 혼잡도 반영),
   * 대화 수정은 /tourist/course/chat(백엔드 GPT)이 맡습니다.
   */
  gptRelay: env.VITE_GPT_RELAY === 'true',
};
