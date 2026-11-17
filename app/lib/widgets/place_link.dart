// 가게·위치 이름 → 네이버 지도 검색 (앱 안 화면으로 열기), 그리고 대표 사진(서버에 네이버 검색 키가 있을 때)
// (웹 src/components/PlaceLink.jsx 와 같은 역할)
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../api/client.dart';
import '../data/tourist_mock.dart';
import '../theme.dart';
import 'back.dart';
import 'ui.dart';

/// 네이버 지도 검색 화면을 앱 안에서 엽니다 (웹 빌드에서는 주소를 보여 주고 복사)
void openPlace(BuildContext context, String name) {
  final url = naverPlaceUrl(name);
  if (kIsWeb) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('네이버 지도 주소를 복사했어요: $url')));
    return;
  }
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => _NaverPage(name: name, url: url)));
}

class _NaverPage extends StatefulWidget {
  const _NaverPage({required this.name, required this.url});
  final String name, url;
  @override
  State<_NaverPage> createState() => _NaverPageState();
}

class _NaverPageState extends State<_NaverPage> {
  late final _web = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..loadRequest(Uri.parse(widget.url));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.surface,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
              child: Row(children: [
                AppBackButton(onPressed: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 8),
                Expanded(child: T('${widget.name} · 네이버 지도', weight: FontWeight.w700, size: 15, maxLines: 1)),
              ]),
            ),
            const Divider(height: 1, color: C.line),
            Expanded(child: WebViewWidget(controller: _web)),
          ]),
        ),
      );
}

/// 누르면 네이버 지도 검색으로 들어가는 장소 이름
class PlaceLink extends StatelessWidget {
  const PlaceLink(this.name, {super.key, this.size = 16});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
        link: true,
        label: '$name 네이버 지도에서 보기',
        child: GestureDetector(
          onTap: () => openPlace(context, name),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: name),
              TextSpan(text: ' ↗', style: tx(size: size - 3, color: C.muted)),
            ]), style: tx(size: size, weight: FontWeight.w700, color: C.skyDeep).copyWith(decoration: TextDecoration.underline, decorationColor: C.line)),
          ),
        ),
      );
}

/// 장소 대표 사진 (작게). 사진이 없으면 아무것도 그리지 않습니다
class PlacePhoto extends StatefulWidget {
  const PlacePhoto(this.name, {super.key});
  final String name;
  @override
  State<PlacePhoto> createState() => _PlacePhotoState();
}

class _PlacePhotoState extends State<PlacePhoto> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PlacePhoto old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name) _load();
  }

  void _load() {
    _url = null;
    final name = widget.name;
    placePhoto(name).then((u) {
      if (mounted && name == widget.name) setState(() => _url = u);
    });
  }

  @override
  Widget build(BuildContext context) {
    final u = _url;
    if (u == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => openPlace(context, widget.name),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            u,
            width: 120,
            height: 80,
            fit: BoxFit.cover,
            semanticLabel: '${widget.name} 대표 사진',
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// 종류 이름 (미술관·기념품샵 등) + 읍·면·동 주소
List<Widget> placeMeta(String name, {String? kind, String? label, String? addr}) {
  final info = placeInfo(name);
  final tag = label ?? info?.label ?? kindLabel[kind ?? info?.kind];
  final where = (addr != null && addr.isNotEmpty) ? addr : info?.addr;
  return [
    if (tag != null) Pill(tag),
    if (where != null && where.isNotEmpty) T.muted(where, size: 13),
  ];
}
