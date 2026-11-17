// 지역 특색 그림 (React 의 components/RegionArt.jsx 와 같은 장면을 CustomPainter 로 그립니다)

import 'package:material_ui/material_ui.dart';

import '../data/region_info.dart';

class RegionArt extends StatelessWidget {
  const RegionArt(this.info, {super.key, required this.label});
  final RegionInfo info;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        image: true,
        child: CustomPaint(painter: _ArtPainter(info), size: Size.infinite),
      );
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.i);
  final RegionInfo i;

  @override
  void paint(Canvas canvas, Size size) {
    // 장면은 320x125 좌표(웹의 viewBox 0 20 320 125)로 그리고, 비율을 지킨 채 칸을 꽉 채웁니다 (CSS slice 와 같음)
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final k = size.width / 320 > size.height / 125 ? size.width / 320 : size.height / 125;
    canvas.translate((size.width - 320 * k) / 2, (size.height - 125 * k) / 2);
    canvas.scale(k);
    canvas.translate(0, -20);
    final all = const Rect.fromLTWH(0, 0, 320, 160);
    canvas.drawRect(all, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [i.from, i.to]).createShader(all));
    Paint fill(Color c, [double o = 1]) => Paint()..color = c.withValues(alpha: o);
    final sun = fill(const Color(0xFFFFF6C8));
    final white = fill(Colors.white, .35);
    final accent = i.accent;
    void sea() {
      final p = Path()..moveTo(0, 120);
      for (var x = 0.0; x < 320; x += 80) {
        p.quadraticBezierTo(x + 20, 112, x + 40, 120);
        p.quadraticBezierTo(x + 60, 128, x + 80, 120);
      }
      p..lineTo(320, 160)..lineTo(0, 160)..close();
      canvas.drawPath(p, white);
    }

    switch (i.art) {
      case 'sunset':
        canvas.drawCircle(const Offset(210, 112), 34, fill(const Color(0xFFFFE08A)));
        canvas.drawRect(const Rect.fromLTWH(0, 112, 320, 48), fill(accent, .35));
        sea();
      case 'city':
        canvas.drawCircle(const Offset(260, 40), 16, sun);
        const b = [[20.0, 70.0, 34.0], [60.0, 50.0, 30.0], [96.0, 80.0, 26.0], [128.0, 40.0, 36.0], [170.0, 64.0, 28.0], [204.0, 56.0, 34.0]];
        for (var k = 0; k < b.length; k++) {
          canvas.drawRRect(RRect.fromLTRBR(b[k][0], b[k][1], b[k][0] + b[k][2], 130, const Radius.circular(3)), fill(accent, .45 + (k % 3) * .15));
        }
        canvas.drawRect(const Rect.fromLTWH(0, 128, 320, 32), fill(Colors.white, .4));
      case 'island':
        canvas.drawCircle(const Offset(60, 40), 18, sun);
        canvas.drawRect(const Rect.fromLTWH(0, 96, 320, 64), fill(accent, .35));
        canvas.drawOval(Rect.fromCenter(center: const Offset(220, 98), width: 96, height: 32), fill(const Color(0xFF3E7D5A), .75));
        sea();
      case 'hills':
        canvas.drawCircle(const Offset(250, 42), 16, sun);
        canvas.drawPath(Path()..moveTo(0, 130)..quadraticBezierTo(60, 60, 120, 120)..quadraticBezierTo(170, 40, 230, 118)..quadraticBezierTo(270, 80, 320, 120)..lineTo(320, 160)..lineTo(0, 160)..close(), fill(accent, .6));
        canvas.drawPath(Path()..moveTo(0, 140)..quadraticBezierTo(80, 110, 160, 138)..quadraticBezierTo(240, 166, 320, 136)..lineTo(320, 160)..lineTo(0, 160)..close(), white);
      case 'cliff':
        canvas.drawCircle(const Offset(70, 40), 16, sun);
        for (var k = 0; k < 7; k++) {
          canvas.drawRect(Rect.fromLTWH(190 + k * 14.0, 70 + (k % 3) * 8.0, 12, 80), fill(accent, .7));
        }
        canvas.drawRect(const Rect.fromLTWH(0, 118, 190, 42), white);
        sea();
      case 'tangerine':
        canvas.drawPath(Path()..moveTo(0, 140)..quadraticBezierTo(160, 100, 320, 140)..lineTo(320, 160)..lineTo(0, 160)..close(), fill(const Color(0xFF6E9E4F), .6));
        for (final (x, y) in [(60.0, 70.0), (110.0, 92.0), (170.0, 64.0), (230.0, 88.0), (280.0, 60.0)]) {
          canvas.drawCircle(Offset(x, y), 18, fill(const Color(0xFFFF9F1C)));
          canvas.drawOval(Rect.fromCenter(center: Offset(x + 6, y - 18), width: 16, height: 8), fill(const Color(0xFF3E7D3A)));
        }
      case 'waves':
        canvas.drawCircle(const Offset(250, 40), 16, sun);
        for (var k = 0; k < 4; k++) {
          final y = 90.0 + k * 18;
          final p = Path()..moveTo(0, y);
          for (var x = 0.0; x < 320; x += 80) {
            p.quadraticBezierTo(x + 20, y - 10, x + 40, y);
            p.quadraticBezierTo(x + 60, y + 10, x + 80, y);
          }
          canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 6..color = (k.isOdd ? Colors.white : accent).withValues(alpha: .7));
        }
      case 'peak':
        canvas.drawCircle(const Offset(70, 70), 22, fill(const Color(0xFFFFD27A)));
        canvas.drawPath(Path()..moveTo(150, 130)..lineTo(180, 62)..quadraticBezierTo(220, 52, 260, 62)..lineTo(290, 130)..close(), fill(accent, .8));
        canvas.drawPath(Path()..moveTo(182, 64)..quadraticBezierTo(220, 74, 258, 64), Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.white.withValues(alpha: .6));
        sea();
      case 'forest':
        canvas.drawPath(Path()..moveTo(0, 132)..quadraticBezierTo(90, 100, 180, 130)..quadraticBezierTo(270, 160, 320, 128)..lineTo(320, 160)..lineTo(0, 160)..close(), fill(accent, .35));
        for (var k = 0; k < 7; k++) {
          final x = 30.0 + k * 40, base = 130.0 - (k % 3) * 8, h = 56.0 + (k % 2) * 14;
          canvas.drawPath(Path()..moveTo(x, base)..lineTo(x + 18, base - h)..lineTo(x + 36, base)..close(), fill(accent, .55 + (k % 3) * .15));
        }
      case 'beach':
        canvas.drawCircle(const Offset(260, 40), 16, sun);
        canvas.drawPath(Path()..moveTo(0, 100)..quadraticBezierTo(60, 90, 120, 100)..quadraticBezierTo(180, 110, 240, 98)..quadraticBezierTo(280, 92, 320, 100)..lineTo(320, 160)..lineTo(0, 160)..close(), fill(accent, .45));
        canvas.drawPath(Path()..moveTo(0, 130)..quadraticBezierTo(100, 118, 200, 132)..quadraticBezierTo(260, 140, 320, 128)..lineTo(320, 160)..lineTo(0, 160)..close(), fill(const Color(0xFFFFF1D0)));
        canvas.drawPath(Path()..moveTo(40, 92)..quadraticBezierTo(70, 50, 100, 92)..close(), fill(const Color(0xFF3E7D5A), .7));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.i != i;
}
