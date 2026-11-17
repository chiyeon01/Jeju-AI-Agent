// 관리 콘솔 Agent 보고서 · 상권 주인 내 가게 리뷰 · 마크다운 위젯 (목업 모드)
import 'package:flutter_test/flutter_test.dart';
import 'package:jeju_ai_agent/pages/console/main_console.dart';
import 'package:jeju_ai_agent/pages/owner/my_reviews.dart';
import 'package:jeju_ai_agent/widgets/markdown.dart';
import 'package:jeju_ai_agent/widgets/ui.dart' show keepAll;
import 'package:material_ui/material_ui.dart';

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: w)));

void _bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('마크다운: 제목·글머리표·굵게', (tester) async {
    await tester.pumpWidget(_wrap(const Markdown('## 요약\n- 애월이 **가장 높아요**\n본문')));
    expect(find.textContaining(keepAll('요약'), findRichText: true), findsOneWidget);
    expect(find.textContaining(keepAll('가장'), findRichText: true), findsOneWidget);
    expect(find.text('•  '), findsOneWidget);
  });

  testWidgets('콘솔: 지역 점수 표와 Agent 보고서 만들기', (tester) async {
    _bigScreen(tester);
    await tester.pumpWidget(_wrap(const MainConsole()));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text(keepAll('지역 점수 (0~10)')), findsOneWidget);
    expect(find.text(keepAll('장소별 평가 (고유 번호)')), findsOneWidget);
    expect(find.text('#30'), findsOneWidget);
    await tester.tap(find.text('Agent 보고서').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(keepAll('아직 보고서가 없어요.')), findsOneWidget);
    await tester.tap(find.text('지금 보고서 만들기'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(keepAll('지역 점수 보고서 (시연)')), findsWidgets);
    await tester.pumpWidget(const SizedBox()); // 타이머 정리
  });

  testWidgets('상권 주인: 가게 연결 → 별점·리뷰 → Agent 분석', (tester) async {
    _bigScreen(tester);
    await tester.pumpWidget(_wrap(const MyReviews()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(keepAll('관광객 평가를 받는 내 가게를 고르세요')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('place-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(keepAll('#1 봄날카페 · 카페')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('연결'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(keepAll('관광객 평가 0건')), findsOneWidget);
    expect(find.textContaining(keepAll('장소 #1')), findsOneWidget);
    await tester.tap(find.text('분석하기'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.textContaining(keepAll('시연 화면이라'), findRichText: true), findsOneWidget);
  });
}
