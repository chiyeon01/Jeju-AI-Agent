// 여행 정보: 동행 · 이동 수단(여러 개) · 여행 시작·끝 시각(10분 단위)
// 성향은 그대로여도 시간과 이동 수단은 여행마다 달라서, 지난 유형으로 시작해도 이 단계부터 합니다.
import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../data/tourist_mock.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';
import 'tourist_flow.dart';

/// 06:00 ~ 23:50, 10분 간격
final tripTimes = [
  for (var m = 6 * 60; m < 24 * 60; m += 10) '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}',
];
String _snap(String t) => tripTimes.firstWhere((x) => x.compareTo(t) >= 0, orElse: () => tripTimes.last);

class TripStep extends StatefulWidget {
  const TripStep({super.key, required this.profile, required this.onDone, required this.onBack});
  final Profile profile;
  final ValueChanged<Profile> onDone;
  final VoidCallback onBack;
  @override
  State<TripStep> createState() => _TripStepState();
}

class _TripStepState extends State<TripStep> {
  late String _companion = companions.contains(widget.profile.companion) ? widget.profile.companion : '연인';
  late List<String> _transports = [...widget.profile.extra.transports];
  late String _start = _snap(widget.profile.startTime);
  late String _end = _snap(widget.profile.endTime ?? '18:00');

  String get _bad => _end.compareTo(_start) <= 0
      ? '여행 끝 시각은 시작 시각보다 늦어야 해요.'
      : _transports.isEmpty
          ? '이동 수단을 하나 이상 골라 주세요.'
          : '';

  String get _span {
    int m(String t) => int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3));
    final d = m(_end) - m(_start);
    return d > 0 ? '${d ~/ 60}시간${d % 60 > 0 ? ' ${d % 60}분' : ''}' : '';
  }

  void _toggle(String t) => setState(() => _transports = _transports.contains(t) ? ([..._transports]..remove(t)) : [..._transports, t]);

  void _done() {
    if (_bad.isNotEmpty) return;
    final ordered = [for (final t in transports) if (_transports.contains(t)) t];
    widget.onDone(widget.profile.withExtra(TripExtra(
      companion: _companion,
      transports: ordered,
      startTime: _start,
      endTime: _end,
      hours: tripHours(_start, _end) ?? 8,
    )));
  }

  Widget _timeSelect(String label, String value, ValueChanged<String> onChanged) => Expanded(
        child: Field(
          label,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.line)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: value,
                menuMaxHeight: 320,
                style: tx(),
                items: [for (final t in tripTimes) DropdownMenuItem(value: t, child: Text(t))],
                onChanged: (v) => v == null ? null : setState(() => onChanged(v)),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => VStack(children: [
        TypeCard(profile: widget.profile, showTrip: false),
        const T.h2('이번 여행은 어떻게 다니나요?'),
        AppCard(
          child: VStack(children: [
            Field('동행', child: Chips(children: [for (final c in companions) ChipBtn(c, on: _companion == c, onTap: () => setState(() => _companion = c))])),
            Field('이동 수단 (여러 개 고를 수 있어요)',
                child: Chips(children: [for (final t in transports) ChipBtn(t, on: _transports.contains(t), onTap: () => _toggle(t))])),
            Row(children: [
              _timeSelect('여행 시작', _start, (v) => _start = v),
              const SizedBox(width: 12),
              _timeSelect('여행 끝', _end, (v) => _end = v),
            ]),
            _bad.isNotEmpty ? T.small(_bad, color: C.bad) : T.muted('$_span 여행이에요.'),
          ]),
        ),
        Between(
          left: Align(alignment: Alignment.centerLeft, child: Btn('성향 테스트 다시 하기', ghost: true, onPressed: widget.onBack)),
          right: Btn('출발 지역 고르기', primary: true, onPressed: _bad.isEmpty ? _done : null),
        ),
      ]);
}
