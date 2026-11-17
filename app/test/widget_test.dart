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

// 시연 계정 버튼은 없앴으므로 직접 입력해서 로그인합니다 (목업 모드의 내부 테스트 계정)
Future<void> _login(WidgetTester tester, String email, {String pw = 'jeju1234'}) async {
  await tester.enterText(find.byType(TextField).at(0), email);
  await tester.enterText(find.byType(TextField).at(1), pw);
  await _tap(tester, '로그인');
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

    await _login(tester, 'user@jeju.kr');
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.text('관리'), findsNothing); // 관광객에게는 관리 메뉴가 없다

    await _tap(tester, '예시 응답으로 건너뛰기');
    expect(find.text(keepAll('어디에서 시작할까요?')), findsOneWidget);
    expect(find.text(keepAll('카카오맵 키를 넣으면 지도가 표시됩니다')), findsOneWidget);

    await _tap(tester, '애월읍');
    await _tap(tester, '애월읍에서 코스 만들기', ms: 6500); // 실시간 날씨·허브를 최대 5초 기다린 뒤 코스
    expect(find.text(keepAll('대화로 코스 고치기')), findsOneWidget);
    // GPT 키가 없는 테스트에서는 데이터 점수 코스 (매번 조금씩 달라서 장소 이름 대신 문구로 확인)
    expect(find.text(keepAll('데이터 점수로 짠 코스예요')), findsOneWidget);
    expect(find.textContaining(keepAll('이동 약')), findsWidgets);

    // 왼쪽 위 뒤로가기 → 이전 단계(출발 지역)
    await tester.tap(find.byTooltip('뒤로가기'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 800));
    }
    expect(find.text(keepAll('어디에서 시작할까요?')), findsOneWidget);
    await _tap(tester, '애월읍');
    await _tap(tester, '애월읍에서 코스 만들기', ms: 6500); // 실시간 날씨·허브를 최대 5초 기다린 뒤 코스

    await _tap(tester, '여행 끝, 평가하기');
    expect(find.text(keepAll('오늘 다녀온 곳은 어땠나요?')), findsOneWidget);

    await _tap(tester, '로그아웃');
    expect(find.text('로그인'), findsOneWidget);
  });

  testWidgets('상권 주인과 관리자 화면', (tester) async {
    _bigScreen(tester);
    await tester.pumpWidget(const ItdaApp());

    await _login(tester, 'owner@jeju.kr');
    expect(find.text(keepAll('애월 돌담국수')), findsOneWidget);
    expect(find.text('여행 코스'), findsNothing);
    await _tap(tester, '로그아웃');

    await _login(tester, 'admin@jeju.kr');
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

  testWidgets('로그인 화면에 시연 계정이 없고, 회원가입하면 바로 로그인된다', (tester) async {
    _bigScreen(tester);
    await tester.pumpWidget(const ItdaApp());
    expect(find.textContaining('시연 계정'), findsNothing);
    await _tap(tester, '계정이 없나요? 회원가입');
    await tester.enterText(find.byType(TextField).at(0), '새여행자');
    await tester.enterText(find.byType(TextField).at(1), 'new@jeju.kr');
    await tester.enterText(find.byType(TextField).at(2), 'short');
    await _tap(tester, '가입하기');
    expect(find.text(keepAll('비밀번호는 8자 이상이어야 해요.')), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(2), 'password123');
    await _tap(tester, '가입하기');
    expect(find.text('1 / 5'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
