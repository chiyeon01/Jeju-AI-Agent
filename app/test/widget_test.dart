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

  testWidgets('관광객: 로그인 → 기록 홈 → 성향 테스트 → 여행 정보 → 지역 → 코스 → 평가 → 기록 홈', (tester) async {
    _bigScreen(tester);
    await tester.pumpWidget(const ItdaApp());
    expect(find.text(keepAll('제주잇다')), findsOneWidget);

    await _login(tester, 'user@jeju.kr');
    // 로그인하면 성향 테스트가 아니라 내 기록 홈
    expect(find.text(keepAll('김여행님, 반가워요')), findsOneWidget);
    expect(find.text(keepAll('아직 다녀온 코스가 없어요.')), findsOneWidget);
    await _tap(tester, '첫 여행 코스 만들기');
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.text('관리'), findsNothing); // 관광객에게는 관리 메뉴가 없다

    await _tap(tester, '예시 응답으로 건너뛰기');
    // 여행 정보: 이동 수단 여러 개, 시작·끝 시각
    expect(find.text(keepAll('이번 여행은 어떻게 다니나요?')), findsOneWidget);
    for (final t in ['자동차', '택시', '버스', '배']) {
      expect(find.text(t), findsOneWidget);
    }
    await _tap(tester, '버스');
    await _tap(tester, '자동차'); // 자동차를 끄고 버스만
    expect(find.text(keepAll('8시간 여행이에요.')), findsOneWidget);
    await _tap(tester, '출발 지역 고르기');
    expect(find.text(keepAll('어디에서 시작할까요?')), findsOneWidget);
    expect(find.textContaining(keepAll('버스 · 10:00~18:00'), findRichText: true), findsWidgets);
    expect(find.text(keepAll('카카오맵 키를 넣으면 지도가 표시됩니다')), findsOneWidget);

    await _tap(tester, '애월읍');
    await _tap(tester, '애월읍에서 코스 만들기', ms: 6500); // 실시간 날씨·허브를 최대 5초 기다린 뒤 코스
    expect(find.text(keepAll('대화로 코스 고치기')), findsOneWidget);
    // GPT 키가 없는 테스트에서는 규칙 코스 (매번 조금씩 달라서 장소 이름 대신 문구로 확인)
    expect(find.textContaining(keepAll('내 성향에 맞춰 짠 코스예요')), findsOneWidget);
    expect(find.textContaining(keepAll('이동 약')), findsWidgets);
    expect(find.textContaining('D1'), findsNothing); // 데이터 출처 글씨는 없앰
    expect(find.textContaining('↗', findRichText: true), findsWidgets); // 장소 이름은 네이버 지도 링크
    // 대화 예시는 3개
    for (final t in ['아기가 놀기 좋은 곳으로 수정해줘.', '분좋카를 원해.', '회를 먹고싶어.']) {
      expect(find.text(t), findsOneWidget);
    }
    await _tap(tester, '다른 코스 보기', ms: 500);
    expect(find.textContaining(keepAll('이전에 본 코스와 다른 장소')), findsOneWidget);

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

    // 건너뛰면 기록 홈으로, 방금 코스와 성향이 기록에 남는다
    await _tap(tester, '건너뛰기');
    expect(find.textContaining('애월읍 출발 ·'), findsOneWidget);
    // 최근 코스를 누르면 그 코스 자세히
    await tester.tap(find.textContaining('애월읍 출발 ·').first);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('내 여행 기록으로'), findsOneWidget);
    expect(find.textContaining(keepAll('버스 · 10:00~18:00')), findsOneWidget);
    await _tap(tester, '내 여행 기록으로');
    expect(find.text('이 유형으로 코스 만들기'), findsOneWidget);
    await _tap(tester, '이 유형으로 코스 만들기');
    expect(find.text(keepAll('이번 여행은 어떻게 다니나요?')), findsOneWidget); // 성향 테스트 건너뛰고 여행 정보부터
    await tester.tap(find.byTooltip('뒤로가기'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 800));
    }
    expect(find.text(keepAll('김여행님, 반가워요')), findsOneWidget);

    // 이름을 누르면 내 정보·설정, 화면 밝기 조절
    await tester.tap(find.byKey(const ValueKey('me-button')));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text(keepAll('내 정보')), findsOneWidget);
    expect(find.text(keepAll('user@jeju.kr')), findsOneWidget);
    expect(find.text(keepAll('100%')), findsOneWidget);
    await tester.drag(find.byType(Slider), const Offset(-2000, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(keepAll('40%')), findsOneWidget);
    await _tap(tester, '원래 밝기');
    expect(find.text(keepAll('100%')), findsOneWidget);

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
    expect(find.text(keepAll('새여행자님, 반가워요')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
