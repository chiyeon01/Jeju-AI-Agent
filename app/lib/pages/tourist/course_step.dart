// AI 코스: 시간표 · 데이터 근거 · 날씨 전환 · 대화로 고치기 (React 의 CourseStep.jsx)
import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../data/tourist_mock.dart';
import '../../theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/jeju_map.dart';
import '../../widgets/ui.dart';
import 'type_card.dart';

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
  bool _loading = true;
  int _req = 0;
  late final List<(bool, String)> _msgs = [
    (false, '${widget.profile.name}님을 위해 ${widget.origin.name}에서 출발하는 코스를 짰어요. 바꾸고 싶은 점을 말해 주세요.'),
  ];
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _plan();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _plan() async {
    final id = ++_req;
    setState(() => _loading = true);
    final c = await planCourse(profile: widget.profile, origin: widget.origin, opts: _opts);
    if (!mounted || id != _req) return;
    setState(() {
      _course = c;
      _loading = false;
    });
  }

  void _setOpts(CourseOpts o) {
    _opts = o;
    _plan();
  }

  Future<void> _send([String? m]) async {
    final message = (m ?? _text.text).trim();
    if (message.isEmpty) return;
    _text.clear();
    setState(() => _msgs.add((true, message)));
    final res = await chatCourse(message);
    if (!mounted) return;
    setState(() => _msgs.add((false, res.reply)));
    final p = res.patch;
    if (p != null) {
      _setOpts(CourseOpts(
        weather: p.weather ?? _opts.weather,
        seafood: p.seafood ?? _opts.seafood,
        removeCount: _opts.removeCount + p.removeCount,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = weathers[_opts.weather]!;
    final oneCol = screenW(context) <= 900;

    final left = VStack(children: [
      CardHead(
        bottom: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Eyebrow('AI 코스 플래너 · ${widget.origin.name} 출발'),
          Heading('오늘의 ${widget.profile.companion} 코스', size: fsXl),
        ]),
        trailing: Seg<String>(
          options: [for (final e in weathers.entries) (e.key, '${e.value.icon} ${e.value.label}')],
          value: _opts.weather,
          onChanged: (k) => _setOpts(_opts.copyWith(weather: k)),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: Pill('${w.icon} ${w.label} ${w.temp}°C · ${w.note}', tone: _opts.weather == 'rain' ? Tone.warn : Tone.sea, wrap: true),
      ),
      AppCard(
        child: _loading || _course == null
            ? Small('장소 후보를 점수화하고 이동 순서를 정하는 중…', muted: true)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _course!.stops.length; i++)
                    _TimelineItem(
                      stop: _course!.stops[i],
                      first: i == 0,
                      last: i == _course!.stops.length - 1,
                      transport: widget.profile.transport,
                    ),
                ],
              ),
      ),
      const Small('장소 점수 = 성향 적합도 + 데이터 인기도 + 평가 점수 − 혼잡도 − 이동시간 + 날씨 적합도. 이동 순서는 그리디 + 2-opt로 정합니다.', muted: true),
    ]);

    final right = VStack(children: [
      TypeCard(profile: widget.profile, compact: true),
      JejuMap(origin: widget.origin, stops: _course?.stops),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const CardHead(title: Heading.card('대화로 코스 고치기')),
          ChatBox(children: [for (final (me, t) in _msgs) Bubble(text: t, me: me)]),
          const SizedBox(height: 10),
          Chips(children: [for (final s in _suggest) ChipBtn(s, onTap: () => _send(s))]),
          ChatInput(controller: _text, hint: '예: 카페는 바다 보이는 곳으로', button: '보내기', onSend: () => _send()),
        ]),
      ),
      SpaceBetween(
        left: Btn('위치 다시 고르기', kind: BtnKind.ghost, onPressed: widget.onBack),
        right: Btn('여행 끝, 평가하기', kind: BtnKind.primary, onPressed: _course == null ? null : () => widget.onDone(_course!)),
      ),
    ]);

    if (oneCol) return VStack(children: [left, right]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 125, child: left),
      const SizedBox(width: 16),
      Expanded(flex: 100, child: right),
    ]);
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.stop, required this.first, required this.last, required this.transport});
  final Stop stop;
  final bool first, last;
  final String transport;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = stop.place;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(stop.at, textAlign: TextAlign.right, style: tx(context, mono: true, size: fsSm, color: c.muted, height: 1.2)),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 24, child: CustomPaint(painter: _RailPainter(c, first, last))),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!first) Small('↓ ${transport == '렌터카' ? '차로' : '버스로'} 약 ${stop.move}분', muted: true),
                  const SizedBox(height: 2),
                  HWrap(gap: 8, children: [
                    Text(s.name, style: tx(context, size: 16.8, weight: FontWeight.w700)),
                    Pill(kindLabel[s.kind] ?? s.kind),
                    if (s.indoor) const Pill('실내', tone: Tone.sea),
                  ]),
                  HWrap(gap: 8, children: [
                    Stars(value: s.rating.round()),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '${s.rating}', style: const TextStyle(fontFamily: kFontMono)),
                        TextSpan(text: ' · 머무는 시간 ${s.stay}분'),
                      ]),
                      style: tx(context, size: fsSm, color: c.muted),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  VStack(
                    gap: 4,
                    cross: CrossAxisAlignment.start,
                    children: [for (final (src, r) in s.reasons) _Reason(src: src, text: r)],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  _RailPainter(this.c, this.first, this.last);
  final AppColors c;
  final bool first, last;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final top = first ? 22.0 : 0.0;
    final bottom = last ? 22.0 : size.height;
    if (bottom > top) canvas.drawRect(Rect.fromLTRB(cx - 1, top, cx + 1, bottom), Paint()..color = c.line);
    const center = Offset(0, 23); // margin-top 16 + 반지름 7
    canvas.drawCircle(center.translate(cx, 0), 5.5, Paint()..color = c.surface);
    canvas.drawCircle(
      center.translate(cx, 0),
      5.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = c.accent,
    );
  }

  @override
  bool shouldRepaint(covariant _RailPainter old) => old.c != c || old.first != first || old.last != last;
}

class _Reason extends StatelessWidget {
  const _Reason({required this.src, required this.text});
  final String src, text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: c.seaSoft, borderRadius: BorderRadius.circular(4)),
          child: Text(src, style: tx(context, mono: true, size: 10, color: c.sea, height: 1.4)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: tx(context, size: fsSm))),
      ],
    );
  }
}
