// 제주 지도 (읍면동 실제 경계) — React 의 JejuMap.jsx 를 CustomPainter 로 옮겼습니다.
//  - selected: 지역 id           - onSelect(region): 지역 누르기
//  - origin: 출발 지역            - stops: 코스 장소 (번호 + 경로, 자동 확대)
//  - health: 지역별 점수 색칠 (콘솔) - flows: 인기 코스 흐름선
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../api/client.dart' show Stop;
import '../data/console_mock.dart';
import '../data/jeju_geo.dart';
import '../data/tourist_mock.dart';
import '../theme.dart';
import 'charts.dart' show paintText;

final Offset _halla = project(33.3617, 126.5292);

class JejuMap extends StatefulWidget {
  const JejuMap({super.key, this.selected, this.onSelect, this.origin, this.stops, this.health, this.flows});
  final String? selected;
  final ValueChanged<Region>? onSelect;
  final Region? origin;
  final List<Stop>? stops;
  final Map<String, RegionHealth>? health;
  final List<PopularCourse>? flows;

  @override
  State<JejuMap> createState() => _JejuMapState();
}

class _JejuMapState extends State<JejuMap> {
  String? _pressed; // 누르고 있는 지역 (웹의 hover 효과 대신)

  Rect get _viewBox {
    final stops = widget.stops;
    if (stops == null || stops.isEmpty) return const Rect.fromLTWH(0, 0, mapW, mapH);
    // 코스가 있으면 코스 주변으로 확대합니다.
    final pts = [for (final s in stops) s.place.pos, if (widget.origin != null) widget.origin!.pos];
    final xs = pts.map((p) => p.dx), ys = pts.map((p) => p.dy);
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    const ratio = mapH / mapW;
    var w = math.max(maxX - minX + 140, 240.0);
    var h = w * ratio;
    final needH = maxY - minY + 120;
    if (needH > h) {
      h = needH;
      w = h / ratio;
    }
    final cx = (maxX + minX) / 2, cy = (maxY + minY) / 2;
    return Rect.fromLTWH(cx - w / 2, cy - h / 2, w, h);
  }

  String? _hit(Offset local, Size size) {
    final vb = _viewBox;
    final scale = size.width / vb.width;
    final p = Offset(local.dx / scale + vb.left, local.dy / scale + vb.top);
    for (final e in JejuGeo.instance.dongs.entries) {
      for (final d in e.value) {
        if (d.path.contains(p)) return e.key;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final vb = _viewBox;
    final interactive = widget.onSelect != null;
    return Semantics(
      label: '제주도 지도',
      child: Container(
        decoration: BoxDecoration(
          color: c.seaSoft,
          borderRadius: BorderRadius.circular(rMd),
          border: Border.all(color: c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: vb.width / vb.height,
          child: LayoutBuilder(builder: (context, box) {
            final size = Size(box.maxWidth, box.maxHeight);
            final paint = CustomPaint(
              size: size,
              painter: _MapPainter(
                c: c,
                vb: vb,
                selected: widget.selected,
                pressed: _pressed,
                origin: widget.origin,
                stops: widget.stops,
                health: widget.health,
                flows: widget.flows,
              ),
            );
            if (!interactive) return paint;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTapDown: (d) => setState(() => _pressed = _hit(d.localPosition, size)),
                onTapCancel: () => setState(() => _pressed = null),
                onTapUp: (d) {
                  final id = _hit(d.localPosition, size);
                  setState(() => _pressed = null);
                  if (id != null && regionById[id] != null) widget.onSelect!(regionById[id]!);
                },
                child: paint,
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.c,
    required this.vb,
    this.selected,
    this.pressed,
    this.origin,
    this.stops,
    this.health,
    this.flows,
  });
  final AppColors c;
  final Rect vb;
  final String? selected, pressed;
  final Region? origin;
  final List<Stop>? stops;
  final Map<String, RegionHealth>? health;
  final List<PopularCourse>? flows;

  Paint _stroke(Color col, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeJoin = StrokeJoin.round
    ..color = col;

  Paint _fill(Color col) => Paint()..color = col;

  @override
  void paint(Canvas canvas, Size size) {
    final geo = JejuGeo.instance;
    final scale = size.width / vb.width;
    final k = vb.width / mapW; // 글자·점 크기 보정 배율
    final hasStops = stops != null && stops!.isNotEmpty;

    canvas.save();
    canvas.scale(scale);
    canvas.translate(-vb.left, -vb.top);

    canvas.drawRect(vb, _fill(c.seaSoft));
    // 해안선: 바다색 두꺼운 테두리를 먼저 깔아 섬 윤곽을 만듭니다
    canvas.drawPath(geo.allPath, _fill(c.surface));
    canvas.drawPath(geo.allPath, _stroke(c.sea.withValues(alpha: .45), 5 * k));

    for (final e in geo.dongs.entries) {
      final rid = e.key;
      final h = health?[rid];
      final on = selected == rid;
      Color fill;
      if (h != null) {
        fill = c.scoreColor(h.score).withValues(alpha: .28);
      } else if (on) {
        fill = c.accent.withValues(alpha: .22);
      } else if (pressed == rid) {
        fill = c.accent.withValues(alpha: .14);
      } else {
        fill = c.surface;
      }
      for (final d in e.value) {
        if (h == null && !on) canvas.drawPath(d.path, _fill(c.surface));
        canvas.drawPath(d.path, _fill(fill));
        canvas.drawPath(d.path, _stroke(c.line, .6 * k));
      }
    }
    // 지역(읍면 묶음) 경계 강조
    for (final e in geo.regionPaths.entries) {
      final on = selected == e.key;
      canvas.drawPath(e.value, _stroke(on ? c.accent : c.muted.withValues(alpha: .35), (on ? 2 : .9) * k));
    }

    // 한라산
    canvas.save();
    canvas.translate(_halla.dx, _halla.dy);
    canvas.scale(k);
    final tri = Path()
      ..moveTo(-14, 7)
      ..lineTo(0, -9)
      ..lineTo(14, 7)
      ..close();
    canvas.drawPath(tri, _fill(c.surface2));
    canvas.drawPath(tri, _stroke(c.muted, 1));
    paintText(canvas, '한라산 1,947m', 0, 21, size: 12, color: c.muted);
    canvas.restore();

    // 인기 코스 흐름선 (점선 곡선)
    for (final f in flows ?? const <PopularCourse>[]) {
      final a = regionById[f.from]!, b = regionById[f.to]!;
      final mx = (a.x + b.x) / 2, my = math.min(a.y, b.y) - 40;
      final path = Path()
        ..moveTo(a.x, a.y)
        ..quadraticBezierTo(mx, my, b.x, b.y);
      _drawDashed(canvas, path, _stroke(c.accent.withValues(alpha: .8), 1 + f.count / 120), 5, 4);
    }

    // 지역 이름 · 점수
    for (final r in regions) {
      final h = health?[r.id];
      final on = selected == r.id;
      if (hasStops && !on) {
        paintText(canvas, r.name, r.x, r.y, size: 13 * k, color: c.muted);
        continue;
      }
      if (h != null) {
        final rad = 9 + h.visits / 130;
        canvas.drawCircle(r.pos, rad, _fill(c.surface));
        canvas.drawCircle(r.pos, rad, _stroke(c.scoreColor(h.score), 2));
        paintText(canvas, '${h.score}', r.x, r.y + 4, size: 14, weight: FontWeight.w700, color: c.ink, family: kFontMono);
        paintText(canvas, r.name, r.x, r.y + 22 + h.visits / 130, size: 13, color: c.ink, strokeColor: c.surface, strokeWidth: 3);
      } else {
        paintText(canvas, r.name, r.x, r.y + 4 * k,
            size: (on ? 18 : 14) * k,
            weight: on ? FontWeight.w700 : FontWeight.w500,
            color: on ? c.accent : c.ink,
            strokeColor: c.surface,
            strokeWidth: 3 * k);
      }
    }

    // 코스 경로와 번호
    if (hasStops) {
      final s = stops!;
      if (s.length > 1) {
        canvas.drawPath(Path()..addPolygon([for (final x in s) x.place.pos], false), _stroke(c.accent, 2.5 * k));
      }
      for (var i = 0; i < s.length; i++) {
        final p = s[i].place;
        canvas.drawCircle(p.pos, 11 * k, _fill(c.accent));
        canvas.drawCircle(p.pos, 11 * k, _stroke(c.surface, 2 * k));
        paintText(canvas, '${i + 1}', p.x, p.y + 4 * k, size: 11 * k, weight: FontWeight.w700, color: c.accentInk);
        final odd = i.isOdd;
        paintText(canvas, p.name, p.x + (odd ? -15 : 15) * k, p.y + 4 * k,
            size: 13 * k, color: c.ink, anchor: odd ? TextAlign.end : TextAlign.start, strokeColor: c.surface, strokeWidth: 3 * k);
      }
    }

    // 출발 위치 표시 (코스가 없을 때)
    if (origin != null && !hasStops) {
      canvas.save();
      canvas.translate(origin!.x, origin!.y + 14);
      canvas.scale(k);
      canvas.drawCircle(Offset.zero, 14, _fill(c.sea.withValues(alpha: .2)));
      canvas.drawCircle(Offset.zero, 5, _fill(c.sea));
      canvas.drawCircle(Offset.zero, 5, _stroke(c.surface, 2));
      canvas.restore();
    }

    canvas.restore();
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint, double dash, double gap) {
    for (final ui.PathMetric m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.c != c ||
      old.vb != vb ||
      old.selected != selected ||
      old.pressed != pressed ||
      old.origin != origin ||
      old.stops != stops ||
      old.health != health ||
      old.flows != flows;
}
