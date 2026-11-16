// 주요 화면이 오류 없이 그려지는지 확인하는 위젯 테스트
import 'package:flutter_test/flutter_test.dart';
import 'package:jeju_ai_agent/data/jeju_geo.dart';
import 'package:jeju_ai_agent/main.dart';
import 'package:jeju_ai_agent/widgets/ui.dart' show keepAll;
import 'package:material_ui/material_ui.dart';

Future<void> _open(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await JejuGeo.load();
  });

  testWidgets('홈 → 관광객 성향 테스트(예시 응답) → 위치 선택', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ItdaApp());
    expect(find.text('제주잇다'), findsOneWidget);
    expect(find.text('여행 코스 받기'), findsOneWidget);

    await _open(tester, '성향 테스트 시작');
    expect(find.text('Q01 / 12'), findsOneWidget);

    await tester.tap(find.text('예시 응답으로 건너뛰기'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text(keepAll('어디에서 시작할까요?')), findsOneWidget);

    await tester.tap(find.text('📍 현재 위치 사용'));
    await tester.pump();
    await tester.tap(find.text('AI 코스 만들기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text(keepAll('대화로 코스 고치기')), findsOneWidget);
    expect(find.text('여행 끝, 평가하기'), findsOneWidget);
    expect(find.text('곽지 노을 방파제'), findsOneWidget); // 애월 출발 코스에 노을 명소가 들어간다

    await tester.tap(find.text('여행 끝, 평가하기'));
    await tester.pump();
    expect(find.text(keepAll('오늘 다녀온 곳은 어땠나요?')), findsOneWidget);
  });

  testWidgets('사장님 대시보드와 Main PC 콘솔이 그려진다', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ItdaApp());
    await _open(tester, '사장님');
    expect(find.text(keepAll('애월 돌담국수')), findsOneWidget);

    await _open(tester, 'Main PC');
    expect(find.text(keepAll('통합 데이터 관리 콘솔')), findsOneWidget);
    for (final tab in ['데이터 관리', '접근·보안', '백업·복구', '통합 현황']) {
      await _open(tester, tab);
    }
    await tester.pumpWidget(const SizedBox.shrink()); // 실시간 이벤트 타이머 정리
  });
}
