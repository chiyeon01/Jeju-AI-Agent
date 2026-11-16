// 방문 후 평가: 별점 + 한 줄 평 (React 의 ReviewStep.jsx)
import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../data/tourist_mock.dart';
import '../../shell.dart';
import '../../theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/ui.dart';

class ReviewStep extends StatefulWidget {
  const ReviewStep({super.key, required this.profile, required this.course, required this.onRestart});
  final Profile profile;
  final Course course;
  final VoidCallback onRestart;

  @override
  State<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<ReviewStep> {
  late final List<(Stop, bool)> _stops;
  late final Map<String, int> _stars;
  late final Map<String, TextEditingController> _texts;
  int? _accepted; // 저장된 평가 수
  bool _skipped = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // 방문 인증: 코스에 포함되고 해당 시간대 반경 내 있었던 장소만 평가 가능 (시연에서는 마지막 장소를 미인증으로 표시)
    final arr = widget.course.stops;
    _stops = [for (var i = 0; i < arr.length; i++) (arr[i], i < arr.length - 1 || arr.length <= 2)];
    _stars = {for (final (s, _) in _stops) s.place.id: 0};
    _texts = {for (final (s, _) in _stops) s.place.id: TextEditingController()};
  }

  @override
  void dispose() {
    for (final t in _texts.values) {
      t.dispose();
    }
    super.dispose();
  }

  List<Stop> get _ready => [for (final (s, ok) in _stops) if (ok && _stars[s.place.id]! > 0) s];

  Future<void> _submit() async {
    setState(() => _sending = true);
    final n = await submitReviews([
      for (final s in _ready)
        {'placeId': s.place.id, 'stars': _stars[s.place.id], 'text': _texts[s.place.id]!.text, 'profile': widget.profile.code},
    ]);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _accepted = n;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final nav = AppNav.of(context);

    if (_skipped) {
      return AppCard(
        raised: true,
        child: VStack(cross: CrossAxisAlignment.start, children: [
          const Eyebrow('평가 건너뜀'),
          const Heading('즐거운 여행이었길 바라요'),
          Text('이번 코스는 평가 없이 마쳤어요. 코스 선택 기록만 익명으로 인기 코스 집계에 쓰여요.', style: tx(context, color: c.muted)),
          HWrap(children: [
            Btn('새 코스 만들기', kind: BtnKind.primary, onPressed: widget.onRestart),
            Btn('처음으로', onPressed: () => nav.go('/')),
          ]),
        ]),
      );
    }

    if (_accepted != null) {
      Widget li(InlineSpan span) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 19, child: Text('•', style: tx(context))),
            Expanded(child: Text.rich(span, style: tx(context))),
          ]);
      const b = TextStyle(fontWeight: FontWeight.w700);
      return AppCard(
        raised: true,
        child: VStack(cross: CrossAxisAlignment.start, children: [
          Eyebrow('평가 $_accepted건 저장됨'),
          const Heading('고마워요! 남긴 평가가 이렇게 쓰여요'),
          VStack(gap: 8, children: [
            li(const TextSpan(children: [
              TextSpan(text: '각 매장의 '),
              TextSpan(text: '고객 만족 지수', style: b),
              TextSpan(text: '와 '),
              TextSpan(text: '성향 적합도', style: b),
              TextSpan(text: '가 바로 다시 계산돼 사장님 대시보드에 반영돼요.'),
            ])),
            li(TextSpan(children: [
              TextSpan(text: widget.profile.name, style: b),
              const TextSpan(text: ' 유형의 장소 선호 행렬이 갱신돼, 비슷한 성향의 다음 여행자 코스가 더 정확해져요.'),
            ])),
            li(const TextSpan(text: '평가는 개인을 알아볼 수 없게 처리된 뒤 제주시 Main PC 통합 저장소에 쌓여요.')),
          ]),
          Btn('새 코스 만들기', kind: BtnKind.primary, onPressed: widget.onRestart),
        ]),
      );
    }

    final ready = _ready;
    return VStack(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Eyebrow('방문 후 평가'),
        const Heading('오늘 다녀온 곳은 어땠나요?'),
        const SizedBox(height: 4),
        const Small('별점과 한 줄 평만 남기면 돼요. 방문이 확인된 장소만 평가할 수 있어요.', muted: true),
      ]),
      for (final (s, verified) in _stops)
        Opacity(
          opacity: verified ? 1 : .6,
          child: IgnorePointer(
            ignoring: !verified,
            child: AppCard(
              child: VStack(gap: 10, cross: CrossAxisAlignment.start, children: [
                SpaceBetween(
                  left: HWrap(gap: 8, children: [
                    Num(s.at, color: c.muted),
                    Text(s.place.name, style: tx(context, weight: FontWeight.w700)),
                  ]),
                  right: verified ? const Pill('✓ 방문 인증 · 반경 150m', tone: Tone.good) : const Pill('방문 확인 안 됨'),
                ),
                Stars(value: _stars[s.place.id]!, onChanged: (n) => setState(() => _stars[s.place.id] = n)),
                AppInput(
                  controller: _texts[s.place.id]!,
                  maxLength: 100,
                  enabled: verified,
                  hint: '한 줄 평 (선택, 100자 이내)',
                ),
              ]),
            ),
          ),
        ),
      SpaceBetween(
        left: const Small('계정당 하루 평가 횟수가 제한돼요.', muted: true),
        right: HWrap(children: [
          Btn('평가 안 하기', kind: BtnKind.ghost, onPressed: _sending ? null : () => setState(() => _skipped = true)),
          Btn(
            _sending ? '보내는 중…' : '평가 ${ready.length}건 보내기',
            kind: BtnKind.primary,
            onPressed: ready.isEmpty || _sending ? null : _submit,
          ),
        ]),
      ),
    ]);
  }
}
