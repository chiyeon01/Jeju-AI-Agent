import 'package:geolocator/geolocator.dart';
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

  bool _locating = false;

  // 제주 범위 (백엔드 /regions/nearest 가 받는 범위와 같음)
  static bool _inJeju(double lat, double lon) => lat >= 32.9 && lat <= 34.1 && lon >= 125.9 && lon <= 127.1;

  void _fallback(String why) {
    if (!mounted) return;
    setState(() {
      _locating = false;
      _region = _regions.firstWhere((r) => r.id == 'aewol', orElse: () => _regions.first);
      _note = '$why 애월읍으로 잡았어요. 지도나 지역을 눌러 바꿀 수 있어요.';
    });
  }

  // 현재 위치: 기기 GPS (권한은 처음 한 번 물어봅니다)
  Future<void> _useCurrent() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _fallback('위치 서비스가 꺼져 있어');
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return _fallback('위치 권한이 없어');
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)),
      );
      if (!_inJeju(p.latitude, p.longitude)) return _fallback('지금 위치가 제주 밖이라');
      await _pickAt(p.latitude, p.longitude, '현재 위치에서 가장 가까운 지역이에요.');
      if (mounted) setState(() => _locating = false);
    } catch (_) {
      _fallback('위치를 가져오지 못해');
    }
  }

  void _select(Region r) => setState(() {
        _region = r;
        _note = '';
      });

  @override
  Widget build(BuildContext context) => VStack(children: [
        TypeCard(profile: widget.profile),
        AppCard(
          child: VStack(children: [
            Between(left: const T.h3('어디에서 시작할까요?'), right: Btn(_locating ? '위치 찾는 중…' : '현재 위치 사용', small: true, onPressed: _regions.isEmpty || _locating ? null : _useCurrent)),
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
