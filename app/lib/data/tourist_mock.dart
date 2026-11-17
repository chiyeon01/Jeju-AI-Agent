// ─────────────────────────────────────────────
// 관광객 화면용 목업 데이터 (React 의 src/mock/tourist.js 와 같은 내용)
// 실제 서비스에서는 FastAPI 의 성향 분석 / 코스 플래너 Agent 응답으로 대체됩니다.
// ─────────────────────────────────────────────
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
  Question('space', '저녁 시간을 보낼 곳은?', Choice('🌅', '노을 지는 포구 방파제'), Choice('🍸', '분위기 좋은 시내 루프탑')),
];

const _adj = {'N-P': '노을 감성', 'N-F': '해녀밥상', 'C-P': '골목 사진', 'C-F': '핫플 미식'};
const _noun = {'A-J': '탐험가', 'A-S': '모험가', 'H-J': '산책가', 'H-S': '여행자'};
const _typeDesc = {
  '노을 감성': '바다와 하늘이 바뀌는 순간을 좋아합니다. 해 지는 시간에 맞춰 코스를 짭니다.',
  '해녀밥상': '바다 가까운 곳에서 제철 음식을 먹는 것이 여행의 이유입니다.',
  '골목 사진': '오래된 돌담길과 작은 가게 사이에서 장면을 찾습니다.',
  '핫플 미식': '요즘 뜨는 식당과 카페를 먼저 알아보고 찾아갑니다.',
};

/// 여행 정보: 동행 · 이동 수단(여러 개) · 여행 시작·끝 시각
class TripExtra {
  const TripExtra({this.companion = '연인', this.transports = const ['자동차'], this.startTime = '10:00', this.endTime, this.hours = 8});
  final String companion, startTime;

  /// 여행 끝 시각 (예전 기록에는 없을 수 있어요)
  final String? endTime;
  final List<String> transports;
  final int hours;

  /// 화면·서버에 보내는 이동 수단 글자 (예: 자동차·버스)
  String get transport => transports.join('·');

  TripExtra copyWith({String? companion, List<String>? transports, String? startTime, String? endTime, int? hours}) => TripExtra(
    companion: companion ?? this.companion,
    transports: transports ?? this.transports,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    hours: hours ?? this.hours,
  );

  Map<String, dynamic> toJson() => {
    'companion': companion,
    'transport': transport,
    'transports': transports,
    'startTime': startTime,
    if (endTime != null) 'endTime': endTime,
    'hours': hours,
  };

  /// 예전 '렌터카'·'대중교통' 도 새 선택지로 바꿔 읽습니다
  static List<String> parseTransports(Map<String, dynamic> j) => _parseTransports(j);
}

List<String> _parseTransports(Map<String, dynamic> j) {
  final raw = j['transports'] is List ? [for (final t in j['transports'] as List) '$t'] : '${j['transport'] ?? ''}'.split(RegExp(r'[·,\s]+'));
  final mapped = {
    for (final t in raw)
      t == '렌터카'
          ? '자동차'
          : t == '대중교통'
          ? '버스'
          : t,
  }.where(transports.contains);
  return mapped.isEmpty
      ? const ['자동차']
      : [
          for (final t in transports)
            if (mapped.contains(t)) t,
        ];
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
  String get startTime => extra.startTime;
  String? get endTime => extra.endTime;

  Profile withExtra(TripExtra e) => Profile(code: code, name: name, desc: desc, scores: scores, tags: tags, extra: e);

  Map<String, dynamic> toJson() => {'code': code, 'name': name, 'desc': desc, 'scores': scores, 'tags': tags, ...extra.toJson()};

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    code: j['code'],
    name: j['name'],
    desc: j['desc'] ?? '',
    scores: Map<String, int>.from((j['scores'] as Map).map((k, v) => MapEntry(k as String, (v as num).round()))),
    tags: List<String>.from(j['tags'] ?? const []),
    extra: TripExtra(
      companion: j['companion'] ?? '연인',
      transports: TripExtra.parseTransports(j),
      startTime: j['startTime'] ?? '10:00',
      endTime: j['endTime'] as String?,
      hours: (j['hours'] as num?)?.toInt() ?? 8,
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
    tags: [code[0] == 'A' ? '#체험' : '#휴식', code[1] == 'N' ? '#바다' : '#골목', code[2] == 'F' ? '#로컬맛집' : '#뷰포인트', code[3] == 'J' ? '#촘촘한일정' : '#여유시간'],
    extra: extra,
  );
}

const companions = ['연인', '친구', '가족', '혼자'];
const transports = ['자동차', '택시', '버스', '배'];

/// 지역 (읍면동 묶음, 위도·경도는 대표 지점)
class Region {
  const Region(this.id, this.name, this.lat, this.lon);
  final String id, name;
  final double lat, lon;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'lat': lat, 'lon': lon};
  factory Region.fromJson(Map<String, dynamic> j) => Region(j['id'], j['name'], (j['lat'] as num).toDouble(), (j['lon'] as num).toDouble());
}

const regions = [
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
  const Place(
    this.id,
    this.name,
    this.region,
    this.kind,
    this.lat,
    this.lon, {
    required this.indoor,
    required this.rating,
    required this.stay,
    this.seafood = false,
    required this.reasons,
    this.crowd,
    this.popularity,
    this.hubReasons = 0,
    this.addr = '',
    this.label,
    this.tags = const [],
  });
  final String id, name, region, kind;

  /// 읍·면·동 (같은 이름의 다른 곳과 구별)
  final String addr;

  /// 미술관·기념품샵 등 화면에 보일 종류 (없으면 kind 이름)
  final String? label;

  /// 대화 요청("미술관 넣어줘")에 맞는 장소를 찾을 때 씁니다
  final List<String> tags;

  String get kindName => label ?? kindLabel[kind] ?? kind;
  final double lat, lon;
  final bool indoor, seafood;
  final double rating;
  final int stay; // 머무는 시간(분)
  final List<(String, String)> reasons; // (데이터 출처, 근거)

  /// 제주데이터허브 등급 (지역 혼잡도: 낮음/보통/높음, 관광지 인기도: 최상위/상위/보통/한산). 없으면 null
  final String? crowd, popularity;

  /// reasons 맨 앞에서 허브 숫자가 들어간 근거 개수 (GPT 프롬프트에서는 뺍니다)
  final int hubReasons;

  Place withReasons(List<(String, String)> r) => Place(
    id,
    name,
    region,
    kind,
    lat,
    lon,
    indoor: indoor,
    rating: rating,
    stay: stay,
    seafood: seafood,
    reasons: r,
    crowd: crowd,
    popularity: popularity,
    hubReasons: hubReasons,
    addr: addr,
    label: label,
    tags: tags,
  );

  Place withHub({String? crowd, String? popularity, required List<(String, String)> hubReasons}) {
    final kept = [
      for (final r in reasons)
        if (!hubReasons.any((h) => h.$1 == r.$1)) r,
    ];
    return Place(
      id,
      name,
      region,
      kind,
      lat,
      lon,
      indoor: indoor,
      rating: rating,
      stay: stay,
      seafood: seafood,
      reasons: [...hubReasons, ...kept],
      crowd: crowd,
      popularity: popularity,
      hubReasons: hubReasons.length,
      addr: addr,
      label: label,
      tags: tags,
    );
  }

  factory Place.fromJson(Map<String, dynamic> m) => Place(
    m['id'],
    m['name'],
    m['region'] ?? '',
    m['kind'] ?? 'spot',
    (m['lat'] as num).toDouble(),
    (m['lon'] as num).toDouble(),
    indoor: m['indoor'] ?? false,
    rating: (m['rating'] as num?)?.toDouble() ?? 0,
    stay: (m['stay'] as num?)?.toInt() ?? 0,
    seafood: m['seafood'] ?? false,
    reasons: [for (final r in (m['reasons'] as List? ?? const [])) ('${r[0]}', '${r[1]}')],
    addr: m['addr'] ?? '',
    label: m['label'] as String?,
    tags: [for (final t in (m['tags'] as List? ?? const [])) '$t'],
  );
}

/// 실제로 있는 제주 장소 (이름 + 읍·면·동으로 한 곳이 특정됩니다. 위도·경도는 지도 표시용 대략값)
const places = [
  Place('p1', '봄날카페', 'aewol', 'cafe', 33.4627, 126.3097, addr: '제주시 애월읍 애월리', indoor: true, rating: 4.5, stay: 60, seafood: false, tags: ['바다뷰', '카페'], reasons: [('소개', '한담 해안 바로 앞, 바다가 보이는 카페')]),
  Place('p2', '한담해안산책로', 'aewol', 'spot', 33.4614, 126.3118, addr: '제주시 애월읍 애월리', indoor: false, rating: 4.7, stay: 50, seafood: false, tags: ['산책', '바다'], reasons: [('소개', '애월 바닷가를 따라 걷는 1.2km 해안 산책로')]),
  Place('p3', '곽지해수욕장', 'aewol', 'sunset', 33.4507, 126.3049, addr: '제주시 애월읍 곽지리', indoor: false, rating: 4.6, stay: 45, seafood: false, tags: ['해변', '노을'], reasons: [('소개', '서쪽 바다로 해가 지는 모래 해변')]),
  Place('p4', '애월연어', 'aewol', 'food', 33.4645, 126.3192, addr: '제주시 애월읍 애월리', indoor: true, rating: 4.4, stay: 60, seafood: true, tags: ['연어', '해산물'], reasons: [('소개', '연어 덮밥·회를 파는 애월 식당')]),
  Place('p5', '아르떼뮤지엄 제주', 'aewol', 'indoor', 33.3963, 126.3448, addr: '제주시 애월읍 어림비로', indoor: true, rating: 4.6, stay: 80, seafood: false, label: '미디어아트 전시관', tags: ['미술관', '전시', '미디어아트'], reasons: [('소개', '옛 공장을 고친 몰입형 미디어아트 전시관')]),
  Place('p6', '협재해수욕장', 'hallim', 'spot', 33.394, 126.2396, addr: '제주시 한림읍 협재리', indoor: false, rating: 4.8, stay: 60, seafood: false, tags: ['해변', '바다'], reasons: [('소개', '비양도가 보이는 에메랄드빛 얕은 해변')]),
  Place('p7', '앤트러사이트 제주 한림점', 'hallim', 'cafe', 33.4117, 126.2693, addr: '제주시 한림읍 한림로', indoor: true, rating: 4.4, stay: 50, seafood: false, tags: ['카페', '공장 개조'], reasons: [('소개', '옛 전분 공장을 고친 커피 로스터리')]),
  Place('p8', '수월봉', 'hallim', 'sunset', 33.2956, 126.1628, addr: '제주시 한경면 고산리', indoor: false, rating: 4.7, stay: 40, seafood: false, tags: ['노을', '지질공원'], reasons: [('소개', '서쪽 끝 해안 절벽, 노을 명소')]),
  Place('p9', '한림칼국수 제주본점', 'hallim', 'food', 33.4129, 126.2586, addr: '제주시 한림읍 한림리', indoor: true, rating: 4.3, stay: 50, seafood: true, tags: ['보말칼국수', '해산물'], reasons: [('소개', '보말칼국수로 알려진 한림 식당')]),
  Place('p10', '동문재래시장', 'jeju-city', 'food', 33.5121, 126.5262, addr: '제주시 관덕로14길', indoor: true, rating: 4.5, stay: 60, seafood: true, tags: ['시장', '회', '기념품'], reasons: [('소개', '제주 최대 상설시장, 회·먹거리·기념품')]),
  Place('p11', '카페 델문도', 'jocheon', 'cafe', 33.5434, 126.6687, addr: '제주시 조천읍 함덕리', indoor: true, rating: 4.5, stay: 50, seafood: false, tags: ['바다뷰', '카페'], reasons: [('소개', '함덕 해변 바로 옆 바다 카페')]),
  Place('p12', '사라봉공원', 'jeju-city', 'sunset', 33.5176, 126.545, addr: '제주시 건입동', indoor: false, rating: 4.5, stay: 40, seafood: false, tags: ['노을', '산책'], reasons: [('소개', '제주항과 바다 너머 노을을 보는 오름 공원')]),
  Place('p13', '국립제주박물관', 'jeju-city', 'indoor', 33.5133, 126.5491, addr: '제주시 일주동로', indoor: true, rating: 4.5, stay: 70, seafood: false, label: '박물관', tags: ['박물관', '전시'], reasons: [('소개', '제주 역사·문화를 보여 주는 국립박물관')]),
  Place('p14', '함덕해수욕장', 'jocheon', 'spot', 33.5432, 126.6694, addr: '제주시 조천읍 함덕리', indoor: false, rating: 4.8, stay: 60, seafood: false, tags: ['해변', '바다'], reasons: [('소개', '서우봉 옆 얕고 맑은 해변')]),
  Place('p15', '도두해녀의집', 'jeju-city', 'food', 33.506, 126.466, addr: '제주시 도두일동', indoor: true, rating: 4.3, stay: 60, seafood: true, tags: ['물회', '해산물'], reasons: [('소개', '해녀가 운영하는 물회 식당')]),
  Place('p16', '풍림다방 송당점', 'gujwa', 'cafe', 33.4708, 126.7822, addr: '제주시 구좌읍 송당리', indoor: true, rating: 4.5, stay: 50, seafood: false, tags: ['카페', '감성'], reasons: [('소개', '송당 마을의 작은 감성 카페')]),
  Place('p17', '월정리해변', 'gujwa', 'spot', 33.5563, 126.7956, addr: '제주시 구좌읍 월정리', indoor: false, rating: 4.6, stay: 50, seafood: false, tags: ['해변', '카페거리'], reasons: [('소개', '카페가 늘어선 하얀 모래 해변')]),
  Place('p18', '성산일출봉', 'seongsan', 'spot', 33.4581, 126.9425, addr: '서귀포시 성산읍 성산리', indoor: false, rating: 4.8, stay: 80, seafood: false, tags: ['오름', '유네스코'], reasons: [('소개', '유네스코 세계자연유산 화산 분화구')]),
  Place('p19', '섭지코지', 'seongsan', 'sunset', 33.4243, 126.9306, addr: '서귀포시 성산읍 고성리', indoor: false, rating: 4.6, stay: 50, seafood: false, tags: ['해안', '풍경'], reasons: [('소개', '성산일출봉이 보이는 해안 언덕')]),
  Place('p20', '맛나식당', 'seongsan', 'food', 33.4627, 126.9332, addr: '서귀포시 성산읍 성산리', indoor: true, rating: 4.4, stay: 50, seafood: true, tags: ['갈치조림', '해산물'], reasons: [('소개', '갈치·고등어조림으로 알려진 성산 식당')]),
  Place('p21', '중문색달해수욕장', 'jungmun', 'spot', 33.2445, 126.412, addr: '서귀포시 색달동', indoor: false, rating: 4.6, stay: 60, seafood: false, tags: ['해변', '서핑'], reasons: [('소개', '파도가 좋아 서핑을 많이 하는 해변')]),
  Place('p22', '테디베어뮤지엄 제주', 'jungmun', 'indoor', 33.2497, 126.4123, addr: '서귀포시 중문관광로', indoor: true, rating: 4.3, stay: 70, seafood: false, label: '박물관', tags: ['박물관', '전시', '아이'], reasons: [('소개', '테디베어 전시관, 아이와 가기 좋은 실내')]),
  Place('p23', '허니문하우스', 'seogwipo', 'cafe', 33.2436, 126.5806, addr: '서귀포시 토평동', indoor: true, rating: 4.5, stay: 50, seafood: false, tags: ['바다뷰', '카페'], reasons: [('소개', '소정방폭포 위 절벽의 바다 카페')]),
  Place('p24', '쇠소깍', 'seogwipo', 'spot', 33.2522, 126.6234, addr: '서귀포시 하효동', indoor: false, rating: 4.6, stay: 50, seafood: false, tags: ['계곡', '카약'], reasons: [('소개', '민물과 바다가 만나는 계곡, 투명카약')]),
  Place('p25', '서귀포매일올레시장', 'seogwipo', 'food', 33.2497, 126.5636, addr: '서귀포시 중앙로62번길', indoor: true, rating: 4.5, stay: 60, seafood: true, tags: ['시장', '회', '기념품'], reasons: [('소개', '서귀포 상설시장, 회·먹거리·기념품')]),
  Place('p26', '표선해수욕장', 'namwon', 'sunset', 33.3264, 126.8414, addr: '서귀포시 표선면 표선리', indoor: false, rating: 4.5, stay: 40, seafood: false, tags: ['해변', '산책'], reasons: [('소개', '넓은 백사장이 펼쳐지는 해변')]),
  Place('p27', '큰엉해안경승지', 'namwon', 'spot', 33.277, 126.711, addr: '서귀포시 남원읍 남원리', indoor: false, rating: 4.6, stay: 50, seafood: false, tags: ['해안', '산책'], reasons: [('소개', '한반도 모양 숲길로 알려진 해안 절벽 산책로')]),
  Place('p28', '부두식당', 'daejeong', 'food', 33.2172, 126.2507, addr: '서귀포시 대정읍 하모리', indoor: true, rating: 4.4, stay: 60, seafood: true, tags: ['방어', '해산물'], reasons: [('소개', '모슬포항 방어회 식당 (제철 11~2월)')]),
  Place('p29', '송악산', 'daejeong', 'spot', 33.1997, 126.2895, addr: '서귀포시 대정읍 상모리', indoor: false, rating: 4.7, stay: 60, seafood: false, tags: ['오름', '둘레길'], reasons: [('소개', '마라도·형제섬이 보이는 해안 둘레길')]),
  Place('p30', '오설록 티뮤지엄', 'daejeong', 'cafe', 33.3059, 126.2895, addr: '서귀포시 안덕면 서광리', indoor: true, rating: 4.5, stay: 60, seafood: false, tags: ['녹차', '카페'], reasons: [('소개', '녹차밭 옆 차 박물관 겸 카페')]),
  Place('p31', '제주도립미술관', 'jeju-city', 'indoor', 33.4524, 126.489, addr: '제주시 1100로', indoor: true, rating: 4.5, stay: 70, seafood: false, label: '미술관', tags: ['미술관', '전시'], reasons: [('소개', '제주 작가와 기획전을 볼 수 있는 도립 미술관')]),
  Place('p32', '이중섭미술관', 'seogwipo', 'indoor', 33.2468, 126.5652, addr: '서귀포시 서귀동', indoor: true, rating: 4.4, stay: 50, seafood: false, label: '미술관', tags: ['미술관', '전시'], reasons: [('소개', '화가 이중섭이 살던 곳 옆 미술관')]),
  Place('p33', '제주도립 김창열미술관', 'hallim', 'indoor', 33.336, 126.269, addr: '제주시 한경면 저지리', indoor: true, rating: 4.5, stay: 60, seafood: false, label: '미술관', tags: ['미술관', '전시'], reasons: [('소개', '물방울 작가 김창열의 미술관')]),
  Place('p34', '본태박물관', 'daejeong', 'indoor', 33.3008, 126.393, addr: '서귀포시 안덕면 상천리', indoor: true, rating: 4.5, stay: 70, seafood: false, label: '미술관', tags: ['미술관', '박물관', '건축'], reasons: [('소개', '안도 다다오가 설계한 미술관·박물관')]),
  Place('p35', '아라리오뮤지엄 탑동시네마', 'jeju-city', 'indoor', 33.5161, 126.5199, addr: '제주시 탑동로', indoor: true, rating: 4.4, stay: 60, seafood: false, label: '미술관', tags: ['미술관', '전시'], reasons: [('소개', '옛 극장을 고친 현대미술관')]),
  Place('p36', '이니스프리 제주하우스', 'daejeong', 'indoor', 33.3054, 126.2884, addr: '서귀포시 안덕면 서광리', indoor: true, rating: 4.3, stay: 30, seafood: false, label: '기념품샵', tags: ['기념품', '소품샵', '쇼핑'], reasons: [('소개', '오설록 옆, 제주 한정 기념품·화장품 가게')]),
  Place('p37', '소심한책방', 'gujwa', 'indoor', 33.4911, 126.898, addr: '제주시 구좌읍 종달리', indoor: true, rating: 4.5, stay: 30, seafood: false, label: '소품샵', tags: ['기념품', '소품샵', '책방'], reasons: [('소개', '종달리 마을의 작은 책방 겸 소품샵')]),
];

const kindLabel = {'cafe': '카페', 'spot': '산책·관광', 'sunset': '노을 명소', 'food': '저녁 식사', 'indoor': '실내 체험'};

class Weather {
  const Weather(this.label, this.temp, this.icon, this.note);
  final String label, icon, note;
  final int temp;
}

const weathers = {'clear': Weather('맑음', 17, '☀️', '강수 확률 10% · 풍속 3m/s'), 'rain': Weather('비', 14, '🌧️', '강수 확률 80% · 실내 코스로 전환했어요')};
