// 카카오맵 (WebView 안에서 카카오맵 JavaScript SDK 를 띄웁니다)
// 키는 env.json 의 KAKAO_JS_KEY. 비어 있으면 안내 문구만 보여 줍니다.
// 카카오 developers > 플랫폼 > Web 사이트 도메인에 http://localhost 를 등록해야 합니다.
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config.dart';
import '../theme.dart';
import 'ui.dart';

class MapLabel {
  const MapLabel(this.id, this.lat, this.lon, this.text, {this.on = false});
  final String id, text;
  final double lat, lon;
  final bool on;
  Map<String, dynamic> toJson() => {'id': id, 'lat': lat, 'lon': lon, 'text': text, 'on': on};
}

class MapMarker {
  const MapMarker(this.lat, this.lon, this.text);
  final double lat, lon;
  final String text;
  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon, 'text': text};
}

class MapCircle {
  const MapCircle(this.lat, this.lon, this.color, this.text, {this.radius = 4000});
  final double lat, lon;
  final int radius;
  final Color color;
  final String text;
  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lon': lon,
        'radius': radius,
        'color': '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        'text': text,
      };
}

class KakaoMap extends StatefulWidget {
  const KakaoMap({
    super.key,
    this.lat = 33.38,
    this.lon = 126.55,
    this.level = 10,
    this.labels = const [],
    this.markers = const [],
    this.path = false,
    this.circles = const [],
    this.onLabelTap,
    this.onMapTap,
    this.height = 260,
  });
  final double lat, lon, height;
  final int level;
  final List<MapLabel> labels;
  final List<MapMarker> markers;
  final bool path;
  final List<MapCircle> circles;
  final ValueChanged<String>? onLabelTap;
  final void Function(double lat, double lon)? onMapTap;

  @override
  State<KakaoMap> createState() => _KakaoMapState();
}

class _KakaoMapState extends State<KakaoMap> {
  WebViewController? _web;
  bool _ready = false;
  bool get _enabled => AppConfig.kakaoJsKey.isNotEmpty && !kIsWeb;

  String get _data => jsonEncode({
        'labels': [for (final l in widget.labels) l.toJson()],
        'markers': [for (final m in widget.markers) m.toJson()],
        'circles': [for (final c in widget.circles) c.toJson()],
        'path': widget.path,
      });

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('Flutter', onMessageReceived: (m) {
        final j = jsonDecode(m.message) as Map<String, dynamic>;
        if (j['type'] == 'ready') {
          _ready = true;
          _push();
        } else if (j['type'] == 'label') {
          widget.onLabelTap?.call(j['id']);
        } else if (j['type'] == 'click') {
          widget.onMapTap?.call((j['lat'] as num).toDouble(), (j['lon'] as num).toDouble());
        }
      })
      ..loadHtmlString(_html(), baseUrl: 'http://localhost');
  }

  @override
  void didUpdateWidget(KakaoMap old) {
    super.didUpdateWidget(old);
    _push();
  }

  void _push() {
    if (_ready) _web?.runJavaScript('render($_data)');
  }

  String _html() => '''
<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
html,body,#map{margin:0;width:100%;height:100%;font-family:sans-serif}
.lb{background:#fff;border:1px solid #cfeaf2;border-radius:999px;padding:2px 8px;font-size:12px;font-weight:600;color:#1b2b33;white-space:nowrap}
.lb.on{background:#87ceeb;border-color:#87ceeb;color:#0b3b4f}
.num{width:24px;height:24px;border-radius:50%;background:#1f6f8b;color:#fff;font-size:12px;font-weight:700;display:flex;align-items:center;justify-content:center;border:2px solid #fff}
</style>
<script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=${AppConfig.kakaoJsKey}&autoload=false"></script>
</head><body><div id="map"></div><script>
var map, layers = [];
function send(o){ Flutter.postMessage(JSON.stringify(o)); }
kakao.maps.load(function(){
  map = new kakao.maps.Map(document.getElementById('map'), { center: new kakao.maps.LatLng(${widget.lat}, ${widget.lon}), level: ${widget.level} });
  kakao.maps.event.addListener(map, 'click', function(e){ send({type:'click', lat:e.latLng.getLat(), lon:e.latLng.getLng()}); });
  send({type:'ready'});
});
function ll(p){ return new kakao.maps.LatLng(p.lat, p.lon); }
function add(l){ l.setMap(map); layers.push(l); }
function render(d){
  layers.forEach(function(l){ l.setMap(null); }); layers = [];
  d.circles.forEach(function(c){
    add(new kakao.maps.Circle({center:ll(c), radius:c.radius, strokeWeight:1, strokeColor:c.color, fillColor:c.color, fillOpacity:0.35}));
    var el = document.createElement('div'); el.className='lb'; el.textContent=c.text;
    add(new kakao.maps.CustomOverlay({position:ll(c), content:el, yAnchor:0.5}));
  });
  d.labels.forEach(function(l){
    var el = document.createElement('div'); el.className = 'lb' + (l.on ? ' on' : ''); el.textContent = l.text;
    el.onclick = function(ev){ ev.stopPropagation(); send({type:'label', id:l.id}); };
    add(new kakao.maps.CustomOverlay({position:ll(l), content:el, yAnchor:1}));
  });
  d.markers.forEach(function(m, i){
    var el = document.createElement('div'); el.className='num'; el.textContent = i + 1; el.title = m.text;
    add(new kakao.maps.CustomOverlay({position:ll(m), content:el, yAnchor:0.5}));
  });
  if (d.path && d.markers.length > 1) add(new kakao.maps.Polyline({path:d.markers.map(ll), strokeWeight:4, strokeColor:'#1f6f8b', strokeOpacity:0.8}));
  if (d.markers.length > 1) { var b = new kakao.maps.LatLngBounds(); d.markers.forEach(function(m){ b.extend(ll(m)); }); map.setBounds(b, 40, 40, 40, 40); }
}
</script></body></html>
''';

  @override
  Widget build(BuildContext context) => Container(
        height: widget.height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: C.mist, borderRadius: BorderRadius.circular(kRadius), border: Border.all(color: C.line)),
        child: _enabled
            ? WebViewWidget(controller: _web!)
            : const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    T('카카오맵 키를 넣으면 지도가 표시됩니다', size: 14, weight: FontWeight.w700, color: C.muted, align: TextAlign.center),
                    T.muted('app/env.json 의 KAKAO_JS_KEY', size: 13, align: TextAlign.center),
                  ]),
                ),
              ),
      );
}
