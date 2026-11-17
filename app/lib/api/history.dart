// ─────────────────────────────────────────────
// 내 여행 기록 (성향 테스트 · 만든 코스 · 보낸 평가) — 웹 src/api/history.js 와 같은 구조
// 백엔드는 성향 결과와 코스를 저장하지 않으므로, 이 기기에 계정별로 저장합니다.
// ─────────────────────────────────────────────
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/tourist_mock.dart';
import 'client.dart';
import 'weather.dart';

const _limit = 20;
String _key(String userId) => 'jeju-history:$userId';

class ProfileRecord {
  const ProfileRecord(this.at, this.profile);
  final DateTime at;
  final Profile profile;
}

class CourseRecord {
  const CourseRecord({required this.at, required this.origin, required this.type, this.weather, this.trip = '', required this.source, required this.stops});
  final DateTime at;
  final String origin, type, source;
  final String? weather;

  /// 동행 · 이동 수단 · 시작~끝 시각
  final String trip;
  final List<({String id, String name, String kind, String at, double? lat, double? lon})> stops;
}

class ReviewRecord {
  const ReviewRecord({required this.at, required this.placeId, required this.name, required this.stars, this.text = ''});
  final DateTime at;
  final String placeId, name, text;
  final int stars;
}

class History {
  const History({this.profiles = const [], this.courses = const [], this.reviews = const []});
  final List<ProfileRecord> profiles;
  final List<CourseRecord> courses;
  final List<ReviewRecord> reviews;
  int get count => profiles.length + courses.length + reviews.length;
  double? get avgStars => reviews.isEmpty ? null : reviews.fold<int>(0, (s, r) => s + r.stars) / reviews.length;
}

DateTime _t(Object? v) => DateTime.tryParse('$v')?.toLocal() ?? DateTime.now();

Future<Map<String, dynamic>> _raw(String userId) async {
  try {
    final s = (await SharedPreferences.getInstance()).getString(_key(userId));
    return s == null ? {} : (jsonDecode(s) as Map).cast<String, dynamic>();
  } catch (_) {
    return {};
  }
}

Future<void> _push(String userId, String list, Map<String, dynamic> item) async {
  final raw = await _raw(userId);
  final items = [item, ...((raw[list] as List?) ?? const [])].take(_limit).toList();
  raw[list] = items;
  await (await SharedPreferences.getInstance()).setString(_key(userId), jsonEncode(raw));
}

String _now() => DateTime.now().toUtc().toIso8601String();

Future<History> loadHistory(String userId) async {
  final raw = await _raw(userId);
  List<Map> l(String k) => [for (final x in (raw[k] as List?) ?? const []) if (x is Map) x];
  return History(
    profiles: [
      for (final x in l('profiles'))
        if (x['profile'] is Map) ProfileRecord(_t(x['at']), Profile.fromJson((x['profile'] as Map).cast<String, dynamic>())),
    ],
    courses: [
      for (final x in l('courses'))
        CourseRecord(
          at: _t(x['at']),
          origin: '${x['origin'] ?? ''}',
          type: '${x['type'] ?? ''}',
          weather: x['weather'] as String?,
          trip: '${x['trip'] ?? ''}',
          source: '${x['source'] ?? 'rule'}',
          stops: [
            for (final s in (x['stops'] as List?) ?? const [])
              if (s is Map)
                (
                  id: '${s['id']}', name: '${s['name']}', kind: '${s['kind']}', at: '${s['at'] ?? ''}',
                  lat: (s['lat'] as num?)?.toDouble(), lon: (s['lon'] as num?)?.toDouble(),
                ),
          ],
        ),
    ],
    reviews: [
      for (final x in l('reviews'))
        ReviewRecord(at: _t(x['at']), placeId: '${x['placeId']}', name: '${x['name']}', stars: (x['stars'] as num?)?.toInt() ?? 0, text: '${x['text'] ?? ''}'),
    ],
  );
}

Future<void> recordProfile(String userId, Profile p) => _push(userId, 'profiles', {'at': _now(), 'profile': p.toJson()});

Future<void> recordCourse(String userId, {required Course course, required Region origin, required Profile profile, LiveWeather? live}) =>
    _push(userId, 'courses', {
      'at': _now(),
      'origin': origin.name,
      'type': '${profile.name} (${profile.code})',
      'weather': live == null ? null : '${live.icon} ${live.label} ${live.temp.round()}°C',
      'trip': [profile.companion, profile.transport, if (profile.endTime != null) '${profile.startTime}~${profile.endTime}'].join(' · '),
      'source': course.source,
      'stops': [
        for (final s in course.stops) {'id': s.place.id, 'name': s.place.name, 'kind': s.place.kind, 'at': s.at, 'lat': s.place.lat, 'lon': s.place.lon}
      ],
    });

Future<void> recordReviews(String userId, List<({String placeId, String name, int stars, String text})> items) async {
  for (final r in items) {
    await _push(userId, 'reviews', {'at': _now(), 'placeId': r.placeId, 'name': r.name, 'stars': r.stars, 'text': r.text});
  }
}

Future<void> clearHistory(String userId) async => (await SharedPreferences.getInstance()).remove(_key(userId));

/// "11월 17일 14:05"
String fmtWhen(DateTime d) => '${d.month}월 ${d.day}일 ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
