// 출발 지역을 누르면 지역 특색(그림·해시태그·설명·내 유형과 맞는 점)이 나타나는지 (목업 모드)
import 'package:flutter_test/flutter_test.dart';
import 'package:jeju_ai_agent/data/region_info.dart';
import 'package:jeju_ai_agent/data/tourist_mock.dart';
import 'package:jeju_ai_agent/pages/tourist/location_step.dart';
import 'package:jeju_ai_agent/widgets/region_art.dart';
import 'package:jeju_ai_agent/widgets/ui.dart' show keepAll;
import 'package:material_ui/material_ui.dart';

void main() {
  test('내 유형과 겹치는 지역 특색', () {
    expect(fitWith('aewol', 'ANPJ'), ['자연·바다', '풍경·사진']);
    expect(fitWith('jeju-city', 'ANPJ'), isEmpty);
    expect(regionInfo.length, 10);
  });

  testWidgets('지역을 누를 때마다 특색 카드가 바뀐다', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const profile = Profile(code: 'ANPJ', name: '노을 감성 탐험가', desc: '바다', scores: {}, tags: ['#바다'], extra: TripExtra());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: LocationStep(profile: profile, onDone: (_) {}, onBack: () {}))),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(RegionFeature), findsNothing);

    await tester.tap(find.text('애월읍').first);
    await tester.pumpAndSettle();
    expect(find.byType(RegionArt), findsOneWidget);
    expect(find.text('#노을명소'), findsOneWidget);
    expect(find.text('내 유형과 잘 맞아요 · 자연·바다, 풍경·사진'), findsOneWidget);
    expect(find.text(keepAll(regionInfo['aewol']!.desc)), findsOneWidget);

    await tester.tap(find.text('성산').first);
    await tester.pumpAndSettle();
    expect(find.text('#성산일출봉'), findsOneWidget);
    expect(find.text('#노을명소'), findsNothing);
  });
}
