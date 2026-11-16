// 디자인 토큰 (React 의 styles.css :root 와 같은 값)
// 제주 하늘·바다 색: #87CEEB(하늘) · #87DBEB(바다) · #E4FBFF(물빛 배경)
import 'package:material_ui/material_ui.dart';

class C {
  static const sky = Color(0xFF87CEEB);
  static const sea = Color(0xFF87DBEB);
  static const mist = Color(0xFFE4FBFF);
  static const skyDeep = Color(0xFF1F6F8B); // 하늘색 위 글자·강조
  static const skyInk = Color(0xFF0B3B4F); // 하늘색 버튼 위 글자
  static const bg = mist;
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF2FCFE);
  static const ink = Color(0xFF1B2B33);
  static const muted = Color(0xFF5F7480);
  static const line = Color(0xFFCFEAF2);
  static const good = Color(0xFF2E8B57);
  static const warn = Color(0xFFC98A12);
  static const bad = Color(0xFFD0534A);
  static const goodSoft = Color(0xFFE3F5EA);
  static const warnSoft = Color(0xFFFBF1DC);
  static const badSoft = Color(0xFFFBE5E3);
  static const star = Color(0xFFF5B301);
}

const double kRadius = 14;

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Pretendard',
    scaffoldBackgroundColor: C.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: C.sky, primary: C.skyDeep, surface: C.surface, onSurface: C.ink),
    splashFactory: NoSplash.splashFactory,
    textSelectionTheme: TextSelectionThemeData(cursorColor: C.skyDeep, selectionColor: C.sky.withValues(alpha: .4)),
  );
  return base.copyWith(textTheme: base.textTheme.apply(bodyColor: C.ink, displayColor: C.ink, fontFamily: 'Pretendard'));
}

/// 글자 스타일 도우미
TextStyle tx({double size = 16, FontWeight weight = FontWeight.w400, Color color = C.ink, double height = 1.55}) => TextStyle(
      fontFamily: 'Pretendard',
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
