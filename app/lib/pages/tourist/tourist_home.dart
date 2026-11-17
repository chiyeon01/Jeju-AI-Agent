// 관광객 첫 화면: 지금까지의 기록을 한눈에 보고, 새 여행을 시작합니다 (웹 TouristHome.jsx 와 같은 내용)
import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../api/history.dart';
import '../../data/tourist_mock.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';
import 'tourist_flow.dart';

/// 여행 코스 메뉴: 기록 홈 ↔ 코스 만들기 흐름
class TouristArea extends StatefulWidget {
  const TouristArea({super.key, required this.user});
  final AppUser user;
  @override
  State<TouristArea> createState() => _TouristAreaState();
}

class _TouristAreaState extends State<TouristArea> {
  bool _flow = false;
  Profile? _start; // "지난 성향으로" 시작하면 그 성향
  int _homeKey = 0;

  void _open([Profile? p]) => setState(() {
        _start = p;
        _flow = true;
      });

  void _close() => setState(() {
        _flow = false;
        _homeKey++; // 기록을 다시 읽음
      });

  @override
  Widget build(BuildContext context) => _flow
      ? TouristFlow(userId: widget.user.id, initialProfile: _start, onExit: _close)
      : TouristHome(key: ValueKey(_homeKey), user: widget.user, onStart: _open);
}

class TouristHome extends StatefulWidget {
  const TouristHome({super.key, required this.user, required this.onStart});
  final AppUser user;
  final void Function([Profile? profile]) onStart;
  @override
  State<TouristHome> createState() => _TouristHomeState();
}

class _TouristHomeState extends State<TouristHome> {
  History? _h;

  @override
  void initState() {
    super.initState();
    loadHistory(widget.user.id).then((h) {
      if (mounted) setState(() => _h = h);
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = _h;
    if (h == null) return const PageBody(children: [Loading()]);
    final last = h.profiles.isEmpty ? null : h.profiles.first;
    final avg = h.avgStars;
    Widget stat(String label, String value) => AppCard(
          padding: 14,
          child: VStack(gap: 2, children: [T.label(label), Text(value, style: tx(size: 22, weight: FontWeight.w700, color: C.skyDeep))]),
        );

    final left = VStack(children: [
      const T.h3('내 여행 유형'),
      if (last != null) ...[
        TypeCard(profile: last.profile),
        T.muted('${fmtWhen(last.at)}에 테스트했어요${h.profiles.length > 1 ? ' · 지금까지 ${h.profiles.length}번' : ''}'),
      ] else
        AppCard(
          child: VStack(cross: CrossAxisAlignment.center, gap: 12, children: [
            const T.muted('아직 성향 테스트를 하지 않았어요.'),
            Btn('5문항 테스트 하기', primary: true, small: true, onPressed: () => widget.onStart()),
          ]),
        ),
      const T.h3('최근 평가'),
      AppCard(
        child: h.reviews.isEmpty
            ? const T.muted('여행을 마치고 평가를 보내면 여기에 모여요.')
            : VStack(gap: 12, children: [
                for (final r in h.reviews.take(5))
                  VStack(gap: 2, children: [
                    Between(
                      left: T(r.name, weight: FontWeight.w700, size: 15),
                      right: Text('★' * r.stars + '☆' * (5 - r.stars), style: tx(size: 13, color: C.star)),
                    ),
                    if (r.text.isNotEmpty) T.small(r.text),
                    T.muted(fmtWhen(r.at), size: 13),
                  ]),
              ]),
      ),
    ]);

    final right = VStack(children: [
      const T.h3('최근 코스'),
      AppCard(
        child: h.courses.isEmpty
            ? VStack(cross: CrossAxisAlignment.center, gap: 12, children: [
                const T.muted('아직 다녀온 코스가 없어요.'),
                Btn('코스 만들기', primary: true, small: true, onPressed: () => widget.onStart()),
              ])
            : VStack(gap: 14, children: [
                for (final c in h.courses.take(6))
                  VStack(gap: 4, children: [
                    Between(left: T('${c.origin} 출발 · ${c.stops.length}곳', weight: FontWeight.w700, size: 15), right: T.muted(fmtWhen(c.at), size: 13)),
                    T.small(c.stops.map((s) => s.name).join(' → ')),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      if (c.weather != null) Pill(c.weather!),
                      for (final k in {for (final s in c.stops) kindLabel[s.kind] ?? ''}.where((x) => x.isNotEmpty).take(3)) Pill(k),
                    ]),
                  ]),
              ]),
      ),
      const T.muted('기록은 이 기기에만 저장돼요. 내 정보에서 지울 수 있어요.'),
    ]);

    return PageBody(children: [
      VStack(gap: 2, cross: CrossAxisAlignment.start, children: [const T.label('내 여행 기록'), T.h2('${widget.user.name}님, 반가워요')]),
      Wrap(spacing: 10, runSpacing: 8, children: [
        if (last != null) Btn('지난 성향으로 코스 만들기', onPressed: () => widget.onStart(last.profile)),
        Btn(last != null ? '성향 테스트부터 새로 시작' : '첫 여행 코스 만들기', primary: true, onPressed: () => widget.onStart()),
      ]),
      Grid(cols: 3, minCols: 3, gap: 8, children: [
        stat('만든 코스', '${h.courses.length}'),
        stat('보낸 평가', '${h.reviews.length}'),
        stat('평균 별점', avg == null ? '-' : avg.toStringAsFixed(1)),
      ]),
      Grid(cols: 2, children: [left, right]),
    ]);
  }
}

