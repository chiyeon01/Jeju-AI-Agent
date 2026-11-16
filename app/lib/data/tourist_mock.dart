// ─────────────────────────────────────────────
// 관광객 화면용 목업 데이터 (React 의 src/mock/tourist.js 와 같은 내용)
// 실제 서비스에서는 FastAPI 의 성향 분석 / 코스 플래너 Agent 응답으로 대체됩니다.
// ─────────────────────────────────────────────
import 'dart:ui';

import 'jeju_geo.dart';

// 4개 축: 활동성(A 액티비티 ↔ H 힐링), 공간(N 자연·바다 ↔ C 도심·핫플),
//         취향(F 미식 ↔ P 풍경·사진), 스타일(J 계획형 ↔ S 즉흥형)
class TasteAxis {
  const TasteAxis(this.key, this.left, this.right, this.lc, this.rc);
  final String key, left, right, lc, rc;
}

const axes = [
  TasteAxis('act', '액티비티', '힐링', 'A', 'H'),
  TasteAxis('space', '자연·바다', '도심·핫플', 'N', 'C'),
  TasteAxis('taste', '미식 중심', '풍경·사진', 'F', 'P'),
  TasteAxis('style', '계획형', '즉흥형', 'J', 'S'),
];

class Choice {
  const Choice(this.icon, this.t);
  final String icon, t;
}

class Question {
  const Question(this.axis, this.q, this.a, this.b);
  final String axis, q;
  final Choice a, b;
}

// 각 문항은 하나의 축에 점수를 줍니다. a 를 고르면 왼쪽(-1), b 를 고르면 오른쪽(+1).
const questions = [
  Question('act', '제주에서 맞는 첫 아침, 더 끌리는 건?', Choice('🚲', '해안도로 자전거 한 바퀴'), Choice('☕', '창가 자리에서 느긋한 브런치')),
  Question('space', '사진첩에 가장 많이 남기고 싶은 장면은?', Choice('🌊', '아무도 없는 에메랄드 바다'), Choice('🏮', '감성 가득한 골목 상점가')),
  Question('taste', '여행 코스를 짤 때 가장 먼저 정하는 건?', Choice('🍜', '꼭 먹어야 할 식당'), Choice('📸', '꼭 봐야 할 뷰 포인트')),
  Question('style', '여행 전날 밤 나는?', Choice('🗒️', '시간대별 일정표 완성'), Choice('🎲', '대충 방향만 정하고 잔다')),
  Question('act', '오름이 눈앞에 있다면?', Choice('⛰️', '정상까지 올라가 본다'), Choice('🌾', '아래 억새밭에서 쉬어 간다')),
  Question('space', '저녁 시간을 보낼 곳은?', Choice('🌅', '노을 지는 포구 방파제'), Choice('🍸', '분위기 좋은 시내 루프탑')),
  Question('taste', '예산이 남는다면 어디에 쓸까?', Choice('🦞', '제철 해산물 코스'), Choice('🚁', '전망 좋은 숙소·체험')),
  Question('style', '가려던 식당에 웨이팅이 1시간이라면?', Choice('⏱️', '미리 정한 2순위로 이동'), Choice('🚶', '근처를 걷다 끌리는 곳으로')),
  Question('act', '비 오는 날의 제주라면?', Choice('🏄', '실내 서핑·카트 체험'), Choice('📚', '북카페에서 빗소리 듣기')),
  Question('space', '숙소를 고른다면?', Choice('🏡', '돌담 있는 시골 독채'), Choice('🏙️', '맛집 많은 시내 호텔')),
  Question('taste', '친구에게 자랑하고 싶은 건?', Choice('🥘', '현지인만 아는 맛집'), Choice('🖼️', '인생샷 한 장')),
  Question('style', '코스 중간 1시간이 비면?', Choice('📍', '근처 추천 장소를 바로 찾는다'), Choice('🌿', '그냥 비워 두고 쉰다')),
];

const _adj = {'N-P': '노을 감성', 'N-F': '해녀밥상', 'C-P': '골목 사진', 'C-F': '핫플 미식'};
const _noun = {'A-J': '탐험가', 'A-S': '모험가', 'H-J': '산책가', 'H-S': '여행자'};
const _typeDesc = {
  '노을 감성': '바다와 하늘이 바뀌는 순간을 좋아합니다. 해 지는 시간에 맞춰 코스를 짭니다.',
  '해녀밥상': '바다 가까운 곳에서 제철 음식을 먹는 것이 여행의 이유입니다.',
  '골목 사진': '오래된 돌담길과 작은 가게 사이에서 장면을 찾습니다.',
  '핫플 미식': '요즘 뜨는 식당과 카페를 먼저 알아보고 찾아갑니다.',
};

/// 동행·이동수단·예산 등 마지막 단계 입력
class TripExtra {
  const TripExtra({this.companion = '연인', this.transport = '렌터카', this.budget = '5~10만원', this.startTime = '15:00', this.hours = 5});
  final String companion, transport, budget, startTime;
  final int hours;

  TripExtra copyWith({String? companion, String? transport, String? budget, String? startTime, int? hours}) => TripExtra(
        companion: companion ?? this.companion,
        transport: transport ?? this.transport,
        budget: budget ?? this.budget,
        startTime: startTime ?? this.startTime,
        hours: hours ?? this.hours,
      );

  Map<String, dynamic> toJson() =>
      {'companion': companion, 'transport': transport, 'budget': budget, 'startTime': startTime, 'hours': hours};
}

/// 성향 분석 결과 (유형 + 동행 정보)
class Profile {
  const Profile({required this.code, required this.name, required this.desc, required this.scores, required this.tags, required this.extra});
  final String code, name, desc;
  final Map<String, int> scores; // -100(왼쪽) ~ +100(오른쪽)
  final List<String> tags;
  final TripExtra extra;

  String get companion => extra.companion;
  String get transport => extra.transport;
  String get budget => extra.budget;
  String get startTime => extra.startTime;

  Map<String, dynamic> toJson() => {'code': code, 'name': name, 'desc': desc, 'scores': scores, 'tags': tags, ...extra.toJson()};

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        code: j['code'],
        name: j['name'],
        desc: j['desc'] ?? '',
        scores: Map<String, int>.from((j['scores'] as Map).map((k, v) => MapEntry(k as String, (v as num).round()))),
        tags: List<String>.from(j['tags'] ?? const []),
        extra: TripExtra(
          companion: j['companion'] ?? '연인',
          transport: j['transport'] ?? '렌터카',
          budget: j['budget'] ?? '5~10만원',
          startTime: j['startTime'] ?? '15:00',
          hours: (j['hours'] as num?)?.toInt() ?? 5,
        ),
      );
}

/// answers: { 문항 번호: 'a' | 'b' }
Profile scoreAnswers(Map<int, String> answers, TripExtra extra) {
  final sum = {'act': 0, 'space': 0, 'taste': 0, 'style': 0};
  final cnt = {'act': 0, 'space': 0, 'taste': 0, 'style': 0};
  for (var i = 0; i < questions.length; i++) {
    final a = answers[i];
    if (a == null) continue;
    final q = questions[i];
    sum[q.axis] = sum[q.axis]! + (a == 'a' ? -1 : 1);
    cnt[q.axis] = cnt[q.axis]! + 1;
  }
  final scores = <String, int>{};
  for (final k in sum.keys) {
    scores[k] = cnt[k]! > 0 ? (sum[k]! / cnt[k]! * 100).round() : 0;
  }
  String pick(String k, String l, String r) => scores[k]! <= 0 ? l : r;
  final code = pick('act', 'A', 'H') + pick('space', 'N', 'C') + pick('taste', 'F', 'P') + pick('style', 'J', 'S');
  final adj = _adj['${code[1]}-${code[2]}']!;
  final noun = _noun['${code[0]}-${code[3]}']!;
  return Profile(
    code: code,
    name: '$adj $noun',
    desc: _typeDesc[adj]!,
    scores: scores,
    tags: [
      code[0] == 'A' ? '#체험' : '#휴식',
      code[1] == 'N' ? '#바다' : '#골목',
      code[2] == 'F' ? '#로컬맛집' : '#뷰포인트',
      code[3] == 'J' ? '#촘촘한일정' : '#여유시간',
    ],
    extra: extra,
  );
}

const companions = ['연인', '친구', '가족', '혼자'];
const transports = ['렌터카', '대중교통'];
const budgets = ['5만원 이하', '5~10만원', '10~20만원', '20만원 이상'];

/// 지역 (위치는 실제 위도·경도로 적고, 지도 좌표 x, y 로 변환합니다)
class Region {
  Region(this.id, this.name, this.lat, this.lon) : pos = project(lat, lon);
  final String id, name;
  final double lat, lon;
  final Offset pos;
  double get x => pos.dx;
  double get y => pos.dy;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'lat': lat, 'lon': lon, 'x': x, 'y': y};
}

final regions = [
  Region('jeju-city', '제주시 동지역', 33.489, 126.51),
  Region('aewol', '애월읍', 33.43, 126.37),
  Region('hallim', '한림·한경', 33.37, 126.23),
  Region('daejeong', '대정·안덕', 33.25, 126.3),
  Region('jungmun', '중문', 33.27, 126.43),
  Region('seogwipo', '서귀포 동지역', 33.285, 126.57),
  Region('namwon', '남원·표선', 33.32, 126.75),
  Region('seongsan', '성산', 33.425, 126.88),
  Region('gujwa', '구좌', 33.495, 126.8),
  Region('jocheon', '조천', 33.49, 126.67),
];

final regionById = {for (final r in regions) r.id: r};

/// 장소. kind: cafe | spot | sunset | food | indoor
class Place {
  Place(this.id, this.name, this.region, this.kind, this.lat, this.lon,
      {required this.indoor, required this.rating, required this.stay, this.seafood = false, required this.reasons})
      : pos = project(lat, lon);
  final String id, name, region, kind;
  final double lat, lon;
  final Offset pos;
  final bool indoor, seafood;
  final double rating;
  final int stay; // 머무는 시간(분)
  final List<(String, String)> reasons; // (데이터 출처, 근거)
  double get x => pos.dx;
  double get y => pos.dy;
}

final places = [
  Place('p1', '애월 돌담 브런치', 'aewol', 'cafe', 33.4635, 126.3330, indoor: true, rating: 4.6, stay: 60, seafood: false, reasons: [('D1', '이 시간대 2030 커플 카드 이용 비중 상위 15%'), ('D3', '최근 한 달 와이파이 방문자 +18%')]),
  Place('p2', '한담 해안 산책로', 'aewol', 'spot', 33.4608, 126.3107, indoor: false, rating: 4.7, stay: 50, seafood: false, reasons: [('D2', '현재 시간 혼잡도 낮음 (읍면동 유동인구 기준)'), ('D8', 'VISIT JEJU 검색 관심도 상승 중')]),
  Place('p3', '곽지 노을 방파제', 'aewol', 'sunset', 33.4507, 126.3053, indoor: false, rating: 4.8, stay: 45, seafood: false, reasons: [('D7', '오늘 일몰 17:38 · 구름 적음'), ('자체', '노을 감성 유형 평점 4.9')]),
  Place('p4', '하귀 해녀의 집', 'aewol', 'food', 33.48, 126.404, indoor: true, rating: 4.5, stay: 70, seafood: true, reasons: [('D1', '외식업 메뉴 매출 중 해산물 비중 1위 지역'), ('자체', '비슷한 성향 관광객 재방문 의향 92%')]),
  Place('p5', '애월 감귤 공방', 'aewol', 'indoor', 33.433, 126.348, indoor: true, rating: 4.4, stay: 60, seafood: false, reasons: [('D8', '체험 상품 선호·구매 데이터 상위'), ('D7', '비 오는 날 대체 장소')]),
  Place('p6', '협재 해변', 'hallim', 'spot', 33.394, 126.2396, indoor: false, rating: 4.8, stay: 60, seafood: false, reasons: [('D4', '관광지 유입자 수 상위 5%'), ('D2', '평일 오후 혼잡도 보통')]),
  Place('p7', '한림 보리빵 카페', 'hallim', 'cafe', 33.4105, 126.27, indoor: true, rating: 4.3, stay: 50, seafood: false, reasons: [('D3', '장소별 와이파이 방문자 증가 추세'), ('D5', '반경 300m 동일 업종 밀도 낮음')]),
  Place('p8', '수월봉 노을', 'hallim', 'sunset', 33.2955, 126.164, indoor: false, rating: 4.7, stay: 40, seafood: false, reasons: [('D7', '서쪽 시야 트임 · 풍속 약함'), ('D8', '여행장소 좋아요 수 상위')]),
  Place('p9', '한림항 고등어 식당', 'hallim', 'food', 33.417, 126.263, indoor: true, rating: 4.4, stay: 60, seafood: true, reasons: [('D1', '저녁 18~20시 카드 이용 건수 증가'), ('D6', '버스 정류장 120m')]),
  Place('p10', '동문 골목 시장', 'jeju-city', 'food', 33.5122, 126.5281, indoor: true, rating: 4.5, stay: 60, seafood: false, reasons: [('D1', '야간 시간대 카드 이용금액 상위'), ('D6', '정류소 이용객 많은 접근성 1등급')]),
  Place('p11', '탑동 루프탑 카페', 'jeju-city', 'cafe', 33.516, 126.517, indoor: true, rating: 4.2, stay: 50, seafood: false, reasons: [('D3', '20대 와이파이 접속 비중 높음'), ('D2', '외국인 단기체류 유동인구 많음')]),
  Place('p12', '사라봉 노을길', 'jeju-city', 'sunset', 33.5175, 126.545, indoor: false, rating: 4.6, stay: 40, seafood: false, reasons: [('D7', '오늘 일몰 17:38'), ('D2', '현재 혼잡도 낮음')]),
  Place('p13', '제주 책방 골목', 'jeju-city', 'indoor', 33.5095, 126.5165, indoor: true, rating: 4.4, stay: 50, seafood: false, reasons: [('D8', '검색어 트렌드 상승'), ('D7', '실내 대체 장소')]),
  Place('p14', '함덕 해변', 'jocheon', 'spot', 33.5432, 126.6694, indoor: false, rating: 4.8, stay: 60, seafood: false, reasons: [('D4', '관광지 유입자 수 상위'), ('D2', '오전 시간대 혼잡도 낮음')]),
  Place('p15', '조천 해녀 밥상', 'jocheon', 'food', 33.538, 126.633, indoor: true, rating: 4.6, stay: 60, seafood: true, reasons: [('D1', '외식업 메뉴 매출 해산물 비중 상위'), ('자체', '가족 동행 만족도 4.7')]),
  Place('p16', '세화 바다 카페', 'gujwa', 'cafe', 33.525, 126.859, indoor: true, rating: 4.5, stay: 50, seafood: false, reasons: [('D3', '주말 와이파이 방문자 +24%'), ('D5', '최근 개업 점포 생존율 양호 지역')]),
  Place('p17', '월정리 해변', 'gujwa', 'spot', 33.5563, 126.7956, indoor: false, rating: 4.6, stay: 50, seafood: false, reasons: [('D8', '여행장소 좋아요 상위'), ('D2', '현재 혼잡도 보통')]),
  Place('p18', '성산 일출봉', 'seongsan', 'spot', 33.459, 126.9425, indoor: false, rating: 4.9, stay: 80, seafood: false, reasons: [('D4', '외국인 유입자 수 1위 관광지'), ('D2', '오후 늦게 혼잡도 감소')]),
  Place('p19', '광치기 해변 노을', 'seongsan', 'sunset', 33.452, 126.925, indoor: false, rating: 4.7, stay: 40, seafood: false, reasons: [('D7', '오늘 시정 양호'), ('자체', '사진형 성향 평점 4.8')]),
  Place('p20', '성산 갈치 식당', 'seongsan', 'food', 33.464, 126.919, indoor: true, rating: 4.3, stay: 60, seafood: true, reasons: [('D1', '저녁 카드 이용금액 상위'), ('D5', '동일 업종 경쟁 밀도 높음 → 대기 짧은 곳 선별')]),
  Place('p21', '중문 색달 해변', 'jungmun', 'spot', 33.244, 126.412, indoor: false, rating: 4.6, stay: 60, seafood: false, reasons: [('D4', '관광지 유입자 수 상위'), ('D7', '파도 높이 적정')]),
  Place('p22', '중문 아쿠아 체험관', 'jungmun', 'indoor', 33.2525, 126.42, indoor: true, rating: 4.3, stay: 80, seafood: false, reasons: [('D8', '관광상품 구매 데이터 상위'), ('D7', '비 오는 날 대체 장소')]),
  Place('p23', '이중섭 거리', 'seogwipo', 'cafe', 33.247, 126.565, indoor: true, rating: 4.4, stay: 60, seafood: false, reasons: [('D3', '와이파이 방문자 유형: 관광객 비중 72%'), ('D6', '정류장 접근성 우수')]),
  Place('p24', '쇠소깍', 'seogwipo', 'spot', 33.2522, 126.6234, indoor: false, rating: 4.6, stay: 50, seafood: false, reasons: [('D4', '관광지 유입 추세 상승'), ('D2', '현재 혼잡도 낮음')]),
  Place('p25', '서귀포 올레 시장', 'seogwipo', 'food', 33.25, 126.563, indoor: true, rating: 4.5, stay: 60, seafood: true, reasons: [('D1', '야간 카드 이용 건수 상위'), ('자체', '친구 동행 만족도 4.6')]),
  Place('p26', '표선 해비치 해변', 'namwon', 'sunset', 33.326, 126.841, indoor: false, rating: 4.5, stay: 40, seafood: false, reasons: [('D2', '혼잡도 매우 낮음'), ('D8', '축제·행사 기간 연계')]),
  Place('p27', '남원 큰엉 산책길', 'namwon', 'spot', 33.277, 126.711, indoor: false, rating: 4.6, stay: 50, seafood: false, reasons: [('D3', '방문자 증가 추세'), ('D2', '오후 혼잡도 낮음')]),
  Place('p28', '대정 방어 식당', 'daejeong', 'food', 33.217, 126.251, indoor: true, rating: 4.5, stay: 60, seafood: true, reasons: [('D1', '제철(11~2월) 메뉴 매출 급증'), ('자체', '평점 4.5')]),
  Place('p29', '송악산 둘레길', 'daejeong', 'spot', 33.2, 126.29, indoor: false, rating: 4.7, stay: 60, seafood: false, reasons: [('D4', '관광지 유입자 증가'), ('D7', '풍속 확인 필요')]),
  Place('p30', '안덕 숲 카페', 'daejeong', 'cafe', 33.27, 126.35, indoor: true, rating: 4.4, stay: 50, seafood: false, reasons: [('D3', '와이파이 방문 증가'), ('D5', '경쟁 밀도 낮음')]),
];

const kindLabel = {'cafe': '카페', 'spot': '산책·관광', 'sunset': '노을 명소', 'food': '저녁 식사', 'indoor': '실내 체험'};

class Weather {
  const Weather(this.label, this.temp, this.icon, this.note);
  final String label, icon, note;
  final int temp;
}

const weathers = {
  'clear': Weather('맑음', 17, '☀️', '강수 확률 10% · 풍속 3m/s'),
  'rain': Weather('비', 14, '🌧️', '강수 확률 80% · 실내 코스로 전환했어요'),
};
