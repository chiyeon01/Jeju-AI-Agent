import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../data/tourist_mock.dart';
import '../../widgets/kakao_map.dart';
import '../../widgets/ui.dart';
import 'tourist_flow.dart';

class LocationStep extends StatefulWidget {
  const LocationStep({super.key, required this.profile, required this.onDone, required this.onBack});
  final Profile profile;
  final ValueChanged<Region> onDone;
  final VoidCallback onBack;
  @override
  State<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends State<LocationStep> {
  List<Region> _regions = const [];
  Region? _region;
  String _note = '';

  @override
  void initState() {
    super.initState();
    getRegions().then((r) => mounted ? setState(() => _regions = r) : null);
  }

  Future<void> _pickAt(double lat, double lon, String note) async {
    final r = await nearestRegion(lat, lon);
    if (!mounted) return;
    setState(() {
      _region = r;
      _note = note;
    });
  }

  // 현재 위치: 기기 GPS 를 쓰려면 geolocator 패키지와 위치 권한을 추가하고 _pickAt(위도, 경도, ...) 를 부르면 됩니다.
  void _useCurrent() => setState(() {
        _region = _regions.firstWhere((r) => r.id == 'aewol', orElse: () => _regions.first);
        _note = '시연용으로 현재 위치를 애월읍으로 잡았어요.';
      });

  void _select(Region r) => setState(() {
        _region = r;
        _note = '';
      });

  @override
  Widget build(BuildContext context) => VStack(children: [
        TypeCard(profile: widget.profile),
        AppCard(
          child: VStack(children: [
            Between(left: const T.h3('어디에서 시작할까요?'), right: Btn('현재 위치 사용', small: true, onPressed: _regions.isEmpty ? null : _useCurrent)),
            Chips(children: [for (final r in _regions) ChipBtn(r.name, on: _region?.id == r.id, onTap: () => _select(r))]),
            KakaoMap(
              lat: _region?.lat ?? 33.38,
              lon: _region?.lon ?? 126.55,
              labels: [for (final r in _regions) MapLabel(r.id, r.lat, r.lon, r.name, on: r.id == _region?.id)],
              onLabelTap: (id) => _select(_regions.firstWhere((r) => r.id == id)),
              onMapTap: (lat, lon) => _pickAt(lat, lon, '지도에서 고른 곳과 가장 가까운 지역이에요.'),
            ),
            if (_note.isNotEmpty) Note(_note),
          ]),
        ),
        Between(
          left: Align(alignment: Alignment.centerLeft, child: Btn('테스트 다시 하기', ghost: true, onPressed: widget.onBack)),
          right: Btn(_region == null ? '지역을 골라 주세요' : '${_region!.name}에서 코스 만들기',
              primary: true, onPressed: _region == null ? null : () => widget.onDone(_region!)),
        ),
      ]);
}
