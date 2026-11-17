// 목업 모드 시연 계정 (실제 서비스에서는 백엔드 /auth/login 이 확인합니다)
export const DEMO_PASSWORD = 'jeju1234';

export const DEMO_ACCOUNTS = [
  { id: 'u-1', email: 'user@jeju.kr', name: '김여행', role: 'USER', label: '관광객' },
  { id: 'm-1', email: 'owner@jeju.kr', name: '애월 돌담국수', role: 'MERCHANT', label: '상권 주인', storeId: 'st-aewol-0142' },
  { id: 'a-1', email: 'admin@jeju.kr', name: '데이터관리과', role: 'ADMIN', label: '관리자' },
];

// 백엔드 security.py 의 테스트 계정과 같게 맞춘 목업 계정 (비밀번호 = 이메일 앞부분, 예: c123@test.kr / c123)
export const TEST_ACCOUNTS = [
  { id: 't-a123', email: 'a123@test.kr', name: '테스트 관광객', role: 'USER', status: 'ACTIVE' },
  { id: 't-b123', email: 'b123@test.kr', name: '테스트 상권', role: 'MERCHANT', status: 'ACTIVE', storeId: 'st-aewol-0142' },
  { id: 't-c123', email: 'c123@test.kr', name: '테스트 관리자', role: 'ADMIN', status: 'ACTIVE' },
];

/** 테스트 관리자 계정(…@test.kr 관리자)이면 화면을 더 굵직하게 보여 줍니다 */
export const isTestAdmin = (u) => !!u && u.role === 'ADMIN' && /@test\.kr$/i.test(u.email || '');

export const ROLE_LABEL = { USER: '관광객', MERCHANT: '상권 주인', ADMIN: '관리자' };
