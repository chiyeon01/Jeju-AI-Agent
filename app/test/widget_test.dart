// 로그인과 역할별 주요 화면이 오류 없이 그려지는지 확인하는 위젯 테스트 (목업 모드)
import 'package:flutter_test/flutter_test.dart';
import 'package:jeju_ai_agent/main.dart';
import 'package:jeju_ai_agent/widgets/ui.dart' show keepAll;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _tap(WidgetTester tester, String text, {int ms = 800}) async {
  await tester.tap(find.text(text).first);
  for (var i = 0; i < 3; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

void _bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('관광객: 로그인 → 성향 테스트 → 지역 → 코스 → 평가', (tester) async {
    _bigScreen(tester);
    await tester.pumpWidget(const ItdaApp());
    expect(find.text(keepAll('제주잇다')), findsOneWidget);

    await _tap(tester, '관광객 계정 · user@jeju.kr');
    expect(find.text('1 / 12'), findsOneWidget);
    expect(find.text('관리'), findsNothing); // 관광객에게는 관리 메뉴가 없다

    await _tap(tester, '예시 응답으로 건너뛰기');
    expect(find.text(keepAll('어디에서 시작할까요?')), findsOneWidget);
    expect(find.text(keepAll('카카오맵 키를 넣으면 지도가 표시됩니다')), findsOneWidget);

    await _tap(tester, '애월읍');
    await _tap(tester, '애월읍에서 코스 만들기');
    expect(find.text(keepAll('대화로 코스 고치기')), findsOneWidget);
    expect(find.text('곽지 노을 방파제'), findsOneWidget);

    await _tap(tester, '여행 끝, 평가하기');
    expect(find.text(keepAll('오늘 다녀온 곳은 어땠나요?')), findsOneWidget);

    await _tap(tester, '로그아웃');
    expect(find.text('로그인'), findsOneWidget);
  });

  testWidgets('상권 주인과 관리자 화면', (tester) async {
    _bigScreen(tester);
    await tester.pumpWidget(const ItdaApp());

    await _tap(tester, '상권 주인 계정 · owner@jeju.kr');
    expect(find.text(keepAll('애월 돌담국수')), findsOneWidget);
    expect(find.text('여행 코스'), findsNothing);
    await _tap(tester, '로그아웃');

    await _tap(tester, '관리자 계정 · admin@jeju.kr');
    expect(find.text(keepAll('통합 관리')), findsOneWidget);
    for (final tab in ['데이터', '계정·보안', '백업', '현황']) {
      await _tap(tester, tab);
    }
    await _tap(tester, '계정·보안');
    await _tap(tester, '가입 승인');
    expect(find.text('가입 승인'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink()); // 실시간 이벤트 타이머 정리
  });

  testWidgets('틀린 비밀번호는 오류를 보여 준다', (tester) async {
    _bigScreen(tester);
    await tester.pumpWidget(const ItdaApp());
    await tester.enterText(find.byType(TextField).at(0), 'user@jeju.kr');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await _tap(tester, '로그인');
    expect(find.text(keepAll('이메일 또는 비밀번호가 맞지 않아요.')), findsOneWidget);
  });
}
