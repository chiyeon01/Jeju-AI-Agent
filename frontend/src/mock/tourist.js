// ─────────────────────────────────────────────
// 관광객 화면용 목업 데이터
// 실제 서비스에서는 FastAPI 의 성향 분석 / 코스 플래너 Agent 응답으로 대체됩니다.
// ─────────────────────────────────────────────

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
  { axis: 'space', q: '저녁 시간을 보낼 곳은?', a: { icon: '🌅', t: '노을 지는 포구 방파제' }, b: { icon: '🍸', t: '분위기 좋은 시내 루프탑' } },
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
export const TRANSPORTS = ['자동차', '택시', '버스', '배'];

// 위치는 실제 위도·경도로 적습니다 (카카오맵에 그대로 표시).
const ll = (lat, lon) => ({ lat, lon });
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
// 실제로 있는 제주 장소 (이름 + 읍·면·동으로 한 곳이 특정됩니다. 위도·경도는 지도 표시용 대략값)
export const PLACES = [
  { id: "p1", name: "봄날카페", region: "aewol", kind: "cafe", ...ll(33.4627, 126.3097), addr: "제주시 애월읍 애월리", indoor: true, rating: 4.5, stay: 60, seafood: false,
    tags: ["바다뷰", "카페"], reasons: [['소개', "한담 해안 바로 앞, 바다가 보이는 카페"]] },
  { id: "p2", name: "한담해안산책로", region: "aewol", kind: "spot", ...ll(33.4614, 126.3118), addr: "제주시 애월읍 애월리", indoor: false, rating: 4.7, stay: 50, seafood: false,
    tags: ["산책", "바다"], reasons: [['소개', "애월 바닷가를 따라 걷는 1.2km 해안 산책로"]] },
  { id: "p3", name: "곽지해수욕장", region: "aewol", kind: "sunset", ...ll(33.4507, 126.3049), addr: "제주시 애월읍 곽지리", indoor: false, rating: 4.6, stay: 45, seafood: false,
    tags: ["해변", "노을"], reasons: [['소개', "서쪽 바다로 해가 지는 모래 해변"]] },
  { id: "p4", name: "애월연어", region: "aewol", kind: "food", ...ll(33.4645, 126.3192), addr: "제주시 애월읍 애월리", indoor: true, rating: 4.4, stay: 60, seafood: true,
    tags: ["연어", "해산물"], reasons: [['소개', "연어 덮밥·회를 파는 애월 식당"]] },
  { id: "p5", name: "아르떼뮤지엄 제주", region: "aewol", kind: "indoor", ...ll(33.3963, 126.3448), addr: "제주시 애월읍 어림비로", indoor: true, rating: 4.6, stay: 80, seafood: false, label: "미디어아트 전시관",
    tags: ["미술관", "전시", "미디어아트"], reasons: [['소개', "옛 공장을 고친 몰입형 미디어아트 전시관"]] },
  { id: "p6", name: "협재해수욕장", region: "hallim", kind: "spot", ...ll(33.394, 126.2396), addr: "제주시 한림읍 협재리", indoor: false, rating: 4.8, stay: 60, seafood: false,
    tags: ["해변", "바다"], reasons: [['소개', "비양도가 보이는 에메랄드빛 얕은 해변"]] },
  { id: "p7", name: "앤트러사이트 제주 한림점", region: "hallim", kind: "cafe", ...ll(33.4117, 126.2693), addr: "제주시 한림읍 한림로", indoor: true, rating: 4.4, stay: 50, seafood: false,
    tags: ["카페", "공장 개조"], reasons: [['소개', "옛 전분 공장을 고친 커피 로스터리"]] },
  { id: "p8", name: "수월봉", region: "hallim", kind: "sunset", ...ll(33.2956, 126.1628), addr: "제주시 한경면 고산리", indoor: false, rating: 4.7, stay: 40, seafood: false,
    tags: ["노을", "지질공원"], reasons: [['소개', "서쪽 끝 해안 절벽, 노을 명소"]] },
  { id: "p9", name: "한림칼국수 제주본점", region: "hallim", kind: "food", ...ll(33.4129, 126.2586), addr: "제주시 한림읍 한림리", indoor: true, rating: 4.3, stay: 50, seafood: true,
    tags: ["보말칼국수", "해산물"], reasons: [['소개', "보말칼국수로 알려진 한림 식당"]] },
  { id: "p10", name: "동문재래시장", region: "jeju-city", kind: "food", ...ll(33.5121, 126.5262), addr: "제주시 관덕로14길", indoor: true, rating: 4.5, stay: 60, seafood: true,
    tags: ["시장", "회", "기념품"], reasons: [['소개', "제주 최대 상설시장, 회·먹거리·기념품"]] },
  { id: "p11", name: "카페 델문도", region: "jocheon", kind: "cafe", ...ll(33.5434, 126.6687), addr: "제주시 조천읍 함덕리", indoor: true, rating: 4.5, stay: 50, seafood: false,
    tags: ["바다뷰", "카페"], reasons: [['소개', "함덕 해변 바로 옆 바다 카페"]] },
  { id: "p12", name: "사라봉공원", region: "jeju-city", kind: "sunset", ...ll(33.5176, 126.545), addr: "제주시 건입동", indoor: false, rating: 4.5, stay: 40, seafood: false,
    tags: ["노을", "산책"], reasons: [['소개', "제주항과 바다 너머 노을을 보는 오름 공원"]] },
  { id: "p13", name: "국립제주박물관", region: "jeju-city", kind: "indoor", ...ll(33.5133, 126.5491), addr: "제주시 일주동로", indoor: true, rating: 4.5, stay: 70, seafood: false, label: "박물관",
    tags: ["박물관", "전시"], reasons: [['소개', "제주 역사·문화를 보여 주는 국립박물관"]] },
  { id: "p14", name: "함덕해수욕장", region: "jocheon", kind: "spot", ...ll(33.5432, 126.6694), addr: "제주시 조천읍 함덕리", indoor: false, rating: 4.8, stay: 60, seafood: false,
    tags: ["해변", "바다"], reasons: [['소개', "서우봉 옆 얕고 맑은 해변"]] },
  { id: "p15", name: "도두해녀의집", region: "jeju-city", kind: "food", ...ll(33.506, 126.466), addr: "제주시 도두일동", indoor: true, rating: 4.3, stay: 60, seafood: true,
    tags: ["물회", "해산물"], reasons: [['소개', "해녀가 운영하는 물회 식당"]] },
  { id: "p16", name: "풍림다방 송당점", region: "gujwa", kind: "cafe", ...ll(33.4708, 126.7822), addr: "제주시 구좌읍 송당리", indoor: true, rating: 4.5, stay: 50, seafood: false,
    tags: ["카페", "감성"], reasons: [['소개', "송당 마을의 작은 감성 카페"]] },
  { id: "p17", name: "월정리해변", region: "gujwa", kind: "spot", ...ll(33.5563, 126.7956), addr: "제주시 구좌읍 월정리", indoor: false, rating: 4.6, stay: 50, seafood: false,
    tags: ["해변", "카페거리"], reasons: [['소개', "카페가 늘어선 하얀 모래 해변"]] },
  { id: "p18", name: "성산일출봉", region: "seongsan", kind: "spot", ...ll(33.4581, 126.9425), addr: "서귀포시 성산읍 성산리", indoor: false, rating: 4.8, stay: 80, seafood: false,
    tags: ["오름", "유네스코"], reasons: [['소개', "유네스코 세계자연유산 화산 분화구"]] },
  { id: "p19", name: "섭지코지", region: "seongsan", kind: "sunset", ...ll(33.4243, 126.9306), addr: "서귀포시 성산읍 고성리", indoor: false, rating: 4.6, stay: 50, seafood: false,
    tags: ["해안", "풍경"], reasons: [['소개', "성산일출봉이 보이는 해안 언덕"]] },
  { id: "p20", name: "맛나식당", region: "seongsan", kind: "food", ...ll(33.4627, 126.9332), addr: "서귀포시 성산읍 성산리", indoor: true, rating: 4.4, stay: 50, seafood: true,
    tags: ["갈치조림", "해산물"], reasons: [['소개', "갈치·고등어조림으로 알려진 성산 식당"]] },
  { id: "p21", name: "중문색달해수욕장", region: "jungmun", kind: "spot", ...ll(33.2445, 126.412), addr: "서귀포시 색달동", indoor: false, rating: 4.6, stay: 60, seafood: false,
    tags: ["해변", "서핑"], reasons: [['소개', "파도가 좋아 서핑을 많이 하는 해변"]] },
  { id: "p22", name: "테디베어뮤지엄 제주", region: "jungmun", kind: "indoor", ...ll(33.2497, 126.4123), addr: "서귀포시 중문관광로", indoor: true, rating: 4.3, stay: 70, seafood: false, label: "박물관",
    tags: ["박물관", "전시", "아이"], reasons: [['소개', "테디베어 전시관, 아이와 가기 좋은 실내"]] },
  { id: "p23", name: "허니문하우스", region: "seogwipo", kind: "cafe", ...ll(33.2436, 126.5806), addr: "서귀포시 토평동", indoor: true, rating: 4.5, stay: 50, seafood: false,
    tags: ["바다뷰", "카페"], reasons: [['소개', "소정방폭포 위 절벽의 바다 카페"]] },
  { id: "p24", name: "쇠소깍", region: "seogwipo", kind: "spot", ...ll(33.2522, 126.6234), addr: "서귀포시 하효동", indoor: false, rating: 4.6, stay: 50, seafood: false,
    tags: ["계곡", "카약"], reasons: [['소개', "민물과 바다가 만나는 계곡, 투명카약"]] },
  { id: "p25", name: "서귀포매일올레시장", region: "seogwipo", kind: "food", ...ll(33.2497, 126.5636), addr: "서귀포시 중앙로62번길", indoor: true, rating: 4.5, stay: 60, seafood: true,
    tags: ["시장", "회", "기념품"], reasons: [['소개', "서귀포 상설시장, 회·먹거리·기념품"]] },
  { id: "p26", name: "표선해수욕장", region: "namwon", kind: "sunset", ...ll(33.3264, 126.8414), addr: "서귀포시 표선면 표선리", indoor: false, rating: 4.5, stay: 40, seafood: false,
    tags: ["해변", "산책"], reasons: [['소개', "넓은 백사장이 펼쳐지는 해변"]] },
  { id: "p27", name: "큰엉해안경승지", region: "namwon", kind: "spot", ...ll(33.277, 126.711), addr: "서귀포시 남원읍 남원리", indoor: false, rating: 4.6, stay: 50, seafood: false,
    tags: ["해안", "산책"], reasons: [['소개', "한반도 모양 숲길로 알려진 해안 절벽 산책로"]] },
  { id: "p28", name: "부두식당", region: "daejeong", kind: "food", ...ll(33.2172, 126.2507), addr: "서귀포시 대정읍 하모리", indoor: true, rating: 4.4, stay: 60, seafood: true,
    tags: ["방어", "해산물"], reasons: [['소개', "모슬포항 방어회 식당 (제철 11~2월)"]] },
  { id: "p29", name: "송악산", region: "daejeong", kind: "spot", ...ll(33.1997, 126.2895), addr: "서귀포시 대정읍 상모리", indoor: false, rating: 4.7, stay: 60, seafood: false,
    tags: ["오름", "둘레길"], reasons: [['소개', "마라도·형제섬이 보이는 해안 둘레길"]] },
  { id: "p30", name: "오설록 티뮤지엄", region: "daejeong", kind: "cafe", ...ll(33.3059, 126.2895), addr: "서귀포시 안덕면 서광리", indoor: true, rating: 4.5, stay: 60, seafood: false,
    tags: ["녹차", "카페"], reasons: [['소개', "녹차밭 옆 차 박물관 겸 카페"]] },
  { id: "p31", name: "제주도립미술관", region: "jeju-city", kind: "indoor", ...ll(33.4524, 126.489), addr: "제주시 1100로", indoor: true, rating: 4.5, stay: 70, seafood: false, label: "미술관",
    tags: ["미술관", "전시"], reasons: [['소개', "제주 작가와 기획전을 볼 수 있는 도립 미술관"]] },
  { id: "p32", name: "이중섭미술관", region: "seogwipo", kind: "indoor", ...ll(33.2468, 126.5652), addr: "서귀포시 서귀동", indoor: true, rating: 4.4, stay: 50, seafood: false, label: "미술관",
    tags: ["미술관", "전시"], reasons: [['소개', "화가 이중섭이 살던 곳 옆 미술관"]] },
  { id: "p33", name: "제주도립 김창열미술관", region: "hallim", kind: "indoor", ...ll(33.336, 126.269), addr: "제주시 한경면 저지리", indoor: true, rating: 4.5, stay: 60, seafood: false, label: "미술관",
    tags: ["미술관", "전시"], reasons: [['소개', "물방울 작가 김창열의 미술관"]] },
  { id: "p34", name: "본태박물관", region: "daejeong", kind: "indoor", ...ll(33.3008, 126.393), addr: "서귀포시 안덕면 상천리", indoor: true, rating: 4.5, stay: 70, seafood: false, label: "미술관",
    tags: ["미술관", "박물관", "건축"], reasons: [['소개', "안도 다다오가 설계한 미술관·박물관"]] },
  { id: "p35", name: "아라리오뮤지엄 탑동시네마", region: "jeju-city", kind: "indoor", ...ll(33.5161, 126.5199), addr: "제주시 탑동로", indoor: true, rating: 4.4, stay: 60, seafood: false, label: "미술관",
    tags: ["미술관", "전시"], reasons: [['소개', "옛 극장을 고친 현대미술관"]] },
  { id: "p36", name: "이니스프리 제주하우스", region: "daejeong", kind: "indoor", ...ll(33.3054, 126.2884), addr: "서귀포시 안덕면 서광리", indoor: true, rating: 4.3, stay: 30, seafood: false, label: "기념품샵",
    tags: ["기념품", "소품샵", "쇼핑"], reasons: [['소개', "오설록 옆, 제주 한정 기념품·화장품 가게"]] },
  { id: "p37", name: "소심한책방", region: "gujwa", kind: "indoor", ...ll(33.4911, 126.898), addr: "제주시 구좌읍 종달리", indoor: true, rating: 4.5, stay: 30, seafood: false, label: "소품샵",
    tags: ["기념품", "소품샵", "책방"], reasons: [['소개', "종달리 마을의 작은 책방 겸 소품샵"]] },
];

export const KIND_LABEL = { cafe: '카페', spot: '산책·관광', sunset: '노을 명소', food: '저녁 식사', indoor: '실내 체험' };

export const WEATHER = {
  clear: { label: '맑음', temp: 17, icon: '☀️', note: '강수 확률 10% · 풍속 3m/s' },
  rain: { label: '비', temp: 14, icon: '🌧️', note: '강수 확률 80% · 실내 코스로 전환했어요' },
};
