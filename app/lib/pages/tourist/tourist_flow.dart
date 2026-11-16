// 관광객 4단계 흐름: 성향 테스트 → 위치 선택 → AI 코스 → 방문 평가 (React 의 TouristFlow.jsx)
import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../data/tourist_mock.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';
import 'course_step.dart';
import 'location_step.dart';
import 'personality_test.dart';
import 'review_step.dart';

const _steps = ['성향 테스트', '위치 선택', 'AI 코스', '방문 평가'];

class TouristFlow extends StatefulWidget {
  const TouristFlow({super.key});

  @override
  State<TouristFlow> createState() => _TouristFlowState();
}

class _TouristFlowState extends State<TouristFlow> {
  final _scroll = ScrollController();
  int _step = 0;
  Profile? _profile;
  Region? _origin;
  Course? _course;

  void _go(int n) {
    setState(() => _step = n);
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_step) {
      0 => PersonalityTest(onDone: (p) {
          _profile = p;
          _go(1);
        }),
      1 => LocationStep(
          profile: _profile!,
          onBack: () => _go(0),
          onDone: (o) {
            _origin = o;
            _go(2);
          }),
      2 => CourseStep(
          profile: _profile!,
          origin: _origin!,
          onBack: () => _go(1),
          onDone: (c) {
            _course = c;
            _go(3);
          }),
      _ => ReviewStep(
          profile: _profile!,
          course: _course!,
          onRestart: () {
            _profile = null;
            _origin = null;
            _course = null;
            _go(0);
          }),
    };

    return PageBody(
      controller: _scroll,
      narrow: _step == 0 || _step == 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Stepper(step: _step),
          const SizedBox(height: 24),
          KeyedSubtree(key: ValueKey(_step), child: body),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: '진행 단계',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= step ? c.accent : c.surface2,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${i + 1}. ${_steps[i]}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tx(context,
                        size: fsXs,
                        weight: i <= step ? FontWeight.w600 : FontWeight.w400,
                        color: i <= step ? c.ink : c.muted),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
