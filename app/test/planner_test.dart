import 'package:flutter_test/flutter_test.dart';
import 'package:jeju_ai_agent/api/hub.dart';
import 'package:jeju_ai_agent/api/planner.dart';
import 'package:jeju_ai_agent/api/weather.dart';
import 'package:jeju_ai_agent/data/tourist_mock.dart';

// 백엔드 /tourist/ai/json 대신 쓰는 가짜 GPT. 받은 (purpose, system, user) 를 기록합니다
class _Fake {
  _Fake(this.reply);
  final Map<String, dynamic> Function() reply;
  final calls = <(String, String, String)>[];
  Future<Map<String, dynamic>> call(String purpose, String system, String user, double t) async {
    calls.add((purpose, system, user));
    return reply();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final profile = scoreAnswers({0: 'a', 1: 'a', 2: 'b', 3: 'a', 4: 'a'}, const TripExtra(companion: '가족', startTime: '15:00', hours: 5));
  final aewol = regions.firstWhere((r) => r.id == 'aewol');
  const live = LiveWeather(code: 'rain', label: '비', icon: '🌧️', temp: 13.1, humidity: 88, wind: 6, rain1h: 1.2, source: '기상청', at: '10:00');

  test('처음 코스: 성향·실시간 날씨·후보를 보내고, 후보에 없는 id 와 중복은 버린다', () async {
    final f = _Fake(() => {'summary': '비가 와서 실내 위주로 짰어요.', 'stops': [{'id': 'p1', 'why': '창가 브런치'}, {'id': 'zz'}, {'id': 'p5', 'why': '감귤 체험'}, {'id': 'p1'}, {'id': 'p4'}]});
    final course = (await planCourseAI(profile: profile, origin: aewol, weather: 'rain', live: live, ask: f.call))!;
    final (purpose, system, _) = f.calls.single;
    expect(purpose, 'course_plan');
    expect(system, contains('비 13.1°C, 습도 88%'));
    expect(system, contains('- 유형: ${profile.name} (${profile.code})'));
    expect(system, contains('동행: 가족'));
    expect(RegExp(r'^\| p\d+ \|', multiLine: true).allMatches(system).length, greaterThanOrEqualTo(18));
    expect(system, contains('이번 변화 힌트: 이번에는'));
    expect(system, isNot(contains('{{')));
    expect(course.source, 'gpt');
    expect(course.summary, '비가 와서 실내 위주로 짰어요.');
    expect([for (final s in course.stops) s.place.id], ['p1', 'p5', 'p4']);
    expect(course.stops.first.at, '15:00');
    expect(course.stops.first.why, '창가 브런치');
    expect(course.stops[1].move, greaterThan(0));
  });

  test('허브: 혼잡도·인기도는 등급만 GPT 에 보내고, 방문객 숫자는 화면 근거에만 둔다', () async {
    const hub = HubData(
      crowd: {'date': '2025-06-30', 'regions': {'aewol': {'index': 0.8, 'vsAveragePct': 41}}},
      sights: {'start': '2024-12', 'items': [
        {'sightsName': '한담해안산책로', 'domestic': 20000, 'foreign': 1000},
        {'sightsName': '성산일출봉', 'domestic': 150000, 'foreign': 40000},
        {'sightsName': '기타', 'domestic': 10, 'foreign': 0},
      ]},
    );
    final f = _Fake(() => {'summary': 's', 'stops': [{'id': 'p2', 'why': '바다'}, {'id': 'p1'}]});
    final course = (await planCourseAI(profile: profile, origin: aewol, weather: 'clear', live: null, hub: hub, ask: f.call))!;
    final system = f.calls.single.$2;
    expect(system, contains('| p2 | 한담해안산책로 |'));
    expect(system, contains('| 높음 | 보통 |'));
    expect(system, contains('2025-06-30 유동인구 기준'));
    expect(system, isNot(contains('21,000')));
    expect(system, contains('실시간 날씨를 불러오지 못했어요'));
    expect(course.stops.first.place.reasons.first, ('D4', '허브 2024-12 방문객 21,000명 (제주 관광지 중 보통)'));
    expect(hubLine(hub), '제주데이터허브 반영: 지역 혼잡도 2025-06-30 · 관광지 방문객 2024-12');
  });

  test('대화: 지금 코스와 대화 기록을 보내고, 바뀐 코스와 출발 시각을 받는다', () async {
    final base = (await planCourseAI(profile: profile, origin: aewol, weather: 'rain', live: live,
        ask: _Fake(() => {'summary': 's', 'stops': [{'id': 'p1', 'why': '브런치'}, {'id': 'p5'}]}).call))!;
    final f = _Fake(() => {'reply': '아이와 가기 좋게 바꾸고 16시 출발로 했어요.', 'action': 'update', 'start_time': '16:00', 'stops': [{'id': 'p5', 'why': '감귤 체험'}, {'id': 'p1'}]});
    final r = (await chatCourseAI(message: '아이랑 가기 좋게', history: const [(false, '코스예요'), (true, '고마워')], course: base,
        profile: profile, origin: aewol, weather: 'rain', live: live, startTime: '15:00', ask: f.call))!;
    final (purpose, system, user) = f.calls.single;
    expect(purpose, 'course_chat');
    expect(user, '아이랑 가기 좋게');
    expect(system, contains('1. 15:00 봄날카페 (id p1'));
    expect(system, contains('플래너: 코스예요\n여행자: 고마워'));
    expect(r.reply, contains('16시'));
    expect(r.startTime, '16:00');
    expect([for (final s in r.course!.stops) s.place.id], ['p5', 'p1']);
    expect(r.course!.stops.first.at, '16:00');
    expect(r.course!.stops[1].why, '브런치'); // 이유를 다시 안 주면 원래 이유 유지
  });

  test('대화: 질문만 하면 코스는 그대로, GPT 오류면 null(기존 방식으로 대체)', () async {
    final base = (await planCourseAI(profile: profile, origin: aewol, weather: 'clear',
        ask: _Fake(() => {'summary': '', 'stops': [{'id': 'p2'}, {'id': 'p3'}]}).call))!;
    final none = await chatCourseAI(message: '거기 주차돼?', history: const [], course: base, profile: profile, origin: aewol,
        weather: 'clear', startTime: '15:00', ask: _Fake(() => {'reply': '네, 주차장이 있어요.', 'action': 'none', 'stops': []}).call);
    expect(none!.course, isNull);
    final fail = await chatCourseAI(message: 'x', history: const [], course: base, profile: profile, origin: aewol,
        weather: 'clear', startTime: '15:00', ask: (_, _, _, _) async => throw Exception('502 UPSTREAM_ERROR'));
    expect(fail, isNull);
  });

  test('목업 모드(백엔드 GPT 없음)에서는 부르지 않는다', () async {
    expect(await planCourseAI(profile: profile, origin: aewol, weather: 'clear'), isNull);
  });
}
