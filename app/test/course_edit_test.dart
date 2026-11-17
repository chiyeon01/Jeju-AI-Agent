import 'package:flutter_test/flutter_test.dart';
import 'package:jeju_ai_agent/api/client.dart';
import 'package:jeju_ai_agent/api/course_edit.dart';
import 'package:jeju_ai_agent/api/planner.dart';
import 'package:jeju_ai_agent/data/tourist_mock.dart';

void main() {
  final byId = {for (final p in places) p.id: p};
  // 중문 출발, 백엔드가 짠 3곳 코스 (카페 → 해변 → 노을)
  Course base() => Course('clear', schedule([(byId['p30']!, null), (byId['p21']!, null), (byId['p8']!, null)], '15:00'));

  test('늘리기 요청을 알아보고, 해산물·줄이기·실내는 백엔드에 맡긴다', () {
    for (final m in ['코스를 더 늘려줘', '1곳 더 넣어줘', '카페 하나 추가해줘', '두 곳 더 가고 싶어']) {
      expect(isAddRequest(m), isTrue, reason: m);
    }
    for (final m in ['저녁은 해산물로 바꿔줘', '1곳 줄여줘', '실내로 바꿔줘', '좋아요']) {
      expect(isAddRequest(m), isFalse, reason: m);
    }
    expect(addToCourse('좋아요', base(), startTime: '15:00'), isNull);
  });

  test('종류를 말하지 않으면 저녁 식사부터 넣고, 시간 흐름 자리에 끼운다', () {
    final r = addToCourse('코스를 더 늘려줘', base(), startTime: '15:00')!;
    final ids = [for (final s in r.course!.stops) s.place.id];
    expect(ids.length, 4);
    expect(r.course!.stops.last.place.kind, 'food');
    expect(r.course!.stops.last.place.reasons.first, ('요청', '대화로 추가한 장소예요'));
    expect(r.reply, contains('이제 4곳을 도는 코스'));
    expect(r.added, [ids.last]);
  });

  test('카페를 말하면 카페를 노을 앞에 넣고, 백엔드가 다시 짜도 유지된다', () {
    final r = addToCourse('카페 하나 추가해줘', base(), startTime: '15:00')!;
    final stops = r.course!.stops;
    final cafe = stops.indexWhere((s) => s.place.id == r.added.single);
    expect(stops[cafe].place.kind, 'cafe');
    expect(cafe, lessThan(stops.indexWhere((s) => s.place.kind == 'sunset')));
    final kept = keepAdded(base().stops, r.added, '15:00');
    expect([for (final s in kept) s.place.id], [for (final s in stops) s.place.id]);
  });

  test('7곳이면 더 넣지 않는다', () {
    var c = base();
    for (var i = 0; i < 4; i++) {
      c = addToCourse('하나 더 넣어줘', c, startTime: '15:00')!.course!;
    }
    expect(c.stops.length, maxStops);
    final r = addToCourse('하나 더 넣어줘', c, startTime: '15:00')!;
    expect(r.course, isNull);
    expect(r.reply, contains('7곳'));
  });
}
