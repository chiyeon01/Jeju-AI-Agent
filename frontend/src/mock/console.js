// ─────────────────────────────────────────────
// 제주시 Main PC 통합 데이터 관리 콘솔 목업 데이터
// ─────────────────────────────────────────────

export const REGION_HEALTH = {
  'jeju-city': { score: 71, visits: 1840, reviews: 212 },
  aewol: { score: 68, visits: 1220, reviews: 164 },
  hallim: { score: 63, visits: 760, reviews: 88 },
  daejeong: { score: 57, visits: 410, reviews: 41 },
  jungmun: { score: 66, visits: 930, reviews: 102 },
  seogwipo: { score: 70, visits: 1310, reviews: 150 },
  namwon: { score: 54, visits: 380, reviews: 37 },
  seongsan: { score: 74, visits: 1460, reviews: 171 },
  gujwa: { score: 61, visits: 640, reviews: 70 },
  jocheon: { score: 65, visits: 820, reviews: 93 },
};

export const POPULAR_COURSES = [
  { from: 'aewol', to: 'hallim', name: '애월 브런치 → 협재 → 수월봉 노을', count: 412, type: '노을 감성 탐험가' },
  { from: 'jocheon', to: 'gujwa', name: '함덕 → 세화 카페 → 월정리', count: 338, type: '골목 사진 여행자' },
  { from: 'seongsan', to: 'namwon', name: '일출봉 → 광치기 → 표선', count: 291, type: '노을 감성 모험가' },
  { from: 'jeju-city', to: 'jocheon', name: '동문시장 → 사라봉 → 조천 해녀밥상', count: 254, type: '해녀밥상 산책가' },
];

export const EVENT_TYPES = [
  { type: '방문 인증', pill: 'sea' },
  { type: '평가 등록', pill: 'accent' },
  { type: '코스 선택', pill: '' },
  { type: '리뷰 분류', pill: 'good' },
  { type: '매장 등록', pill: 'warn' },
];

export const EVENT_SAMPLES = [
  ['방문 인증', '협재 해변 · 반경 120m · 성향 HNPS'],
  ['평가 등록', '애월 돌담국수 ★5 · 고객 만족 지수 4.30 → 4.31'],
  ['코스 선택', '성산 3곳 코스 · 렌터카 · 연인'],
  ['리뷰 분류', '"웨이팅이 길어요" → 대기(부정)'],
  ['평가 등록', '세화 바다 카페 ★4 · 성향-장소 행렬 갱신'],
  ['방문 인증', '동문 골목 시장 · 반경 80m'],
  ['코스 선택', '중문 실내 코스 (비) · 가족'],
  ['매장 등록', '조천 해녀 밥상 · 이벤트 "겨울 성게 한 그릇"'],
  ['리뷰 분류', '"뷰가 미쳤어요" → 분위기(긍정)'],
  ['평가 등록', '서귀포 올레 시장 ★4 · 지역 점수 70 유지'],
];

export const SOURCES = [
  { id: 'D1', name: '카드 이용 정보 (업종·요일·시간대·메뉴)', cycle: '월', basis: '2025-06', last: '11-10 03:00', rows: '2,184,330', status: 'ok' },
  { id: 'D2', name: '내국인·외국인 유동인구 (읍면동)', cycle: '매일 API', basis: '2026-11-09', last: '11-10 03:12', rows: '96,412', status: 'ok' },
  { id: 'D3', name: '와이파이 방문자 사용량 · AP 정보', cycle: '매일 API', basis: '2026-11-09', last: '11-10 03:20', rows: '412,905', status: 'warn', note: 'AP 3개 누락' },
  { id: 'D4', name: '관광지 유입자 · 입도객', cycle: '월', basis: '2025-07', last: '11-01 04:00', rows: '18,220', status: 'ok' },
  { id: 'D5', name: '상가 정보 · 사업체 생멸 · BSI', cycle: '분기', basis: '2025-09', last: '10-15 04:00', rows: '64,031', status: 'ok' },
  { id: 'D6', name: '버스 정류소 · 노선 · 승차 인원', cycle: '매일 API', basis: '2026-11-09', last: '11-10 03:31', rows: '1,203,778', status: 'ok' },
  { id: 'D7', name: '일별 기상 정보 · 관측소', cycle: '매일 API', basis: '2026-11-09', last: '11-10 03:05', rows: '7,420', status: 'ok' },
  { id: 'D8', name: 'VISIT JEJU 검색·장소·선호·축제', cycle: '월', basis: '2025-09', last: '11-01 04:20', rows: '33,815', status: 'err', note: '응답 지연으로 재시도 대기' },
];

export const DERIVED = [
  { name: '실시간 상권 지표', desc: '평가·방문 이벤트마다 매장 점수 재계산', store: 'TimescaleDB', lag: '0.8초' },
  { name: '성향-장소 선호 행렬', desc: '16유형 × 장소 평점 누적', store: 'PostgreSQL', lag: '5분 배치' },
  { name: '혼잡도 스냅샷', desc: '방문 인증 + 유동인구 + 와이파이 결합', store: 'TimescaleDB', lag: '15분' },
  { name: '코스 인기 랭킹', desc: '선택·완주 코스 집계', store: 'PostgreSQL', lag: '1시간' },
  { name: '리뷰 감성 태그', desc: '6개 주제 × 긍·부정 분류 (KoBERT 미세조정)', store: 'pgvector', lag: '1.2초' },
];

export const QUALITY = [
  { check: '결측치', target: 'D3 와이파이 AP 그룹', result: 'AP 3개 일일 사용량 누락', level: 'warn' },
  { check: '이상치', target: '평가 이벤트', result: '동일 계정 1시간 내 평가 6건 → 차단', level: 'bad' },
  { check: '스키마', target: 'D6 버스 승차 인원', result: '컬럼 일치', level: 'good' },
  { check: '좌표 범위', target: '방문 인증 위경도', result: '제주 범위 밖 2건 제외', level: 'warn' },
  { check: '중복', target: 'D1 카드 이용 정보', result: '중복 0건', level: 'good' },
];

export const ACCOUNTS = [
  { name: '데이터관리과 관리자', role: '관리자', scope: '전체 읽기·쓰기·반출 승인', last: '11-10 09:12' },
  { name: '관광정책과 분석가', role: '분석가', scope: '집계 데이터 읽기', last: '11-10 08:47' },
  { name: '상권 Agent 서비스 계정', role: '서비스', scope: '지표·리뷰 테이블 읽기', last: '실시간' },
  { name: '관광객 Agent 서비스 계정', role: '서비스', scope: '장소·코스·선호 행렬 읽기', last: '실시간' },
  { name: '외부 연구기관 (센터 PC)', role: '열람', scope: '마스킹 집계만 열람, 반출 불가', last: '11-07 14:30' },
];

export const ACCESS_LOG = [
  { at: '11-10 09:14', who: '데이터관리과 관리자', action: '조회', target: '지역별 상권 점수', ok: true },
  { at: '11-10 08:51', who: '관광정책과 분석가', action: '반출 요청', target: '성향별 코스 랭킹 (집계)', ok: true },
  { at: '11-10 08:20', who: '외부 연구기관', action: '반출 요청', target: '방문 인증 원본', ok: false },
  { at: '11-09 17:02', who: '관광정책과 분석가', action: '조회', target: '리뷰 감성 태그', ok: true },
];

export const MASKING = [
  { rule: '방문 인증 위경도', how: '100m 격자로 일반화' },
  { rule: '평가 계정 ID', how: '해시 처리, 원본은 관리자만' },
  { rule: '셀 단위 집계', how: '5건 미만 셀은 공개하지 않음 (k ≥ 5)' },
  { rule: '리뷰 본문', how: '전화번호·차량번호 자동 제거' },
];

export const BACKUPS = [
  { at: '11-10 02:00', kind: '일일 스냅샷', size: '38.2 GB', ok: true },
  { at: '11-09 02:00', kind: '일일 스냅샷', size: '38.0 GB', ok: true },
  { at: '11-08 02:00', kind: '일일 스냅샷', size: '37.9 GB', ok: true },
  { at: '11-03 03:00', kind: '주간 전체', size: '212.4 GB', ok: true },
  { at: '11-01 04:00', kind: '월간 보관', size: '208.7 GB', ok: true },
];

export const RETENTION = [
  { what: '일일 스냅샷', keep: '14일' },
  { what: '주간 전체 백업', keep: '8주' },
  { what: '월간 보관', keep: '3년' },
  { what: '실시간 이벤트 원본', keep: '90일 후 집계만 보관' },
];
