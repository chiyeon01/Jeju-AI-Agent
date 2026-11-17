// ─────────────────────────────────────────────
// 제주데이터허브 값을 장소 목록에 붙입니다 (웹 src/api/hub.js 와 같은 규칙)
//  - D2 지역 혼잡도: 백엔드 /datahub/crowd
//  - D4 관광지 유입자 수: 백엔드 /datahub/sights
// 허브 데이터는 Main PC(백엔드) 밖으로 나가면 안 되므로,
// 화면에는 숫자를 보여 주되 GPT 프롬프트에는 등급만 넣습니다.
// ─────────────────────────────────────────────
import '../data/tourist_mock.dart';

/// 백엔드가 가공한 허브 값. 둘 다 null 이면 허브를 못 쓰는 상태
class HubData {
  const HubData({this.crowd, this.sights});
  final Map<String, dynamic>? crowd; // {date, regions: {지역id: {index, vsAveragePct}}}
  final Map<String, dynamic>? sights; // {start, items: [{sightsName, domestic, foreign}]}
  bool get isEmpty => crowd == null && sights == null;
}

/// 우리 장소 id → 허브 관광지명에 들어 있는 낱말 (공백을 뺀 이름에서 찾습니다)
const hubAlias = {
  'p2': ['한담'], 'p6': ['협재'], 'p8': ['수월봉'], 'p10': ['동문시장', '동문재래시장'], 'p12': ['사라봉'],
  'p14': ['함덕'], 'p17': ['월정'], 'p18': ['성산일출봉', '일출봉'], 'p19': ['광치기'], 'p21': ['중문', '색달'],
  'p23': ['이중섭'], 'p24': ['쇠소깍'], 'p25': ['올레시장'], 'p26': ['표선'], 'p27': ['큰엉'], 'p29': ['송악산'],
};

String crowdLabel(double index) => index >= 0.67 ? '높음' : index >= 0.34 ? '보통' : '낮음';
String popularityLabel(double rankPct) => rankPct <= 0.1 ? '최상위' : rankPct <= 0.3 ? '상위' : rankPct <= 0.6 ? '보통' : '한산';

String _norm(Object? s) => '${s ?? ''}'.replaceAll(RegExp(r'\s'), '');
int _n(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String _comma(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

(int, double)? _findSight(String id, List items) {
  final alias = hubAlias[id];
  if (alias == null || items.isEmpty) return null;
  int total(Map x) => _n(x['domestic']) + _n(x['foreign']);
  final hits = [for (final x in items) if (x is Map && alias.any((a) => _norm(x['sightsName']).contains(a))) x];
  if (hits.isEmpty) return null;
  final sum = hits.fold<int>(0, (s, x) => s + total(x));
  final all = [for (final x in items) if (x is Map) total(x)]..sort((a, b) => b.compareTo(a));
  var rank = all.indexWhere((v) => v <= sum);
  if (rank < 0) rank = all.length;
  return (sum, rank / (all.isEmpty ? 1 : all.length));
}

/// 장소마다 허브 등급을 붙이고, 허브에서 확인한 근거를 맨 앞에 넣습니다
List<Place> applyHub(List<Place> list, HubData? hub) {
  if (hub == null || hub.isEmpty) return list;
  final regions = (hub.crowd?['regions'] as Map?) ?? const {};
  final items = (hub.sights?['items'] as List?) ?? const [];
  final month = '${hub.sights?['start'] ?? ''}';
  final date = '${hub.crowd?['date'] ?? ''}';
  return [
    for (final p in list)
      () {
        final c = regions[p.region] as Map?;
        final sight = _findSight(p.id, items);
        final idx = (c?['index'] as num?)?.toDouble();
        final pct = (c?['vsAveragePct'] as num?)?.toInt();
        final real = <(String, String)>[
          if (sight != null) ('D4', '허브 $month 방문객 ${_comma(sight.$1)}명 (제주 관광지 중 ${popularityLabel(sight.$2)})'),
          if (idx != null) ('D2', '지역 유동인구 평균 대비 ${(pct ?? 0) >= 0 ? '+' : ''}${pct ?? 0}% · 혼잡도 ${crowdLabel(idx)} ($date)'),
        ];
        if (real.isEmpty) return p;
        return p.withHub(
            crowd: idx == null ? null : crowdLabel(idx),
            popularity: sight == null ? null : popularityLabel(sight.$2),
            hubReasons: real);
      }(),
  ];
}

/// 허브 연결 상태를 화면용 한 줄로 (없으면 null)
String? hubLine(HubData? hub) {
  if (hub == null || hub.isEmpty) return null;
  return '제주데이터허브 반영: ${[
    if (hub.crowd != null) '지역 혼잡도 ${hub.crowd!['date']}',
    if (hub.sights != null) '관광지 방문객 ${hub.sights!['start']}',
  ].join(' · ')}';
}

/// GPT 프롬프트용: 어느 날짜의 허브 값인지
String hubText(HubData? hub) {
  if (hub == null || hub.isEmpty) return '제주데이터허브 값을 불러오지 못했어요. 혼잡도·인기도 칸은 비어 있어요';
  return '${[
    if (hub.crowd != null) '지역 혼잡도는 ${hub.crowd!['date']} 유동인구 기준',
    if (hub.sights != null) '관광지 인기도는 ${hub.sights!['start']} 방문객 수 기준',
  ].join(', ')} (제주데이터허브)';
}
