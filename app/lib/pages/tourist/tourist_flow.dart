// 관광객: 성향 테스트 → 출발 지역 → AI 코스 → 방문 평가
import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../data/tourist_mock.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';
import 'course_step.dart';
import 'location_step.dart';
import 'personality_test.dart';
import 'review_step.dart';

class TouristFlow extends StatefulWidget {
  const TouristFlow({super.key});
  @override
  State<TouristFlow> createState() => _TouristFlowState();
}

class _TouristFlowState extends State<TouristFlow> {
  int _step = 0;
  Profile? _profile;
  Region? _origin;
  Course? _course;

  void _go(int n) => setState(() => _step = n);

  @override
  Widget build(BuildContext context) {
    final body = switch (_step) {
      0 => PersonalityTest(onDone: (p) {
          _profile = p;
          _go(1);
        }),
      1 => LocationStep(profile: _profile!, onBack: () => _go(0), onDone: (r) {
          _origin = r;
          _go(2);
        }),
      2 => CourseStep(profile: _profile!, origin: _origin!, onBack: () => _go(1), onDone: (c) {
          _course = c;
          _go(3);
        }),
      _ => ReviewStep(profile: _profile!, course: _course!, onRestart: () {
          _profile = null;
          _origin = null;
          _course = null;
          _go(0);
        }),
    };
    return PageBody(
      key: ValueKey(_step),
      narrow: _step != 2,
      children: [
        Semantics(
          label: '${_step + 1} / 4 단계',
          child: Row(children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: Container(height: 4, decoration: BoxDecoration(color: i <= _step ? C.sky : C.line, borderRadius: BorderRadius.circular(999)))),
            ],
          ]),
        ),
        body,
      ],
    );
  }
}

/// 내 여행 유형 카드
class TypeCard extends StatelessWidget {
  const TypeCard({super.key, required this.profile});
  final Profile profile;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: C.sky, borderRadius: BorderRadius.circular(kRadius)),
        child: VStack(gap: 6, children: [
          T.small('나의 제주 여행 유형 · ${profile.code}', color: C.skyInk),
          T.h2(profile.name, color: C.skyInk),
          T.small(profile.desc, color: C.skyInk),
          T.small('${profile.tags.join(' · ')} · ${profile.companion} · ${profile.transport}', color: C.skyInk),
        ]),
      );
}
