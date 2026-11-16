// 작은 차트 모음: 스파크라인, 주간 추이 선 그래프, 점수 게이지, 별점 (React 의 Charts.jsx)
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// 글자를 캔버스에 그립니다. y 는 SVG 처럼 글자 기준선 위치입니다.
void paintText(
  Canvas canvas,
  String text,
  double x,
  double baselineY, {
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w400,
  String family = kFontBody,
  TextAlign anchor = TextAlign.center,
  Color? strokeColor,
  double strokeWidth = 0,
}) {
  TextPainter make(Paint? fg) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: family,
          fontSize: size,
          fontWeight: weight,
          height: 1,
          color: fg == null ? color : null,
          foreground: fg,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp;
  }

  final fill = make(null);
  final base = fill.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  final dx = switch (anchor) {
    TextAlign.center => x - fill.width / 2,
    TextAlign.end || TextAlign.right => x - fill.width,
    _ => x,
  };
  final offset = Offset(dx, baselineY - base);
  if (strokeColor != null && strokeWidth > 0) {
    final stroke = make(Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..color = strokeColor);
    stroke.paint(canvas, offset);
  }
  fill.paint(canvas, offset);
}

/// 스파크라인
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.data, this.width = 120, this.height = 36, this.color});
  final List<double> data;
  final double width, height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _SparkPainter(data, color ?? context.c.sea)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.data, this.color);
  final List<double> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final mn = data.reduce(math.min), mx = data.reduce(math.max);
    final span = (mx - mn) == 0 ? 1 : mx - mn;
    const pad = 4.0;
    final pts = [
      for (var i = 0; i < data.length; i++)
        Offset(pad + i * (w - pad * 2) / (data.length - 1), h - pad - (data[i] - mn) / span * (h - pad * 2)),
    ];
    final line = Path()..addPolygon(pts, false);
    final area2 = Path()..addPolygon([Offset(pad, h - pad), ...pts, Offset(w - pad, h - pad)], true);
    canvas.drawPath(area2, Paint()..color = color.withValues(alpha: .12));
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    canvas.drawCircle(pts.last, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.data != data || old.color != color;
}

/// 주간 점수 추이 선 그래프 (가로 560 기준 좌표를 화면 폭에 맞춰 늘립니다)
class LineChart extends StatelessWidget {
  const LineChart({super.key, required this.data, this.labels, this.height = 160});
  final List<double> data;
  final List<String>? labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: '주간 상권 건강 점수 추이',
      child: AspectRatio(
        aspectRatio: 560 / height,
        child: CustomPaint(painter: _LinePainter(data, labels, height, c)),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.data, this.labels, this.vh, this.c);
  final List<double> data;
  final List<String>? labels;
  final double vh;
  final AppColors c;

  @override
  void paint(Canvas canvas, Size size) {
    const W = 560.0, L = 32.0, R = 28.0, T = 12.0, B = 24.0;
    final H = vh;
    canvas.save();
    canvas.scale(size.width / W);
    final mn = ((data.reduce(math.min) - 5) / 10).floor() * 10.0;
    final mx = ((data.reduce(math.max) + 5) / 10).ceil() * 10.0;
    double x(int i) => L + i * (W - L - R) / (data.length - 1);
    double y(double v) => T + (1 - (v - mn) / (mx - mn)) * (H - T - B);

    // 눈금 (점선)
    final dash = Paint()
      ..color = c.line
      ..strokeWidth = 1;
    for (var v = mn; v <= mx; v += 10) {
      for (var sx = L; sx < W - R; sx += 6) {
        canvas.drawLine(Offset(sx, y(v)), Offset(math.min(sx + 2, W - R), y(v)), dash);
      }
      paintText(canvas, v.toInt().toString(), L - 8, y(v) + 4, size: 10, color: c.muted, family: kFontMono, anchor: TextAlign.end);
    }
    final pts = [for (var i = 0; i < data.length; i++) Offset(x(i), y(data[i]))];
    final area = Path()..addPolygon([Offset(x(0), H - B), ...pts, Offset(x(data.length - 1), H - B)], true);
    canvas.drawPath(area, Paint()..color = c.accent.withValues(alpha: .1));
    canvas.drawPath(
      Path()..addPolygon(pts, false),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..color = c.accent,
    );
    for (var i = 0; i < pts.length; i++) {
      final last = i == pts.length - 1;
      final r = last ? 4.5 : 2.5;
      canvas.drawCircle(pts[i], r, Paint()..color = last ? c.accent : c.surface);
      canvas.drawCircle(
        pts[i],
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = c.accent,
      );
    }
    final lb = labels;
    if (lb != null) {
      for (var i = 0; i < lb.length; i++) {
        if (i % 2 == 1 || i == lb.length - 1) {
          paintText(canvas, lb[i], x(i), H - 6, size: 10, color: c.muted);
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.data != data || old.c != c;
}

/// 상권 건강 점수 게이지 (270도 원호)
class Gauge extends StatelessWidget {
  const Gauge({super.key, required this.value, this.size = 168, this.label = '상권 건강 점수'});
  final int value;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$label $value점',
        child: SizedBox(width: size, height: size, child: CustomPaint(painter: _GaugePainter(value, context.c))),
      );
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.value, this.c);
  final int value;
  final AppColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final r = s / 2 - 14;
    final rect = Rect.fromCircle(center: Offset(s / 2, s / 2), radius: r);
    final color = value >= 70 ? c.good : value >= 55 ? c.warn : c.bad;
    Paint arc(Color col) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = col;
    const start = 135 * math.pi / 180; // 왼쪽 아래에서 시작
    const sweep = 270 * math.pi / 180;
    canvas.drawArc(rect, start, sweep, false, arc(c.surface2));
    if (value > 0) canvas.drawArc(rect, start, sweep * value / 100, false, arc(color));
    paintText(canvas, '$value', s / 2, s / 2 + 8, size: 44, color: c.ink, family: kFontMono);
    paintText(canvas, '/ 100', s / 2, s / 2 + 32, size: 12, color: c.muted);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.value != value || old.c != c;
}

/// 별점. onChanged 가 있으면 눌러서 고를 수 있습니다.
class Stars extends StatelessWidget {
  const Stars({super.key, required this.value, this.onChanged, this.size});
  final int value;
  final ValueChanged<int>? onChanged;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (onChanged == null) {
      return Semantics(
        label: '별점 $value점',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var n = 1; n <= 5; n++)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Text('★', style: TextStyle(fontSize: size ?? 16, height: 1.2, color: n <= value ? c.accent : c.line)),
              ),
          ],
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var n = 1; n <= 5; n++)
          Semantics(
            button: true,
            selected: value == n,
            label: '$n점',
            child: _Tap(
              onTap: () => onChanged!(n),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 2, 4, 2),
                child: Text('★', style: TextStyle(fontSize: size ?? 25.6, height: 1, color: n <= value ? c.accent : c.line)),
              ),
            ),
          ),
      ],
    );
  }
}

class _Tap extends StatelessWidget {
  const _Tap({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
      );
}
