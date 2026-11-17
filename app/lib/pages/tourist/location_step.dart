import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../data/region_info.dart';
import '../../data/tourist_mock.dart';
import '../../theme.dart';
import '../../widgets/kakao_map.dart';
import '../../widgets/region_art.dart';
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

  // 주소 입력: 서버 주소 검색(카카오) → 가장 가까운 지역, 안 되면 읍·면·동 이름으로
  final _address = TextEditingController();
  bool _finding = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _findAddress() async {
    final q = _address.text.trim();
    if (q.isEmpty || _finding) return;
    setState(() => _finding = true);
    try {
      final hit = await regionFromAddress(q);
      if (!mounted) return;
      setState(() {
        if (hit != null) {
          _region = hit.$1;
          _note = "'${hit.$2}' 기준으로 ${hit.$1.name}에서 시작해요.";
        } else {
          _note = '주소에서 제주 지역을 찾지 못했어요. 읍·면·동 이름(예: 애월읍 곽지리)으로 다시 적거나 아래에서 골라 주세요.';
        }
      });
    } finally {
      if (mounted) setState(() => _finding = false);
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
            Row(children: [
              Expanded(child: AppInput(controller: _address, hint: '주소 입력 (예: 제주시 애월읍 애월해안로 272)', onSubmitted: (_) => _findAddress())),
              const SizedBox(width: 8),
              Btn(_finding ? '찾는 중…' : '주소로 찾기', onPressed: _finding || _regions.isEmpty ? null : _findAddress),
            ]),
            Chips(children: [for (final r in _regions) ChipBtn(r.name, on: _region?.id == r.id, accent: regionInfo[r.id]?.accent, onTap: () => _select(r))]),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(anim), child: child),
              ),
              child: _region == null || regionInfo[_region!.id] == null
                  ? const SizedBox.shrink()
                  : RegionFeature(key: ValueKey(_region!.id), region: _region!, profileCode: widget.profile.code),
            ),
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
          left: Align(alignment: Alignment.centerLeft, child: Btn('여행 정보 다시 고르기', ghost: true, onPressed: widget.onBack)),
          right: Btn(_region == null ? '지역을 골라 주세요' : '${_region!.name}에서 코스 만들기',
              primary: true, onPressed: _region == null ? null : () => widget.onDone(_region!)),
        ),
      ]);
}

const _spotKind = {'cafe': '카페', 'spot': '산책', 'sunset': '노을', 'food': '식당', 'indoor': '실내'};

/// 고른 지역의 특색: 그림 + 해시태그 + 설명 + 갈 만한 곳
class RegionFeature extends StatelessWidget {
  const RegionFeature({super.key, required this.region, required this.profileCode});
  final Region region;
  final String profileCode;

  @override
  Widget build(BuildContext context) {
    final info = regionInfo[region.id]!;
    final spots = places.where((p) => p.region == region.id).toList()..sort((a, b) => b.rating.compareTo(a.rating));
    final fit = fitWith(region.id, profileCode);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 4, color: info.accent),
        LayoutBuilder(builder: (context, box) => SizedBox(height: (box.maxWidth * 125 / 320).clamp(0, 200), child: RegionPhoto(region: region, info: info))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: VStack(gap: 8, children: [
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('${info.emoji} ${region.name}', style: tx(size: 17, weight: FontWeight.w700)),
              if (fit.isNotEmpty) Pill('내 유형과 잘 맞아요 · ${fit.join(', ')}', tone: 'good'),
            ]),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in info.tags)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(color: info.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(999)),
                  child: Text(t, style: tx(size: 12, weight: FontWeight.w600, color: info.accent)),
                ),
            ]),
            T.small(info.desc),
            if (spots.isNotEmpty)
              T.muted('갈 만한 곳: ${spots.take(4).map((p) => '${p.name}(${_spotKind[p.kind]})').join(' · ')}', size: 13),
          ]),
        ),
      ]),
    );
  }
}

/// 지역 대표 사진 (실제 사진, 네이버 이미지 검색). 불러오기 전·실패하면 그림으로
class RegionPhoto extends StatefulWidget {
  const RegionPhoto({super.key, required this.region, required this.info});
  final Region region;
  final RegionInfo info;
  @override
  State<RegionPhoto> createState() => _RegionPhotoState();
}

class _RegionPhotoState extends State<RegionPhoto> {
  List<String> _srcs = const []; // 원본 → 썸네일 순서로 시도
  int _at = 0;

  @override
  void initState() {
    super.initState();
    final q = widget.info.photo;
    searchPhoto(q).then((p) {
      if (!mounted || p == null) return;
      setState(() => _srcs = [for (final k in ['image', 'thumbnail']) if (p[k] is String && (p[k] as String).isNotEmpty) p[k] as String]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final art = RegionArt(widget.info, label: '${widget.region.name} 풍경 그림');
    if (_at >= _srcs.length) return art;
    return Stack(fit: StackFit.expand, children: [
      Image.network(
        _srcs[_at],
        fit: BoxFit.cover,
        semanticLabel: '${widget.region.name} 대표 사진 (${widget.info.photo})',
        loadingBuilder: (_, child, progress) => progress == null ? child : art,
        errorBuilder: (_, _, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _at++);
          });
          return art;
        },
      ),
      Positioned(
        right: 8,
        bottom: 6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: const Color(0x73000000), borderRadius: BorderRadius.circular(6)),
          child: Text('${widget.info.photo} · 네이버 이미지 검색', style: tx(size: 11, color: C.surface)),
        ),
      ),
    ]);
  }
}
