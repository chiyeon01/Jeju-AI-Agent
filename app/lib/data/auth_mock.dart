// 목업 모드 시연 계정 (실제 서비스에서는 백엔드 /auth/login 이 확인합니다)
const demoPassword = 'jeju1234';

const demoAccounts = [
  {'id': 'u-1', 'email': 'user@jeju.kr', 'name': '김여행', 'role': 'USER', 'label': '관광객'},
  {'id': 'm-1', 'email': 'owner@jeju.kr', 'name': '애월 돌담국수', 'role': 'MERCHANT', 'label': '상권 주인', 'storeId': 'st-aewol-0142'},
  {'id': 'a-1', 'email': 'admin@jeju.kr', 'name': '데이터관리과', 'role': 'ADMIN', 'label': '관리자'},
];

const roleLabel = {'USER': '관광객', 'MERCHANT': '상권 주인', 'ADMIN': '관리자'};
