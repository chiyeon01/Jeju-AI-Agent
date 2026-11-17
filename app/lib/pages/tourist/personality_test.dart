import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../data/tourist_mock.dart';
import '../../theme.dart';
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
  TripExtra _extra = const TripExtra();
  bool _loading = false;

  void _choose(String v) {
    setState(() => _answers[_i] = v);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _i++);
    });
  }

  Future<void> _finish([Map<int, String>? ans]) async {
    setState(() => _loading = true);
    final p = await analyzeProfile(ans ?? _answers, _extra);
    if (mounted) widget.onDone(p);
  }

  Future<void> _pickTime() async {
    final hm = _extra.startTime.split(':').map(int.parse).toList();
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: hm[0], minute: hm[1]));
    if (t != null) {
      setState(() => _extra = _extra.copyWith(startTime: '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = questions.length;
    if (_i >= total) {
      return VStack(children: [
        const T.h2('누구와, 어떻게 움직이나요?'),
        AppCard(
          child: VStack(children: [
            Field('동행', child: Chips(children: [for (final c in companions) ChipBtn(c, on: _extra.companion == c, onTap: () => setState(() => _extra = _extra.copyWith(companion: c)))])),
            Field('이동수단', child: Chips(children: [for (final c in transports) ChipBtn(c, on: _extra.transport == c, onTap: () => setState(() => _extra = _extra.copyWith(transport: c)))])),
            Field('출발 시각', child: Align(alignment: Alignment.centerLeft, child: Btn(_extra.startTime, onPressed: _pickTime))),
            Field('이용 시간', child: Chips(children: [for (final h in [3, 4, 5, 6, 8]) ChipBtn('$h시간', on: _extra.hours == h, onTap: () => setState(() => _extra = _extra.copyWith(hours: h)))])),
          ]),
        ),
        Between(
          left: Align(alignment: Alignment.centerLeft, child: Btn('이전', ghost: true, onPressed: () => setState(() => _i = total - 1))),
          right: Btn(_loading ? '분석 중…' : '내 여행 유형 보기', primary: true, onPressed: _loading ? null : _finish),
        ),
      ]);
    }
    final q = questions[_i];
    Widget answer(String k, Choice c) => GestureDetector(
          onTap: () => _choose(k),
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
      Grid(cols: 2, minCols: MediaQuery.sizeOf(context).width > 520 ? 2 : 1, children: [answer('a', q.a), answer('b', q.b)]),
      if (_i > 0) Align(alignment: Alignment.centerLeft, child: Btn('이전 문항', ghost: true, small: true, onPressed: () => setState(() => _i--))),
    ]);
  }
}
