// ─────────────────────────────────────────────
// 코스 플래너 (GPT) — 웹 src/api/planner.js 와 같은 구조
//  - planCourseAI : 성향 + 실시간 날씨 + 출발 지역 → GPT 가 후보 장소 중에서 코스를 짭니다
//  - chatCourseAI : 지금 코스 + 대화 기록 + 사용자 말 → GPT 가 코스를 고칩니다
// 프롬프트 문장은 assets/prompts/*.md 에 있습니다.
// GPT 가 고르는 건 장소 id 와 이유뿐이고, 도착 시각·이동 시간은 여기서 계산합니다.
// GPT 를 쓸 수 없으면 null 을 돌려주고, 화면은 기존 planCourse / chatCourse 로 대신합니다.
// ─────────────────────────────────────────────
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/tourist_mock.dart';
import '../prompts/prompts.dart';
import 'client.dart';
import 'gpt.dart';
import 'hub.dart';
import 'weather.dart';

const _candidateLimit = 18;
final _rand = math.Random();

double _km(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0, rad = math.pi / 180;
  final dLat = (lat2 - lat1) * rad, dLon = (lon2 - lon1) * rad;
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(lat1 * rad) * math.cos(lat2 * rad) * math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.sqrt(h));
}

// 직선거리(km) × 1.3(도로 보정) ÷ 평균 35km/h + 주차·도보 4분
int _move(Place a, Place b) => math.max(5, (_km(a.lat, a.lon, b.lat, b.lon) * 1.3 / 35 * 60 + 4).round());
String _fmt(int x) => '${(x ~/ 60 % 24).toString().padLeft(2, '0')}:${(x % 60).toString().padLeft(2, '0')}';
int _min(String hm) {
  final p = hm.split(':').map(int.parse).toList();
  return p[0] * 60 + p[1];
}

/// 장소 목록에 도착 시각·이동 시간을 붙입니다
List<Stop> schedule(List<(Place, String?)> stops, String startTime) {
  var t = _min(startTime);
  final out = <Stop>[];
  for (var i = 0; i < stops.length; i++) {
    final (p, why) = stops[i];
    final move = i == 0 ? 0 : _move(stops[i - 1].$1, p);
    t += move;
    out.add(Stop(p, _fmt(t), move, why: why));
    t += p.stay;
  }
  return out;
}

// 출발지에서 가까운 순 + 종류별로 고르게 + 비가 오면 실내를 더해 GPT 가 고를 후보를 만듭니다
// all 은 허브 값(혼잡도·방문객)을 붙인 장소 목록입니다
List<Place> _candidates(List<Place> all, Region origin, bool rain, [List<String> keep = const []]) {
  final byId = {for (final p in all) p.id: p};
  double d(Place p) => _km(p.lat, p.lon, origin.lat, origin.lon);
  final near = [...all]..sort((a, b) => d(a).compareTo(d(b)));
  final out = <String, Place>{for (final id in keep) if (byId[id] != null) id: byId[id]!};
  final byKind = <String, List<Place>>{};
  for (final p in near) {
    byKind.putIfAbsent(p.kind, () => []).add(p);
  }
  for (var i = 0; out.length < _candidateLimit && i < 10; i++) {
    for (final list in byKind.values) {
      if (i < list.length && out.length < _candidateLimit) out[list[i].id] = list[i];
    }
  }
  if (rain) {
    for (final p in near.where((x) => x.indoor).take(6)) {
      out[p.id] = p;
    }
  }
  return out.values.toList();
}

String _table(List<Place> list, Region origin) => [
      for (final p in list)
        '| ${p.id} | ${p.name} | ${kindLabel[p.kind]} | ${p.indoor ? '실내' : '야외'} | ${p.rating} | ${p.stay} | '
            '${_km(p.lat, p.lon, origin.lat, origin.lon).toStringAsFixed(1)} | ${p.seafood ? '예' : '-'} | '
            '${p.crowd ?? '-'} | ${p.popularity ?? '-'} | '
            '${p.reasons.skip(p.hubReasons).map((r) => '${r.$1}: ${r.$2}').join(' / ')} |',
    ].join('\n');

String _profileText(Profile p) => [
      '- 유형: ${p.name} (${p.code})',
      if (p.desc.isNotEmpty) '- 설명: ${p.desc}',
      if (p.tags.isNotEmpty) '- 태그: ${p.tags.join(' ')}',
      '- 축 점수(음수=왼쪽, 양수=오른쪽): 활동성 ${p.scores['act'] ?? 0}, 공간 ${p.scores['space'] ?? 0}, 취향 ${p.scores['taste'] ?? 0}, 스타일 ${p.scores['style'] ?? 0}',
      '- 동행: ${p.companion} · 이동수단: ${p.transport}',
    ].join('\n');

/// 화면이 쓰는 날씨(코드 + 실시간 값)를 GPT 용 한 줄로
String weatherText(String code, LiveWeather? live) {
  final indoor = code == 'rain' && live?.code != 'rain' ? ' · 여행자가 실내 위주로 바꿔 달라고 했어요' : '';
  if (live != null) {
    String n(double? v) => v == null ? '?' : fmtNum(v);
    return '${live.label} ${n(live.temp)}°C, 습도 ${n(live.humidity)}%, 풍속 ${n(live.wind)}m/s, 1시간 강수 ${n(live.rain1h)}mm (${live.source} 실시간)$indoor';
  }
  return '실시간 날씨를 불러오지 못했어요. 날씨를 단정하지 말고 실내·야외를 섞어 줘$indoor';
}

const _variations = [
  '이번에는 덜 알려진 곳을 하나 넣어 봐', '이번에는 평점이 높은 곳 위주로', '이번에는 이동 거리를 최대한 짧게',
  '이번에는 사진 찍기 좋은 곳을 하나 더', '이번에는 현지인이 갈 법한 곳을 섞어서', '이번에는 마지막을 인상적인 곳으로',
];

Future<String> _context(Profile profile, Region origin, String weather, LiveWeather? live, HubData? hub, String startTime, List<Place> list) {
  final k = DateTime.now().toUtc().add(const Duration(hours: 9));
  String p2(int n) => n.toString().padLeft(2, '0');
  return renderPrompt('context', {
    'today': '${k.year}-${p2(k.month)}-${p2(k.day)}',
    'now': '${p2(k.hour)}:${p2(k.minute)}',
    'origin': '${origin.name} (위도 ${origin.lat}, 경도 ${origin.lon})',
    'start_time': startTime,
    'hours': '${profile.extra.hours}시간',
    'weather': weatherText(weather, live),
    'hub': hubText(hub),
    'profile': _profileText(profile),
    'candidates': _table(list, origin),
  });
}

// GPT 가 준 stops 검증: 후보에 있는 id 만, 중복 없이
List<(Place, String?)> _toStops(Object? raw, List<Place> list) {
  final allowed = {for (final p in list) p.id};
  final byId = {for (final p in list) p.id: p};
  final seen = <String>{};
  final out = <(Place, String?)>[];
  for (final s in raw is List ? raw : const []) {
    if (s is! Map) continue;
    final id = '${s['id'] ?? ''}'.trim();
    if (!allowed.contains(id) || !seen.add(id)) continue;
    final why = '${s['why'] ?? ''}'.trim();
    out.add((byId[id]!, why.isEmpty ? null : why));
  }
  return out;
}

// 이용 시간 안에 끝나도록 뒤쪽 장소를 뺍니다 (최소 2곳)
List<(Place, String?)> _fit(List<(Place, String?)> stops, String startTime, int hours) {
  final end = _min(startTime) + hours * 60;
  final timed = schedule(stops, startTime);
  var keep = 0;
  for (var i = 0; i < timed.length; i++) {
    var t = _min(timed[i].at);
    if (t < _min(startTime)) t += 24 * 60;
    if (i < 2 || t + timed[i].place.stay <= end) keep = i + 1;
  }
  return stops.sublist(0, keep);
}

/// 처음 코스. GPT 를 못 쓰면 null
Future<Course?> planCourseAI(
    {required Profile profile, required Region origin, required String weather, LiveWeather? live, HubData? hub, GptAsk? ask}) async {
  if (ask == null && !await gptAvailable()) return null;
  try {
    final list = _candidates(applyHub(places, hub), origin, weather == 'rain');
    final system = await renderPrompt('course_plan', {
      'context': await _context(profile, origin, weather, live, hub, profile.startTime, list),
      'variation': _variations[_rand.nextInt(_variations.length)],
    });
    final res = ask != null
        ? await ask('course_plan', system, '오늘 코스를 짜 줘.', 0.9)
        : await chatJson(system, '오늘 코스를 짜 줘.', purpose: 'course_plan', temperature: 0.9);
    final stops = _fit(_toStops(res['stops'], list), profile.startTime, profile.extra.hours);
    if (stops.length < 2) throw Exception('GPT 가 고른 장소가 2곳보다 적어요');
    return Course(weather, schedule(stops, profile.startTime), summary: '${res['summary'] ?? ''}'.trim(), source: 'gpt');
  } catch (e) {
    debugPrint('[planner] GPT 코스 실패, 기존 방식으로 대신합니다: $e');
    return null;
  }
}

/// 대화 결과. course 가 null 이면 코스는 그대로
class AiChatResult {
  const AiChatResult(this.reply, this.course, this.startTime);
  final String reply;
  final Course? course;
  final String? startTime;
}

/// 대화로 코스 고치기. history 는 (내가 보낸 말인지, 내용). GPT 를 못 쓰면 null
Future<AiChatResult?> chatCourseAI({
  required String message,
  required List<(bool, String)> history,
  required Course course,
  required Profile profile,
  required Region origin,
  required String weather,
  LiveWeather? live,
  HubData? hub,
  required String startTime,
  GptAsk? ask,
}) async {
  if (ask == null && !await gptAvailable()) return null;
  try {
    final list = _candidates(applyHub(places, hub), origin, weather == 'rain', [for (final s in course.stops) s.place.id]);
    final courseText = [
      for (var i = 0; i < course.stops.length; i++)
        '${i + 1}. ${course.stops[i].at} ${course.stops[i].place.name} (id ${course.stops[i].place.id}, ${kindLabel[course.stops[i].place.kind]}, ${course.stops[i].place.stay}분)',
    ].join('\n');
    final h = history.length > 10 ? history.sublist(history.length - 10) : history;
    final historyText = h.map((m) => '${m.$1 ? '여행자' : '플래너'}: ${m.$2}').join('\n');
    final system = await renderPrompt('course_chat', {
      'context': await _context(profile, origin, weather, live, hub, startTime, list),
      'course': courseText.isEmpty ? '(아직 없음)' : courseText,
      'history': historyText.isEmpty ? '(없음)' : historyText,
    });
    final res = ask != null
        ? await ask('course_chat', system, message, 0.7)
        : await chatJson(system, message, purpose: 'course_chat', temperature: 0.7);
    final reply = '${res['reply'] ?? ''}'.trim();
    if (reply.isEmpty) throw Exception('GPT 답이 비어 있어요');
    if (res['action'] != 'update') return AiChatResult(reply, null, null);
    final st = '${res['start_time'] ?? ''}';
    final start = RegExp(r'^\d{1,2}:\d{2}$').hasMatch(st) ? st : startTime;
    // GPT 가 이유를 다시 주지 않은 장소는 원래 이유를 그대로 씁니다
    final prevWhy = {for (final s in course.stops) s.place.id: s.why};
    final stops = [for (final (p, why) in _toStops(res['stops'], list)) (p, why ?? prevWhy[p.id])];
    if (stops.isEmpty) return AiChatResult(reply, null, null);
    return AiChatResult(reply, Course(course.weather, schedule(stops, start), summary: course.summary, source: 'gpt'), start);
  } catch (e) {
    debugPrint('[planner] GPT 대화 실패, 기존 방식으로 대신합니다: $e');
    return null;
  }
}
