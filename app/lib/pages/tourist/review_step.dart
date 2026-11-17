import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../theme.dart';
import '../../data/tourist_mock.dart';
import '../../widgets/charts.dart';
import '../../widgets/ui.dart';

class ReviewStep extends StatefulWidget {
  const ReviewStep({super.key, required this.profile, required this.course, required this.onRestart, this.onSent});
  final Profile profile;
  final Course course;
  final VoidCallback onRestart;

  /// 평가를 보낸 뒤 (내 기록에 남김)
  final void Function(List<({String placeId, String name, int stars, String text})> items)? onSent;
  @override
  State<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<ReviewStep> {
  late final Map<String, int> _stars = {for (final s in widget.course.stops) s.place.id: 0};
  late final Map<String, TextEditingController> _text = {for (final s in widget.course.stops) s.place.id: TextEditingController()};
  int? _accepted;
  bool _sending = false;
  String _error = '';

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _error = '';
    });
    final picked = [for (final s in widget.course.stops) if (_stars[s.place.id]! > 0) s];
    try {
      final n = await submitReviews([
        for (final s in picked) {'placeId': s.place.id, 'stars': _stars[s.place.id], 'text': _text[s.place.id]!.text, 'profile': widget.profile.code},
      ]);
      widget.onSent?.call([
        for (final s in picked) (placeId: s.place.id, name: s.place.name, stars: _stars[s.place.id]!, text: _text[s.place.id]!.text.trim()),
      ]);
      if (mounted) setState(() => _accepted = n);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted != null) {
      return AppCard(
        child: VStack(cross: CrossAxisAlignment.start, children: [
          const T.h2('고마워요!'),
          T.muted('평가 $_accepted건이 저장됐어요. 가게 점수와 다음 여행자의 코스 추천에 반영돼요.', size: 15),
          Btn('내 기록 보기', primary: true, onPressed: widget.onRestart),
        ]),
      );
    }
    final ready = _stars.values.where((v) => v > 0).length;
    return VStack(children: [
      const T.h2('오늘 다녀온 곳은 어땠나요?'),
      for (final s in widget.course.stops)
        AppCard(
          child: VStack(gap: 10, children: [
            Wrap(spacing: 10, runSpacing: 6, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
              T.h3(s.place.name),
              Stars(value: _stars[s.place.id]!, onChanged: (n) => setState(() => _stars[s.place.id] = n)),
            ]),
            AppInput(controller: _text[s.place.id]!, hint: '한 줄 평 (선택)', maxLength: 100),
          ]),
        ),
      if (_error.isNotEmpty) T.small(_error, color: C.bad),
      Between(
        left: Align(alignment: Alignment.centerLeft, child: Btn('건너뛰기', ghost: true, onPressed: widget.onRestart)),
        right: Btn(_sending ? '보내는 중…' : '평가 $ready건 보내기', primary: true, onPressed: ready == 0 || _sending ? null : _submit),
      ),
    ]);
  }
}
