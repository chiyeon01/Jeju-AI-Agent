import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../data/tourist_mock.dart';
import '../../theme.dart';
import '../../widgets/back.dart';
import '../../widgets/ui.dart';

const _sample = {0: 'a', 1: 'a', 2: 'b', 3: 'a', 4: 'a'};

class PersonalityTest extends StatefulWidget {
  const PersonalityTest({super.key, required this.onDone});
  final ValueChanged<Profile> onDone;
  @override
  State<PersonalityTest> createState() => _PersonalityTestState();
}

class _PersonalityTestState extends State<PersonalityTest> {
  int _i = 0;
  final Map<int, String> _answers = {};
  bool _loading = false;

  // 마지막 문항에 답하면 바로 유형을 봅니다 (동행·이동 수단·시간은 다음 "여행 정보" 단계에서)
  void _choose(String v) {
    setState(() => _answers[_i] = v);
    if (_i == questions.length - 1) {
      _finish();
      return;
    }
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _i++);
    });
  }

  Future<void> _finish([Map<int, String>? ans]) async {
    setState(() => _loading = true);
    final p = await analyzeProfile(ans ?? _answers, const TripExtra());
    if (mounted) widget.onDone(p);
  }

  void _prev() => setState(() => _i--); // 왼쪽 위 뒤로가기: 이전 문항

  @override
  Widget build(BuildContext context) => BackRegistration(onBack: _i > 0 ? _prev : null, child: _body(context));

  Widget _body(BuildContext context) {
    final total = questions.length;
    final q = questions[_i];
    Widget answer(String k, Choice c) => GestureDetector(
          onTap: _loading ? null : () => _choose(k),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _answers[_i] == k ? C.mist : C.surface,
                borderRadius: BorderRadius.circular(kRadius),
                border: Border.all(color: _answers[_i] == k ? C.sky : C.line, width: 1.5),
              ),
              child: VStack(gap: 4, children: [Text(c.icon, style: const TextStyle(fontSize: 24)), T(c.t)]),
            ),
          ),
        );
    return VStack(children: [
      Between(
        left: T.label('${_i + 1} / $total'),
        right: Btn(_loading ? '분석 중…' : '예시 응답으로 건너뛰기', ghost: true, small: true, onPressed: _loading ? null : () => _finish(_sample)),
      ),
      T.h2(q.q),
      if (_loading) const T.muted('내 여행 유형을 분석하는 중…'),
      Grid(cols: 2, minCols: MediaQuery.sizeOf(context).width > 520 ? 2 : 1, children: [answer('a', q.a), answer('b', q.b)]),
      if (_i > 0) Align(alignment: Alignment.centerLeft, child: Btn('이전 문항', ghost: true, small: true, onPressed: () => setState(() => _i--))),
    ]);
  }
}
