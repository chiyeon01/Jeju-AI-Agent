// 관광객: 성향 테스트 → 여행 정보(시간·이동 수단) → 출발 지역 → AI 코스 → 방문 평가
import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../api/history.dart';
import '../../data/tourist_mock.dart';
import '../../theme.dart';
import '../../widgets/back.dart';
import '../../widgets/ui.dart';
import 'course_step.dart';
import 'location_step.dart';
import 'personality_test.dart';
import 'review_step.dart';
import 'trip_step.dart';

class TouristFlow extends StatefulWidget {
  const TouristFlow({super.key, required this.userId, this.initialProfile, required this.onExit});
  final String userId;

  /// 홈에서 고른 유형으로 시작하면 성향 테스트를 건너뛰고 여행 정보(시간·이동 수단)부터
  final Profile? initialProfile;

  /// 기록 홈으로 돌아가기
  final VoidCallback onExit;
  @override
  State<TouristFlow> createState() => _TouristFlowState();
}

class _TouristFlowState extends State<TouristFlow> {
  late int _step = widget.initialProfile != null ? 1 : 0;
  late Profile? _profile = widget.initialProfile;
  Region? _origin;
  Course? _course;

  void _go(int n) => setState(() => _step = n);
  // 왼쪽 위 뒤로가기: 이전 단계, 첫 단계면 기록 홈으로
  void _back() => _step == 0 || (_step == 1 && widget.initialProfile != null) ? widget.onExit() : _go(_step - 1);
  static const _steps = 5;

  @override
  Widget build(BuildContext context) {
    final body = switch (_step) {
      0 => PersonalityTest(onDone: (p) {
          _profile = p;
          recordProfile(widget.userId, p);
          _go(1);
        }),
      1 => TripStep(profile: _profile!, onBack: () => _go(0), onDone: (p) {
          _profile = p;
          _go(2);
        }),
      2 => LocationStep(profile: _profile!, onBack: () => _go(1), onDone: (r) {
          _origin = r;
          _go(3);
        }),
      3 => CourseStep(profile: _profile!, origin: _origin!, onBack: () => _go(2), onDone: (c, live) {
          _course = c;
          recordCourse(widget.userId, course: c, origin: _origin!, profile: _profile!, live: live);
          _go(4);
        }),
      _ => ReviewStep(
          profile: _profile!,
          course: _course!,
          onSent: (items) => recordReviews(widget.userId, items),
          onRestart: widget.onExit,
        ),
    };
    return BackRegistration(onBack: _back, child: PageBody(
      key: ValueKey(_step),
      narrow: _step != 3,
      children: [
        Semantics(
          label: '${_step + 1} / $_steps 단계',
          child: Row(children: [
            for (var i = 0; i < _steps; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: Container(height: 4, decoration: BoxDecoration(color: i <= _step ? C.sky : C.line, borderRadius: BorderRadius.circular(999)))),
            ],
          ]),
        ),
        body,
      ],
    ));
  }
}

/// 내 여행 유형 카드 (showTrip: 동행·이동 수단·시간까지 보여 줄지)
class TypeCard extends StatelessWidget {
  const TypeCard({super.key, required this.profile, this.showTrip = true});
  final Profile profile;
  final bool showTrip;
  @override
  Widget build(BuildContext context) {
    final trip = [
      profile.companion,
      profile.transport,
      if (profile.endTime != null) '${profile.startTime}~${profile.endTime}',
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: C.sky, borderRadius: BorderRadius.circular(kRadius)),
      child: VStack(gap: 6, children: [
        T.small('나의 제주 여행 유형 · ${profile.code}', color: C.skyInk),
        T.h2(profile.name, color: C.skyInk),
        T.small(profile.desc, color: C.skyInk),
        T.small([profile.tags.join(' · '), if (showTrip) ...trip].join(' · '), color: C.skyInk),
      ]),
    );
  }
}
