// 작은 차트: 선 그래프, 별점
import 'package:material_ui/material_ui.dart';

import '../theme.dart';

class LineChart extends StatelessWidget {
  const LineChart({super.key, required this.data, required this.labels, this.height = 160});
  final List<double> data;
  final List<String> labels;
  final double height;
  @override
  Widget build(BuildContext context) =>
      SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _LinePainter(data, labels)));
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.data, this.labels);
  final List<double> data;
  final List<String> labels;

  void _text(Canvas c, String s, Offset at, {TextAlign align = TextAlign.center}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: tx(size: 11, color: C.muted, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = align == TextAlign.right ? at.dx - tp.width : at.dx - tp.width / 2;
    tp.paint(c, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const l = 30.0, r = 16.0, t = 12.0, b = 24.0;
    final lo = ((data.reduce((a, b) => a < b ? a : b) - 5) / 10).floor() * 10.0;
    final hi = ((data.reduce((a, b) => a > b ? a : b) + 5) / 10).ceil() * 10.0;
    double x(int i) => l + i * (size.width - l - r) / (data.length - 1);
    double y(double v) => t + (1 - (v - lo) / (hi - lo)) * (size.height - t - b);
    final grid = Paint()..color = C.line;
    for (var v = lo; v <= hi; v += 10) {
      canvas.drawLine(Offset(l, y(v)), Offset(size.width - r, y(v)), grid);
      _text(canvas, v.toStringAsFixed(0), Offset(l - 8, y(v)), align: TextAlign.right);
    }
    final line = Path()..moveTo(x(0), y(data[0]));
    for (var i = 1; i < data.length; i++) {
      line.lineTo(x(i), y(data[i]));
    }
    final area = Path.from(line)
      ..lineTo(x(data.length - 1), size.height - b)
      ..lineTo(x(0), size.height - b)
      ..close();
    canvas.drawPath(area, Paint()..color = C.sky.withValues(alpha: .25));
    canvas.drawPath(line, Paint()
      ..color = C.skyDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(Offset(x(data.length - 1), y(data.last)), 4.5, Paint()..color = C.skyDeep);
    for (var i = 0; i < labels.length; i++) {
      if (i % 3 == 2 || i == labels.length - 1) _text(canvas, labels[i], Offset(x(i), size.height - 8));
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.data != data;
}

/// 별점. onChanged 가 있으면 누를 수 있습니다.
class Stars extends StatelessWidget {
  const Stars({super.key, required this.value, this.onChanged});
  final int value;
  final ValueChanged<int>? onChanged;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var n = 1; n <= 5; n++)
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(n),
            child: Semantics(
              label: onChanged == null ? null : '$n점',
              button: onChanged != null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Text('★', style: TextStyle(fontSize: onChanged == null ? 15 : 26, height: 1, color: n <= value ? C.star : C.line)),
              ),
            ),
          ),
      ]);
}
