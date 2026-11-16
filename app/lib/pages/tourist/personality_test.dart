// 12문항 성향 테스트 + 동행·이동수단·예산 입력 (React 의 PersonalityTest.jsx)
import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../data/tourist_mock.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';

const _sample = {0: 'b', 1: 'a', 2: 'b', 3: 'a', 4: 'a', 5: 'a', 6: 'b', 7: 'b', 8: 'a', 9: 'a', 10: 'b', 11: 'a'};

class PersonalityTest extends StatefulWidget {
  const PersonalityTest({super.key, required this.onDone});
  final ValueChanged<Profile> onDone;

  @override
  State<PersonalityTest> createState() => _PersonalityTestState();
}

class _PersonalityTestState extends State<PersonalityTest> {
  int _i = 0;
  Map<int, String> _answers = {};
  TripExtra _extra = const TripExtra();
  bool _loading = false;

  int get _total => questions.length;

  void _choose(String v) {
    setState(() => _answers = {..._answers, _i: v});
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) setState(() => _i += 1);
    });
  }

  Future<void> _finish([Map<int, String>? ans]) async {
    setState(() => _loading = true);
    final p = await analyzeProfile(ans ?? _answers, _extra);
    if (!mounted) return;
    setState(() => _loading = false);
    widget.onDone(p);
  }

  Future<void> _pickTime() async {
    final parts = _extra.startTime.split(':').map(int.parse).toList();
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: parts[0], minute: parts[1]));
    if (t != null) setState(() => _extra = _extra.copyWith(startTime: '${pad2(t.hour)}:${pad2(t.minute)}'));
  }

  @override
  Widget build(BuildContext context) => _i >= _total ? _buildExtra(context) : _buildQuestion(context);

  Widget _buildExtra(BuildContext context) {
    final c = context.c;
    Widget chips(List<String> opts, String cur, void Function(String) set) => Chips(children: [
          for (final o in opts) ChipBtn(o, on: cur == o, onTap: () => setState(() => set(o))),
        ]);

    final timeBox = Tap(
      onTap: _pickTime,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(rSm),
          border: Border.all(color: c.line),
        ),
        child: Row(children: [
          Expanded(child: Text(_extra.startTime, style: tx(context, height: 1.4))),
          Icon(Icons.schedule, size: 18, color: c.muted),
        ]),
      ),
    );

    final hoursBox = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(rSm),
        border: Border.all(color: c.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _extra.hours,
          isExpanded: true,
          dropdownColor: c.surface,
          style: tx(context, height: 1.4),
          items: [for (final h in [3, 4, 5, 6, 8]) DropdownMenuItem(value: h, child: Text('$h시간'))],
          onChanged: (v) => setState(() => _extra = _extra.copyWith(hours: v)),
        ),
      ),
    );

    return VStack(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Eyebrow('마지막 단계'),
        Heading('누구와, 어떻게 움직이나요?', size: fsXl),
      ]),
      AppCard(
        child: VStack(children: [
          Field(label: '동행', child: chips(companions, _extra.companion, (v) => _extra = _extra.copyWith(companion: v))),
          Field(label: '이동수단', child: chips(transports, _extra.transport, (v) => _extra = _extra.copyWith(transport: v))),
          Field(label: '1인 예산', child: chips(budgets, _extra.budget, (v) => _extra = _extra.copyWith(budget: v))),
          Grid(columns: Grid.g2(context), stretch: false, children: [
            Field(label: '출발 시각', child: timeBox),
            Field(label: '이용 시간', child: hoursBox),
          ]),
        ]),
      ),
      SpaceBetween(
        left: Btn('이전', kind: BtnKind.ghost, onPressed: () => setState(() => _i = _total - 1)),
        right: Btn(_loading ? '성향 분석 중…' : '내 여행 유형 보기', kind: BtnKind.primary, onPressed: _loading ? null : () => _finish()),
      ),
    ]);
  }

  Widget _buildQuestion(BuildContext context) {
    final c = context.c;
    final q = questions[_i];
    final oneCol = screenW(context) <= 520;
    final answers = [
      for (final (k, ch) in [('a', q.a), ('b', q.b)]) _AnswerButton(choice: ch, on: _answers[_i] == k, onTap: () => _choose(k)),
    ];
    return VStack(children: [
      SpaceBetween(
        left: Text('Q${pad2(_i + 1)} / $_total', style: tx(context, mono: true, size: fsSm, color: c.accent)),
        right: Btn(
          _loading ? '분석 중…' : '예시 응답으로 건너뛰기',
          kind: BtnKind.ghost,
          small: true,
          onPressed: _loading
              ? null
              : () {
                  setState(() => _answers = Map.of(_sample));
                  _finish(_sample);
                },
        ),
      ),
      Bar(value: _i / _total, color: c.accent),
      Heading(q.q, size: 25.6),
      Grid(columns: oneCol ? 1 : 2, gap: 12, children: answers),
      Align(
        alignment: Alignment.centerLeft,
        child: Btn('이전 문항', kind: BtnKind.ghost, small: true, onPressed: _i == 0 ? null : () => setState(() => _i = (_i - 1).clamp(0, _total))),
      ),
    ]);
  }
}

class _AnswerButton extends StatefulWidget {
  const _AnswerButton({required this.choice, required this.on, required this.onTap});
  final Choice choice;
  final bool on;
  final VoidCallback onTap;

  @override
  State<_AnswerButton> createState() => _AnswerButtonState();
}

class _AnswerButtonState extends State<_AnswerButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Tap(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.on ? c.accentSoft : c.surface,
            borderRadius: BorderRadius.circular(rMd),
            border: Border.all(color: widget.on || _hover ? c.accent : c.line, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.choice.icon, style: const TextStyle(fontSize: 25.6, height: 1.3)),
              const SizedBox(height: 6),
              Text(widget.choice.t, style: tx(context)),
            ],
          ),
        ),
      ),
    );
  }
}
