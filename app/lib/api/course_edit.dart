// ─────────────────────────────────────────────
// 백엔드 대화 API(/tourist/course/chat)가 못 하는 코스 수정을 앱에서 직접 처리합니다 (웹 src/api/courseEdit.js 와 같은 규칙).
// 백엔드는 "해산물로 / 줄이기 / 실내로" 세 가지만 바꿀 수 있어서,
// "코스를 더 늘려줘", "카페 하나 더 넣어줘" 같은 요청은 여기서 장소를 골라 넣습니다.
// ─────────────────────────────────────────────
import '../data/tourist_mock.dart';
import 'client.dart';
import 'hub.dart';
import 'planner.dart';

const maxStops = 7;

const _kindWords = [
  ('cafe', r'카페|커피|디저트|브런치|빵'),
  ('sunset', r'노을|일몰|석양|해\s*질'),
  ('food', r'식당|맛집|밥|저녁|점심|먹을|먹고|음식'),
  ('indoor', r'실내\s*체험|체험|박물관|전시|공방'),
  ('spot', r'산책|해변|바다|관광|오름|걷|명소|구경'),
];
const _numWords = {'한': 1, '하나': 1, '두': 2, '둘': 2, '세': 3, '셋': 3};

// 하루 흐름: 낮(카페·산책·실내) → 노을 → 저녁 식사
const _phase = {'cafe': 0, 'spot': 0, 'indoor': 0, 'sunset': 1, 'food': 2};
int _ph(String kind) => _phase[kind] ?? 0;

const _addedReason = ('요청', '대화로 추가한 장소예요');

/// "늘려줘 / 추가 / 하나 더 / 넣어줘" 류인지. 해산물·줄이기·실내 전환은 백엔드가 처리하므로 제외
bool isAddRequest(String message) {
  final m = message.replaceAll(RegExp(r'\s+'), ' ');
  if (RegExp(r'해산물|회로|바다\s*음식|줄여|빼|실내로\s*바꿔').hasMatch(m)) return false;
  return RegExp(r'늘려|늘리|추가|더\s*넣|넣어|하나\s*더|한\s*곳\s*더|\d+\s*곳\s*더|더\s*가고|더\s*많이|더\s*추천').hasMatch(m);
}

int _wantedCount(String m) {
  final n = RegExp(r'(\d+)\s*(곳|개|군데)').firstMatch(m);
  if (n != null) return int.parse(n.group(1)!).clamp(1, 3);
  final w = RegExp(r'(한|하나|두|둘|세|셋)\s*(곳|개|군데)?').firstMatch(m);
  return w != null && RegExp(r'곳|개|군데|더').hasMatch(m) ? _numWords[w.group(1)] ?? 1 : 1;
}

String? _wantedKind(String m) {
  for (final (k, re) in _kindWords) {
    if (RegExp(re).hasMatch(m)) return k;
  }
  return null;
}

/// 장소를 시간 흐름에 맞는 자리에 끼워 넣습니다 (예: 카페는 노을·저녁 앞에)
List<Place> insertPlaces(List<Place> stops, List<Place> add) {
  final out = [...stops];
  for (final p in add) {
    if (out.any((s) => s.id == p.id)) continue;
    final at = out.indexWhere((s) => _ph(s.kind) > _ph(p.kind));
    out.insert(at < 0 ? out.length : at, p);
  }
  return out;
}

double _dist(Place a, Place b) => kmBetween(a.lat, a.lon, b.lat, b.lon);

List<Place> _pick(List<Place> stops, {required int count, String? kind, required bool rain, HubData? hub}) {
  final all = applyHub(places, hub);
  final used = {for (final s in stops) s.id};
  final picked = <Place>[];
  for (var i = 0; i < count; i++) {
    final cur = insertPlaces(stops, picked);
    int kindCount(String k) => cur.where((s) => s.kind == k).length;
    Place? anchorFor(Place p) {
      final at = cur.indexWhere((s) => _ph(s.kind) > _ph(p.kind));
      final idx = (at < 0 ? cur.length : at) - 1;
      return idx >= 0 ? cur[idx] : (cur.isEmpty ? null : cur.first);
    }

    // 종류를 말하지 않았으면: 저녁 식사가 없을 때는 식당부터, 있으면 코스에 적은 종류(식당 제외)
    final k = kind ?? (kindCount('food') == 0 ? 'food' : null);
    final pool = [
      for (final p in all)
        if (!used.contains(p.id) && !picked.any((x) => x.id == p.id) && (k != null ? p.kind == k : p.kind != 'food') && (!rain || p.indoor || kind != null)) p,
    ];
    if (pool.isEmpty) break;
    double score(Place p) {
      final a = anchorFor(p);
      return (a == null ? 0 : _dist(a, p)) + (k != null ? 0 : kindCount(p.kind) * 4) - p.rating * 2;
    }

    pool.sort((a, b) => score(a).compareTo(score(b)));
    picked.add(pool.first);
  }
  return picked;
}

String _end(List<Stop> stops) {
  final last = stops.last;
  final p = last.at.split(':').map(int.parse).toList();
  final t = p[0] * 60 + p[1] + last.place.stay;
  return '${(t ~/ 60 % 24).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}';
}

String _lateSunset(List<Stop> stops) {
  final s = stops.where((x) => x.place.kind == 'sunset').firstOrNull;
  if (s == null) return '';
  final p = s.at.split(':').map(int.parse).toList();
  return p[0] * 60 + p[1] >= 19 * 60 ? " 다만 '${s.place.name}' 도착이 ${s.at}라 해가 진 뒤일 수 있어요. 하나 빼고 싶으면 \"1곳 줄여줘\"라고 해 주세요." : '';
}

/// 결과. course 가 null 이면 코스는 그대로
class AddResult {
  const AddResult(this.reply, this.course, this.added);
  final String reply;
  final Course? course;
  final List<String> added;
}

/// "코스를 더 늘려줘" 같은 요청을 처리합니다. 해당 요청이 아니면 null
AddResult? addToCourse(String message, Course course, {required String startTime, bool rain = false, HubData? hub}) {
  if (!isAddRequest(message)) return null;
  final room = maxStops - course.stops.length;
  if (room <= 0) return AddResult('지금 ${course.stops.length}곳이라 더 넣으면 하루에 다 돌기 어려워요. 하나를 빼고 바꿔 볼까요?', null, const []);
  final kind = _wantedKind(message);
  final picked = [
    for (final p in _pick([for (final s in course.stops) s.place], count: _wantedCount(message).clamp(1, room), kind: kind, rain: rain, hub: hub))
      p.withReasons([_addedReason, ...p.reasons]),
  ];
  if (picked.isEmpty) {
    return AddResult('${kind != null ? '${kindLabel[kind]} 중에는 ' : ''}더 넣을 만한 곳을 찾지 못했어요. 다른 종류로 말해 주세요.', null, const []);
  }
  final whyById = {for (final s in course.stops) s.place.id: s.why};
  final merged = insertPlaces([for (final s in course.stops) s.place], picked);
  final stops = schedule([for (final p in merged) (p, whyById[p.id])], startTime);
  final names = picked.map((p) => "'${p.name}'").join(', ');
  return AddResult('$names 추가했어요. 이제 ${stops.length}곳을 도는 코스이고, ${_end(stops)}쯤 끝나요.${_lateSunset(stops)}',
      Course(course.weather, stops, summary: course.summary, source: course.source), [for (final p in picked) p.id]);
}

/// 백엔드가 코스를 다시 짠 뒤에도 대화로 추가한 장소를 유지합니다
List<Stop> keepAdded(List<Stop> stops, List<String> addedIds, String startTime) {
  if (addedIds.isEmpty) return stops;
  final byId = {for (final p in places) p.id: p};
  final extra = [for (final id in addedIds) if (byId[id] != null) byId[id]!.withReasons([_addedReason, ...byId[id]!.reasons])];
  final whyById = {for (final s in stops) s.place.id: s.why};
  final merged = insertPlaces([for (final s in stops) s.place], extra).take(maxStops).toList();
  return schedule([for (final p in merged) (p, whyById[p.id])], startTime);
}
