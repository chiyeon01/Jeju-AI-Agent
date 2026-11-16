// 출발 위치 고르기: 지도에서 지역을 누르거나 현재 위치 사용 (React 의 LocationStep.jsx)
import 'package:material_ui/material_ui.dart';

import '../../data/tourist_mock.dart';
import '../../theme.dart';
import '../../widgets/jeju_map.dart';
import '../../widgets/ui.dart';
import 'type_card.dart';

class LocationStep extends StatefulWidget {
  const LocationStep({super.key, required this.profile, required this.onDone, required this.onBack});
  final Profile profile;
  final ValueChanged<Region> onDone;
  final VoidCallback onBack;

  @override
  State<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends State<LocationStep> {
  Region? _region;
  String _note = '';

  void _useCurrent() {
    // 실제 서비스: 기기 GPS → 가장 가까운 읍면동으로 변환 (백엔드 PostGIS)
    setState(() {
      _region = regionById['aewol'];
      _note = '현재 위치를 애월읍으로 잡았어요. (시연용 가상 위치)';
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = _region;
    return VStack(gap: 20, children: [
      TypeCard(profile: widget.profile),
      AppCard(
        child: VStack(children: [
          CardHead(
            bottom: 0,
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Heading.card('어디에서 시작할까요?'),
              const Small('지도에서 지역을 누르거나 현재 위치를 사용하세요.', muted: true),
            ]),
            trailing: Btn('📍 현재 위치 사용', small: true, onPressed: _useCurrent),
          ),
          JejuMap(
            selected: r?.id,
            origin: r,
            onSelect: (x) => setState(() {
              _region = x;
              _note = '';
            }),
          ),
          SpaceBetween(
            left: r == null
                ? const Small('아직 고른 지역이 없어요.', muted: true)
                : Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: '출발 지역 '),
                      TextSpan(text: r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (_note.isNotEmpty) TextSpan(text: ' · $_note', style: TextStyle(color: c.muted)),
                    ]),
                    style: tx(context, size: fsSm),
                  ),
            right: HWrap(children: [
              Btn('테스트 다시 하기', kind: BtnKind.ghost, onPressed: widget.onBack),
              Btn('AI 코스 만들기', kind: BtnKind.primary, onPressed: r == null ? null : () => widget.onDone(r)),
            ]),
          ),
        ]),
      ),
    ]);
  }
}
