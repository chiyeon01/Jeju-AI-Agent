// 나의 제주 여행 유형 카드 (React 의 TypeCard.jsx)
import 'package:material_ui/material_ui.dart';

import '../../data/tourist_mock.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';

class TypeCard extends StatelessWidget {
  const TypeCard({super.key, required this.profile, this.compact = false});
  final Profile profile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ink = c.basaltInk;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: c.basalt, borderRadius: BorderRadius.circular(rLg)),
      child: VStack(
        cross: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow('나의 제주 여행 유형 · ${profile.code}', color: ink, opacity: .7),
              const SizedBox(height: 4),
              Text(profile.name, style: tx(context, display: true, size: 35.2, color: c.accent)),
              if (!compact) ...[
                const SizedBox(height: 6),
                Opacity(opacity: .85, child: Text(profile.desc, style: tx(context, color: ink))),
              ],
            ],
          ),
          if (!compact)
            VStack(gap: 10, children: [for (final a in axes) _AxisRow(axis: a, value: profile.scores[a.key] ?? 0)]),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final t in profile.tags) Opacity(opacity: .85, child: Text(t, style: tx(context, size: fsSm, color: ink))),
              Opacity(
                opacity: .6,
                child: Text('· ${profile.companion} · ${profile.transport} · ${profile.budget}',
                    style: tx(context, size: fsSm, color: ink)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AxisRow extends StatelessWidget {
  const _AxisRow({required this.axis, required this.value});
  final TasteAxis axis;
  final int value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    TextStyle st(bool strong) => tx(context, size: fsSm, color: c.basaltInk, weight: strong ? FontWeight.w700 : FontWeight.w400);
    return Row(
      children: [
        SizedBox(width: 77, child: Text(axis.left, style: st(value <= 0))),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 14,
            child: LayoutBuilder(builder: (context, box) {
              final x = box.maxWidth * (value + 100) / 200;
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Positioned(
                    left: x - 7,
                    top: 0,
                    child: Container(width: 14, height: 14, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)),
                  ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 77, child: Text(axis.right, textAlign: TextAlign.right, style: st(value > 0))),
      ],
    );
  }
}
