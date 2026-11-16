// ─────────────────────────────────────────────
// API 클라이언트 (React 의 src/api/client.js 와 같은 역할)
// USE_MOCK=true(기본) 이면 목업 데이터를 돌려주고,
// false 이면 FastAPI 백엔드(API_BASE_URL)를 호출합니다.
// 화면은 이 파일의 함수만 사용하므로 백엔드 연동 시 여기만 바꾸면 됩니다.
//
// 실행 예: flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
//   (Android 에뮬레이터에서 PC 의 localhost 는 10.0.2.2 입니다)
// ─────────────────────────────────────────────
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:http/http.dart' as http;

import '../data/jeju_geo.dart';
import '../data/owner_mock.dart';
import '../data/tourist_mock.dart';

const bool isMock = String.fromEnvironment('USE_MOCK', defaultValue: 'true') != 'false';
const String _base = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000/api');

Future<void> _wait(int ms) => Future.delayed(Duration(milliseconds: ms));

Future<Map<String, dynamic>> _http(String path, [Object? body]) async {
  final uri = Uri.parse('$_base$path');
  final res = body == null
      ? await http.get(uri, headers: {'Content-Type': 'application/json'})
      : await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('서버 응답 오류 (${res.statusCode})');
  }
  return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
}

/// 성향 분석 Agent: POST /tourist/profile
Future<Profile> analyzeProfile(Map<int, String> answers, TripExtra extra) async {
  if (!isMock) {
    final j = await _http('/tourist/profile', {
      'answers': answers.map((k, v) => MapEntry('$k', v)),
      ...extra.toJson(),
    });
    return Profile.fromJson(j);
  }
  await _wait(500);
  return scoreAnswers(answers, extra);
}

/// 코스의 한 장소 (도착 시각 at, 앞 장소에서 이동 시간 move 분)
class Stop {
  const Stop(this.place, this.at, this.move);
  final Place place;
  final String at;
  final int move;
}

class Course {
  const Course(this.weather, this.stops);
  final String weather;
  final List<Stop> stops;
}

/// 코스 옵션 (대화로 바뀌는 값)
class CourseOpts {
  const CourseOpts({this.weather = 'clear', this.seafood = false, this.removeCount = 0});
  final String weather;
  final bool seafood;
  final int removeCount;

  CourseOpts copyWith({String? weather, bool? seafood, int? removeCount}) => CourseOpts(
        weather: weather ?? this.weather,
        seafood: seafood ?? this.seafood,
        removeCount: removeCount ?? this.removeCount,
      );
}

double _dist(Offset a, Offset b) => (a - b).distance;

/// 코스 플래너 Agent: POST /tourist/course
Future<Course> planCourse({required Profile profile, required Region origin, required CourseOpts opts}) async {
  final startTime = profile.startTime;
  if (!isMock) {
    final j = await _http('/tourist/course', {
      'profile': profile.toJson(),
      'origin': origin.toJson(),
      'weather': opts.weather,
      'startTime': startTime,
    });
    final stops = (j['stops'] as List).map((s) {
      final m = s as Map<String, dynamic>;
      final p = Place(m['id'], m['name'], m['region'] ?? '', m['kind'] ?? 'spot', (m['lat'] as num).toDouble(), (m['lon'] as num).toDouble(),
          indoor: m['indoor'] ?? false,
          rating: (m['rating'] as num?)?.toDouble() ?? 0,
          stay: (m['stay'] as num?)?.toInt() ?? 0,
          seafood: m['seafood'] ?? false,
          reasons: [for (final r in (m['reasons'] as List? ?? const [])) ('${r[0]}', '${r[1]}')]);
      return Stop(p, m['at'] ?? '', (m['move'] as num?)?.toInt() ?? 0);
    }).toList();
    return Course(j['weather'] ?? opts.weather, stops);
  }
  await _wait(700);
  final rain = opts.weather == 'rain';
  final near = [...places]..sort((a, b) => _dist(a.pos, origin.pos).compareTo(_dist(b.pos, origin.pos)));
  Place? pick(List<String> kinds, Set<String> used, [bool Function(Place)? pred]) {
    for (final p in near) {
      if (kinds.contains(p.kind) && !used.contains(p.id) && (pred == null || pred(p))) return p;
    }
    return null;
  }

  final order = rain
      ? [['cafe'], ['indoor'], ['indoor', 'cafe'], ['food']]
      : [['cafe'], ['spot'], ['sunset'], ['food']];
  final used = <String>{};
  final stops = <Place>[];
  for (final kinds in order) {
    bool Function(Place) pred;
    if (kinds.contains('food') && opts.seafood) {
      pred = (p) => p.seafood;
    } else if (rain) {
      pred = (p) => p.indoor;
    } else {
      pred = (p) => true;
    }
    final p = pick(kinds, used, pred) ?? pick(kinds, used);
    if (p != null) {
      used.add(p.id);
      stops.add(p);
    }
  }
  final trimmed = stops.sublist(0, math.min(stops.length, math.max(2, stops.length - opts.removeCount)));

  // 시간표 생성 (장소 체류시간 + 이동시간)
  final hm = startTime.split(':').map(int.parse).toList();
  var t = hm[0] * 60 + hm[1];
  String fmt(int x) => '${(x ~/ 60).toString().padLeft(2, '0')}:${(x % 60).toString().padLeft(2, '0')}';
  final out = <Stop>[];
  for (var i = 0; i < trimmed.length; i++) {
    final p = trimmed[i];
    // 직선거리(km) × 1.3(도로 보정) ÷ 평균 35km/h + 주차·도보 4분
    final km = i == 0 ? 0.0 : _dist(p.pos, trimmed[i - 1].pos) * kmPerPx * 1.3;
    final move = i == 0 ? 0 : math.max(5, (km / 35 * 60 + 4).round());
    t += move;
    final at = fmt(t);
    t += p.stay;
    out.add(Stop(p, at, move));
  }
  return Course(opts.weather, out);
}

/// 코스 수정 대화 결과. patch 가 있으면 코스 옵션을 바꿉니다.
class ChatResult {
  const ChatResult(this.reply, this.patch);
  final String reply;
  final ({String? weather, bool? seafood, int removeCount})? patch;
}

/// 코스 수정 대화: POST /tourist/course/chat
Future<ChatResult> chatCourse(String message) async {
  if (!isMock) {
    final j = await _http('/tourist/course/chat', {'message': message});
    final p = j['patch'] as Map<String, dynamic>?;
    return ChatResult(
      j['reply'] ?? '',
      p == null ? null : (weather: p['weather'] as String?, seafood: p['seafood'] as bool?, removeCount: (p['removeCount'] as num?)?.toInt() ?? 0),
    );
  }
  await _wait(600);
  if (RegExp('해산물|회|바다 음식').hasMatch(message)) {
    return const ChatResult('저녁을 해산물 식당으로 바꿨어요. 최근 외식업 메뉴 매출에서 해산물 비중이 높은 곳 위주로 골랐어요.',
        (weather: null, seafood: true, removeCount: 0));
  }
  if (RegExp('줄여|빼|하나 빼|1곳').hasMatch(message)) {
    return const ChatResult('마지막 장소 하나를 뺐어요. 이동 시간이 줄어 여유가 생겼어요.', (weather: null, seafood: null, removeCount: 1));
  }
  if (RegExp('비|실내').hasMatch(message)) {
    return const ChatResult('실내 위주 코스로 바꿨어요.', (weather: 'rain', seafood: null, removeCount: 0));
  }
  return const ChatResult(
      '시연 화면에서는 "저녁은 해산물로 바꿔줘", "1곳 줄여줘", "실내로 바꿔줘"를 알아들어요. 백엔드를 연결하면 Claude 기반 코스 플래너 Agent가 답합니다.', null);
}

/// 방문 후 평가: POST /tourist/reviews → 실시간 파이프라인 이벤트
Future<int> submitReviews(List<Map<String, dynamic>> reviews) async {
  if (!isMock) {
    final j = await _http('/tourist/reviews', {'reviews': reviews});
    return (j['accepted'] as num?)?.toInt() ?? reviews.length;
  }
  await _wait(600);
  return reviews.length;
}

/// 상권 Agent 질의: POST /owner/ask
Future<String> askOwnerAgent(String question) async {
  if (!isMock) {
    final j = await _http('/owner/ask', {'question': question});
    return j['answer'] ?? '';
  }
  await _wait(700);
  return ownerQa[question] ??
      '시연 화면에서는 아래 예시 질문에 답해요. 백엔드를 연결하면 상권 분석 Agent가 SQL로 지표를 계산한 뒤 근거와 함께 답합니다.';
}

/// 사장님 개선 조치 등록: POST /owner/actions
Future<void> registerAction(String kind, String title) async {
  if (!isMock) {
    await _http('/owner/actions', {'kind': kind, 'title': title});
    return;
  }
  await _wait(400);
}
