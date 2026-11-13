// ─────────────────────────────────────────────
// 관광객 화면용 목업 데이터
// 실제 서비스에서는 FastAPI 의 성향 분석 / 코스 플래너 Agent 응답으로 대체됩니다.
// ─────────────────────────────────────────────
import { project } from './jejuGeo.js';

// 4개 축: 활동성(A 액티비티 ↔ H 힐링), 공간(N 자연·바다 ↔ C 도심·핫플),
//         취향(F 미식 ↔ P 풍경·사진), 스타일(J 계획형 ↔ S 즉흥형)
export const AXES = [
  { key: 'act', left: '액티비티', right: '힐링', lc: 'A', rc: 'H' },
  { key: 'space', left: '자연·바다', right: '도심·핫플', lc: 'N', rc: 'C' },
  { key: 'taste', left: '미식 중심', right: '풍경·사진', lc: 'F', rc: 'P' },
  { key: 'style', left: '계획형', right: '즉흥형', lc: 'J', rc: 'S' },
];

// 각 문항은 하나의 축에 점수를 줍니다. a 를 고르면 왼쪽(-1), b 를 고르면 오른쪽(+1).
export const QUESTIONS = [
  { axis: 'act', q: '제주에서 맞는 첫 아침, 더 끌리는 건?', a: { icon: '🚲', t: '해안도로 자전거 한 바퀴' }, b: { icon: '☕', t: '창가 자리에서 느긋한 브런치' } },
  { axis: 'space', q: '사진첩에 가장 많이 남기고 싶은 장면은?', a: { icon: '🌊', t: '아무도 없는 에메랄드 바다' }, b: { icon: '🏮', t: '감성 가득한 골목 상점가' } },
  { axis: 'taste', q: '여행 코스를 짤 때 가장 먼저 정하는 건?', a: { icon: '🍜', t: '꼭 먹어야 할 식당' }, b: { icon: '📸', t: '꼭 봐야 할 뷰 포인트' } },
  { axis: 'style', q: '여행 전날 밤 나는?', a: { icon: '🗒️', t: '시간대별 일정표 완성' }, b: { icon: '🎲', t: '대충 방향만 정하고 잔다' } },
  { axis: 'act', q: '오름이 눈앞에 있다면?', a: { icon: '⛰️', t: '정상까지 올라가 본다' }, b: { icon: '🌾', t: '아래 억새밭에서 쉬어 간다' } },
  { axis: 'space', q: '저녁 시간을 보낼 곳은?', a: { icon: '🌅', t: '노을 지는 포구 방파제' }, b: { icon: '🍸', t: '분위기 좋은 시내 루프탑' } },
  { axis: 'taste', q: '예산이 남는다면 어디에 쓸까?', a: { icon: '🦞', t: '제철 해산물 코스' }, b: { icon: '🚁', t: '전망 좋은 숙소·체험' } },
  { axis: 'style', q: '가려던 식당에 웨이팅이 1시간이라면?', a: { icon: '⏱️', t: '미리 정한 2순위로 이동' }, b: { icon: '🚶', t: '근처를 걷다 끌리는 곳으로' } },
  { axis: 'act', q: '비 오는 날의 제주라면?', a: { icon: '🏄', t: '실내 서핑·카트 체험' }, b: { icon: '📚', t: '북카페에서 빗소리 듣기' } },
  { axis: 'space', q: '숙소를 고른다면?', a: { icon: '🏡', t: '돌담 있는 시골 독채' }, b: { icon: '🏙️', t: '맛집 많은 시내 호텔' } },
  { axis: 'taste', q: '친구에게 자랑하고 싶은 건?', a: { icon: '🥘', t: '현지인만 아는 맛집' }, b: { icon: '🖼️', t: '인생샷 한 장' } },
  { axis: 'style', q: '코스 중간 1시간이 비면?', a: { icon: '📍', t: '근처 추천 장소를 바로 찾는다' }, b: { icon: '🌿', t: '그냥 비워 두고 쉰다' } },
];

const ADJ = {
  'N-P': '노을 감성', 'N-F': '해녀밥상', 'C-P': '골목 사진', 'C-F': '핫플 미식',
};
const NOUN = {
  'A-J': '탐험가', 'A-S': '모험가', 'H-J': '산책가', 'H-S': '여행자',
};
const TYPE_DESC = {
  '노을 감성': '바다와 하늘이 바뀌는 순간을 좋아합니다. 해 지는 시간에 맞춰 코스를 짭니다.',
  '해녀밥상': '바다 가까운 곳에서 제철 음식을 먹는 것이 여행의 이유입니다.',
  '골목 사진': '오래된 돌담길과 작은 가게 사이에서 장면을 찾습니다.',
  '핫플 미식': '요즘 뜨는 식당과 카페를 먼저 알아보고 찾아갑니다.',
};

export function scoreAnswers(answers) {
  // answers: { [index]: 'a' | 'b' }
  const sum = { act: 0, space: 0, taste: 0, style: 0 };
  const cnt = { act: 0, space: 0, taste: 0, style: 0 };
  QUESTIONS.forEach((q, i) => {
    if (!answers[i]) return;
    sum[q.axis] += answers[i] === 'a' ? -1 : 1;
    cnt[q.axis] += 1;
  });
  // -100(왼쪽) ~ +100(오른쪽)
  const scores = {};
  for (const k of Object.keys(sum)) scores[k] = cnt[k] ? Math.round((sum[k] / cnt[k]) * 100) : 0;
  const pick = (k, l, r) => (scores[k] <= 0 ? l : r);
  const code = pick('act', 'A', 'H') + pick('space', 'N', 'C') + pick('taste', 'F', 'P') + pick('style', 'J', 'S');
  const adj = ADJ[`${code[1]}-${code[2]}`];
  const noun = NOUN[`${code[0]}-${code[3]}`];
  return {
    code,
    name: `${adj} ${noun}`,
    desc: TYPE_DESC[adj],
    scores,
    tags: [
      code[0] === 'A' ? '#체험' : '#휴식',
      code[1] === 'N' ? '#바다' : '#골목',
      code[2] === 'F' ? '#로컬맛집' : '#뷰포인트',
      code[3] === 'J' ? '#촘촘한일정' : '#여유시간',
    ],
  };
}

export const COMPANIONS = ['연인', '친구', '가족', '혼자'];
export const TRANSPORTS = ['렌터카', '대중교통'];
export const BUDGETS = ['5만원 이하', '5~10만원', '10~20만원', '20만원 이상'];

// 위치는 실제 위도·경도로 적고, 지도 좌표(x, y)로 변환합니다.
const ll = (lat, lon) => ({ lat, lon, ...project(lat, lon) });
export const REGIONS = [
  { id: 'jeju-city', name: '제주시 동지역', ...ll(33.489, 126.51) },
  { id: 'aewol', name: '애월읍', ...ll(33.43, 126.37) },
  { id: 'hallim', name: '한림·한경', ...ll(33.37, 126.23) },
  { id: 'daejeong', name: '대정·안덕', ...ll(33.25, 126.3) },
  { id: 'jungmun', name: '중문', ...ll(33.27, 126.43) },
  { id: 'seogwipo', name: '서귀포 동지역', ...ll(33.285, 126.57) },
  { id: 'namwon', name: '남원·표선', ...ll(33.32, 126.75) },
  { id: 'seongsan', name: '성산', ...ll(33.425, 126.88) },
  { id: 'gujwa', name: '구좌', ...ll(33.495, 126.8) },
  { id: 'jocheon', name: '조천', ...ll(33.49, 126.67) },
];

// kind: cafe | spot | sunset | food | indoor
export const PLACES = [
  { id: 'p1', name: '애월 돌담 브런치', region: 'aewol', kind: 'cafe', ...ll(33.4635, 126.3330), indoor: true, rating: 4.6, stay: 60,
    reasons: [['D1', '이 시간대 2030 커플 카드 이용 비중 상위 15%'], ['D3', '최근 한 달 와이파이 방문자 +18%']] },
  { id: 'p2', name: '한담 해안 산책로', region: 'aewol', kind: 'spot', ...ll(33.4608, 126.3107), indoor: false, rating: 4.7, stay: 50,
    reasons: [['D2', '현재 시간 혼잡도 낮음 (읍면동 유동인구 기준)'], ['D8', 'VISIT JEJU 검색 관심도 상승 중']] },
  { id: 'p3', name: '곽지 노을 방파제', region: 'aewol', kind: 'sunset', ...ll(33.4507, 126.3053), indoor: false, rating: 4.8, stay: 45,
    reasons: [['D7', '오늘 일몰 17:38 · 구름 적음'], ['자체', '노을 감성 유형 평점 4.9']] },
  { id: 'p4', name: '하귀 해녀의 집', region: 'aewol', kind: 'food', ...ll(33.48, 126.404), indoor: true, rating: 4.5, stay: 70, seafood: true,
    reasons: [['D1', '외식업 메뉴 매출 중 해산물 비중 1위 지역'], ['자체', '비슷한 성향 관광객 재방문 의향 92%']] },
  { id: 'p5', name: '애월 감귤 공방', region: 'aewol', kind: 'indoor', ...ll(33.433, 126.348), indoor: true, rating: 4.4, stay: 60,
    reasons: [['D8', '체험 상품 선호·구매 데이터 상위'], ['D7', '비 오는 날 대체 장소']] },
  { id: 'p6', name: '협재 해변', region: 'hallim', kind: 'spot', ...ll(33.394, 126.2396), indoor: false, rating: 4.8, stay: 60,
    reasons: [['D4', '관광지 유입자 수 상위 5%'], ['D2', '평일 오후 혼잡도 보통']] },
  { id: 'p7', name: '한림 보리빵 카페', region: 'hallim', kind: 'cafe', ...ll(33.4105, 126.27), indoor: true, rating: 4.3, stay: 50,
    reasons: [['D3', '장소별 와이파이 방문자 증가 추세'], ['D5', '반경 300m 동일 업종 밀도 낮음']] },
  { id: 'p8', name: '수월봉 노을', region: 'hallim', kind: 'sunset', ...ll(33.2955, 126.164), indoor: false, rating: 4.7, stay: 40,
    reasons: [['D7', '서쪽 시야 트임 · 풍속 약함'], ['D8', '여행장소 좋아요 수 상위']] },
  { id: 'p9', name: '한림항 고등어 식당', region: 'hallim', kind: 'food', ...ll(33.417, 126.263), indoor: true, rating: 4.4, stay: 60, seafood: true,
    reasons: [['D1', '저녁 18~20시 카드 이용 건수 증가'], ['D6', '버스 정류장 120m']] },
  { id: 'p10', name: '동문 골목 시장', region: 'jeju-city', kind: 'food', ...ll(33.5122, 126.5281), indoor: true, rating: 4.5, stay: 60,
    reasons: [['D1', '야간 시간대 카드 이용금액 상위'], ['D6', '정류소 이용객 많은 접근성 1등급']] },
  { id: 'p11', name: '탑동 루프탑 카페', region: 'jeju-city', kind: 'cafe', ...ll(33.516, 126.517), indoor: true, rating: 4.2, stay: 50,
    reasons: [['D3', '20대 와이파이 접속 비중 높음'], ['D2', '외국인 단기체류 유동인구 많음']] },
  { id: 'p12', name: '사라봉 노을길', region: 'jeju-city', kind: 'sunset', ...ll(33.5175, 126.545), indoor: false, rating: 4.6, stay: 40,
    reasons: [['D7', '오늘 일몰 17:38'], ['D2', '현재 혼잡도 낮음']] },
  { id: 'p13', name: '제주 책방 골목', region: 'jeju-city', kind: 'indoor', ...ll(33.5095, 126.5165), indoor: true, rating: 4.4, stay: 50,
    reasons: [['D8', '검색어 트렌드 상승'], ['D7', '실내 대체 장소']] },
  { id: 'p14', name: '함덕 해변', region: 'jocheon', kind: 'spot', ...ll(33.5432, 126.6694), indoor: false, rating: 4.8, stay: 60,
    reasons: [['D4', '관광지 유입자 수 상위'], ['D2', '오전 시간대 혼잡도 낮음']] },
  { id: 'p15', name: '조천 해녀 밥상', region: 'jocheon', kind: 'food', ...ll(33.538, 126.633), indoor: true, rating: 4.6, stay: 60, seafood: true,
    reasons: [['D1', '외식업 메뉴 매출 해산물 비중 상위'], ['자체', '가족 동행 만족도 4.7']] },
  { id: 'p16', name: '세화 바다 카페', region: 'gujwa', kind: 'cafe', ...ll(33.525, 126.859), indoor: true, rating: 4.5, stay: 50,
    reasons: [['D3', '주말 와이파이 방문자 +24%'], ['D5', '최근 개업 점포 생존율 양호 지역']] },
  { id: 'p17', name: '월정리 해변', region: 'gujwa', kind: 'spot', ...ll(33.5563, 126.7956), indoor: false, rating: 4.6, stay: 50,
    reasons: [['D8', '여행장소 좋아요 상위'], ['D2', '현재 혼잡도 보통']] },
  { id: 'p18', name: '성산 일출봉', region: 'seongsan', kind: 'spot', ...ll(33.459, 126.9425), indoor: false, rating: 4.9, stay: 80,
    reasons: [['D4', '외국인 유입자 수 1위 관광지'], ['D2', '오후 늦게 혼잡도 감소']] },
  { id: 'p19', name: '광치기 해변 노을', region: 'seongsan', kind: 'sunset', ...ll(33.452, 126.925), indoor: false, rating: 4.7, stay: 40,
    reasons: [['D7', '오늘 시정 양호'], ['자체', '사진형 성향 평점 4.8']] },
  { id: 'p20', name: '성산 갈치 식당', region: 'seongsan', kind: 'food', ...ll(33.464, 126.919), indoor: true, rating: 4.3, stay: 60, seafood: true,
    reasons: [['D1', '저녁 카드 이용금액 상위'], ['D5', '동일 업종 경쟁 밀도 높음 → 대기 짧은 곳 선별']] },
  { id: 'p21', name: '중문 색달 해변', region: 'jungmun', kind: 'spot', ...ll(33.244, 126.412), indoor: false, rating: 4.6, stay: 60,
    reasons: [['D4', '관광지 유입자 수 상위'], ['D7', '파도 높이 적정']] },
  { id: 'p22', name: '중문 아쿠아 체험관', region: 'jungmun', kind: 'indoor', ...ll(33.2525, 126.42), indoor: true, rating: 4.3, stay: 80,
    reasons: [['D8', '관광상품 구매 데이터 상위'], ['D7', '비 오는 날 대체 장소']] },
  { id: 'p23', name: '이중섭 거리', region: 'seogwipo', kind: 'cafe', ...ll(33.247, 126.565), indoor: true, rating: 4.4, stay: 60,
    reasons: [['D3', '와이파이 방문자 유형: 관광객 비중 72%'], ['D6', '정류장 접근성 우수']] },
  { id: 'p24', name: '쇠소깍', region: 'seogwipo', kind: 'spot', ...ll(33.2522, 126.6234), indoor: false, rating: 4.6, stay: 50,
    reasons: [['D4', '관광지 유입 추세 상승'], ['D2', '현재 혼잡도 낮음']] },
  { id: 'p25', name: '서귀포 올레 시장', region: 'seogwipo', kind: 'food', ...ll(33.25, 126.563), indoor: true, rating: 4.5, stay: 60, seafood: true,
    reasons: [['D1', '야간 카드 이용 건수 상위'], ['자체', '친구 동행 만족도 4.6']] },
  { id: 'p26', name: '표선 해비치 해변', region: 'namwon', kind: 'sunset', ...ll(33.326, 126.841), indoor: false, rating: 4.5, stay: 40,
    reasons: [['D2', '혼잡도 매우 낮음'], ['D8', '축제·행사 기간 연계']] },
  { id: 'p27', name: '남원 큰엉 산책길', region: 'namwon', kind: 'spot', ...ll(33.277, 126.711), indoor: false, rating: 4.6, stay: 50,
    reasons: [['D3', '방문자 증가 추세'], ['D2', '오후 혼잡도 낮음']] },
  { id: 'p28', name: '대정 방어 식당', region: 'daejeong', kind: 'food', ...ll(33.217, 126.251), indoor: true, rating: 4.5, stay: 60, seafood: true,
    reasons: [['D1', '제철(11~2월) 메뉴 매출 급증'], ['자체', '평점 4.5']] },
  { id: 'p29', name: '송악산 둘레길', region: 'daejeong', kind: 'spot', ...ll(33.2, 126.29), indoor: false, rating: 4.7, stay: 60,
    reasons: [['D4', '관광지 유입자 증가'], ['D7', '풍속 확인 필요']] },
  { id: 'p30', name: '안덕 숲 카페', region: 'daejeong', kind: 'cafe', ...ll(33.27, 126.35), indoor: true, rating: 4.4, stay: 50,
    reasons: [['D3', '와이파이 방문 증가'], ['D5', '경쟁 밀도 낮음']] },
];

export const KIND_LABEL = { cafe: '카페', spot: '산책·관광', sunset: '노을 명소', food: '저녁 식사', indoor: '실내 체험' };

export const WEATHER = {
  clear: { label: '맑음', temp: 17, icon: '☀️', note: '강수 확률 10% · 풍속 3m/s' },
  rain: { label: '비', temp: 14, icon: '🌧️', note: '강수 확률 80% · 실내 코스로 전환했어요' },
};
