// ─────────────────────────────────────────────
// 제주시 Main PC 통합 데이터 관리 콘솔 목업 데이터 (React 의 src/mock/console.js 와 같은 내용)
// ─────────────────────────────────────────────

class RegionHealth {
  const RegionHealth(this.score, this.visits, this.reviews);
  final int score, visits, reviews;
}

const regionHealth = {
  'jeju-city': RegionHealth(71, 1840, 212),
  'aewol': RegionHealth(68, 1220, 164),
  'hallim': RegionHealth(63, 760, 88),
  'daejeong': RegionHealth(57, 410, 41),
  'jungmun': RegionHealth(66, 930, 102),
  'seogwipo': RegionHealth(70, 1310, 150),
  'namwon': RegionHealth(54, 380, 37),
  'seongsan': RegionHealth(74, 1460, 171),
  'gujwa': RegionHealth(61, 640, 70),
  'jocheon': RegionHealth(65, 820, 93),
};

const eventSamples = [
  ('방문 인증', '협재 해변 · 반경 120m · 성향 HNPS'),
  ('평가 등록', '애월 돌담국수 ★5 · 고객 만족 지수 4.30 → 4.31'),
  ('코스 선택', '성산 3곳 코스 · 렌터카 · 연인'),
  ('리뷰 분류', '"웨이팅이 길어요" → 대기(부정)'),
  ('평가 등록', '세화 바다 카페 ★4 · 성향-장소 행렬 갱신'),
  ('방문 인증', '동문 골목 시장 · 반경 80m'),
  ('코스 선택', '중문 실내 코스 (비) · 가족'),
  ('매장 등록', '조천 해녀 밥상 · 이벤트 "겨울 성게 한 그릇"'),
  ('리뷰 분류', '"뷰가 미쳤어요" → 분위기(긍정)'),
  ('평가 등록', '서귀포 올레 시장 ★4 · 지역 점수 70 유지'),
];

class DataSource {
  const DataSource(this.id, this.name, this.cycle, this.basis, this.last, this.rows, this.status, [this.note]);
  final String id, name, cycle, basis, last, rows, status;
  final String? note;
}

const sources = [
  DataSource('D1', '카드 이용 정보 (업종·요일·시간대·메뉴)', '월', '2025-06', '11-10 03:00', '2,184,330', 'ok'),
  DataSource('D2', '내국인·외국인 유동인구 (읍면동)', '매일 API', '2026-11-09', '11-10 03:12', '96,412', 'ok'),
  DataSource('D3', '와이파이 방문자 사용량 · AP 정보', '매일 API', '2026-11-09', '11-10 03:20', '412,905', 'warn', 'AP 3개 누락'),
  DataSource('D4', '관광지 유입자 · 입도객', '월', '2025-07', '11-01 04:00', '18,220', 'ok'),
  DataSource('D5', '상가 정보 · 사업체 생멸 · BSI', '분기', '2025-09', '10-15 04:00', '64,031', 'ok'),
  DataSource('D6', '버스 정류소 · 노선 · 승차 인원', '매일 API', '2026-11-09', '11-10 03:31', '1,203,778', 'ok'),
  DataSource('D7', '일별 기상 정보 · 관측소', '매일 API', '2026-11-09', '11-10 03:05', '7,420', 'ok'),
  DataSource('D8', 'VISIT JEJU 검색·장소·선호·축제', '월', '2025-09', '11-01 04:20', '33,815', 'err', '응답 지연으로 재시도 대기'),
];

/// (이름, 설명, 저장소, 반영 지연)
const derived = [
  ('실시간 상권 지표', '평가·방문 이벤트마다 매장 점수 재계산', 'TimescaleDB', '0.8초'),
  ('성향-장소 선호 행렬', '16유형 × 장소 평점 누적', 'PostgreSQL', '5분 배치'),
  ('혼잡도 스냅샷', '방문 인증 + 유동인구 + 와이파이 결합', 'TimescaleDB', '15분'),
  ('코스 인기 랭킹', '선택·완주 코스 집계', 'PostgreSQL', '1시간'),
  ('리뷰 감성 태그', '6개 주제 × 긍·부정 분류 (KoBERT 미세조정)', 'pgvector', '1.2초'),
];

/// (점검, 대상, 결과, 수준)
const quality = [
  ('결측치', 'D3 와이파이 AP 그룹', 'AP 3개 일일 사용량 누락', 'warn'),
  ('이상치', '평가 이벤트', '동일 계정 1시간 내 평가 6건 → 차단', 'bad'),
  ('스키마', 'D6 버스 승차 인원', '컬럼 일치', 'good'),
  ('좌표 범위', '방문 인증 위경도', '제주 범위 밖 2건 제외', 'warn'),
  ('중복', 'D1 카드 이용 정보', '중복 0건', 'good'),
];

/// GET /admin/users 응답 형식 (role: USER | MERCHANT | ADMIN, status: ACTIVE | PENDING | SUSPENDED)
const accounts = [
  {'id': 'a-1', 'name': '데이터관리과', 'email': 'admin@jeju.kr', 'role': 'ADMIN', 'status': 'ACTIVE', 'last': '11-10 09:12'},
  {'id': 'm-1', 'name': '애월 돌담국수', 'email': 'owner@jeju.kr', 'role': 'MERCHANT', 'status': 'ACTIVE', 'last': '11-10 08:47'},
  {'id': 'm-2', 'name': '세화 바다 카페', 'email': 'sehwa@jeju.kr', 'role': 'MERCHANT', 'status': 'PENDING', 'last': '-'},
  {'id': 'u-1', 'name': '김여행', 'email': 'user@jeju.kr', 'role': 'USER', 'status': 'ACTIVE', 'last': '11-09 17:02'},
];

/// (시각, 계정, 요청, 대상, 허용 여부)
const accessLog = [
  ('11-10 09:14', '데이터관리과 관리자', '조회', '지역별 상권 점수', true),
  ('11-10 08:51', '관광정책과 분석가', '반출 요청', '성향별 코스 랭킹 (집계)', true),
  ('11-10 08:20', '외부 연구기관', '반출 요청', '방문 인증 원본', false),
  ('11-09 17:02', '관광정책과 분석가', '조회', '리뷰 감성 태그', true),
];

/// (규칙, 처리 방법)
const masking = [
  ('방문 인증 위경도', '100m 격자로 일반화'),
  ('평가 계정 ID', '해시 처리, 원본은 관리자만'),
  ('셀 단위 집계', '5건 미만 셀은 공개하지 않음 (k ≥ 5)'),
  ('리뷰 본문', '전화번호·차량번호 자동 제거'),
];

/// (시각, 종류, 크기)
const backups = [
  ('11-10 02:00', '일일 스냅샷', '38.2 GB'),
  ('11-09 02:00', '일일 스냅샷', '38.0 GB'),
  ('11-08 02:00', '일일 스냅샷', '37.9 GB'),
  ('11-03 03:00', '주간 전체', '212.4 GB'),
  ('11-01 04:00', '월간 보관', '208.7 GB'),
];

/// (대상, 보관 기간)
const retention = [
  ('일일 스냅샷', '14일'),
  ('주간 전체 백업', '8주'),
  ('월간 보관', '3년'),
  ('실시간 이벤트 원본', '90일 후 집계만 보관'),
];
