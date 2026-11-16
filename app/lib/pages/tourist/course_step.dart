import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../data/tourist_mock.dart';
import '../../theme.dart';
import '../../widgets/kakao_map.dart';
import '../../widgets/ui.dart';

const _suggest = ['저녁은 해산물로 바꿔줘', '1곳 줄여줘', '실내로 바꿔줘'];

class CourseStep extends StatefulWidget {
  const CourseStep({super.key, required this.profile, required this.origin, required this.onDone, required this.onBack});
  final Profile profile;
  final Region origin;
  final ValueChanged<Course> onDone;
  final VoidCallback onBack;
  @override
  State<CourseStep> createState() => _CourseStepState();
}

class _CourseStepState extends State<CourseStep> {
  CourseOpts _opts = const CourseOpts();
  Course? _course;
  late final List<(bool, String)> _msgs = [(false, '${widget.origin.name}에서 출발하는 코스예요. 바꾸고 싶은 점을 말해 주세요.')];
  int _req = 0;

  @override
  void initState() {
    super.initState();
    _plan();
  }

  Future<void> _plan() async {
    final my = ++_req;
    setState(() => _course = null);
    final c = await planCourse(profile: widget.profile, origin: widget.origin, opts: _opts);
    if (mounted && my == _req) setState(() => _course = c);
  }

  Future<void> _send(String m) async {
    setState(() => _msgs.add((true, m)));
    final r = await chatCourse(m);
    if (!mounted) return;
    setState(() => _msgs.add((false, r.reply)));
    final p = r.patch;
    if (p != null) {
      _opts = _opts.copyWith(weather: p.weather, seafood: p.seafood, removeCount: _opts.removeCount + p.removeCount);
      _plan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = weathers[_opts.weather]!;
    final left = VStack(children: [
      Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
        VStack(gap: 2, cross: CrossAxisAlignment.start, children: [
          T.label('${widget.origin.name} 출발 · ${widget.profile.name}'),
          const T.h2('오늘의 추천 코스'),
        ]),
        Seg<String>(options: {for (final e in weathers.entries) e.key: e.value.label}, value: _opts.weather, onChanged: (v) {
          _opts = _opts.copyWith(weather: v);
          _plan();
        }),
      ]),
      Note('${w.icon} ${w.label} ${w.temp}°C · ${w.note}'),
      AppCard(
        child: _course == null
            ? const T.muted('코스를 만드는 중…')
            : Column(children: [
                for (var i = 0; i < _course!.stops.length; i++) _StopRow(stop: _course!.stops[i], first: i == 0, last: i == _course!.stops.length - 1),
              ]),
      ),
    ]);
    final right = VStack(children: [
      KakaoMap(
        lat: widget.origin.lat,
        lon: widget.origin.lon,
        level: 9,
        path: true,
        markers: [for (final s in _course?.stops ?? const <Stop>[]) MapMarker(s.place.lat, s.place.lon, s.place.name)],
      ),
      ChatPanel(title: '대화로 코스 고치기', messages: _msgs, suggestions: _suggest, onSend: _send, hint: '예: 카페는 바다 보이는 곳으로'),
      Between(
        left: Align(alignment: Alignment.centerLeft, child: Btn('위치 다시 고르기', ghost: true, onPressed: widget.onBack)),
        right: Btn('여행 끝, 평가하기', primary: true, onPressed: _course == null ? null : () => widget.onDone(_course!)),
      ),
    ]);
    return Grid(cols: 2, children: [left, right]);
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop, required this.first, required this.last});
  final Stop stop;
  final bool first, last;
  @override
  Widget build(BuildContext context) {
    final p = stop.place;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: C.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 56, child: Text(stop.at, style: tx(weight: FontWeight.w700, color: C.skyDeep))),
        Expanded(
          child: VStack(gap: 4, children: [
            if (!first) T.muted('이동 약 ${stop.move}분'),
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(p.name, style: tx(weight: FontWeight.w700)),
              Pill(kindLabel[p.kind] ?? p.kind),
            ]),
            if (p.reasons.isNotEmpty)
              Text.rich(TextSpan(children: [
                TextSpan(text: '${p.reasons.first.$1}  ', style: tx(size: 13, weight: FontWeight.w600, color: C.skyDeep)),
                TextSpan(text: keepAll(p.reasons.first.$2), style: tx(size: 13, color: C.muted)),
              ])),
          ]),
        ),
      ]),
    );
  }
}
