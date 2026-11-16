// 디자인 토큰: React 프론트엔드 styles.css 의 :root 변수를 그대로 옮겼습니다.
// 현무암 돌담처럼 단단한 회색 바탕 위에, 한라봉 주황(행동)과 바다 청록(데이터)이 얹히는 구조입니다.
import 'package:material_ui/material_ui.dart';

const String kFontBody = 'Pretendard';
const String kFontDisplay = 'DoHyeon';
const String kFontMono = 'PlexMono';

// 글자 크기 (1rem = 16)
const double fsXs = 12, fsSm = 14, fsMd = 16, fsLg = 20, fsXl = 28, fs2xl = 40;
// 모서리
const double rSm = 6, rMd = 12, rLg = 20;

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.dark,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.muted,
    required this.line,
    required this.basalt,
    required this.basaltInk,
    required this.accent,
    required this.accentSoft,
    required this.accentInk,
    required this.sea,
    required this.seaSoft,
    required this.good,
    required this.warn,
    required this.bad,
    required this.goodSoft,
    required this.warnSoft,
    required this.badSoft,
  });

  final bool dark;
  final Color bg, surface, surface2, ink, muted, line, basalt, basaltInk;
  final Color accent, accentSoft, accentInk, sea, seaSoft;
  final Color good, warn, bad, goodSoft, warnSoft, badSoft;

  static const light = AppColors(
    dark: false,
    bg: Color(0xFFF1F2EF),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFE7E9E5),
    ink: Color(0xFF1D2021),
    muted: Color(0xFF5D6462),
    line: Color(0xFFD5D8D3),
    basalt: Color(0xFF2F3133),
    basaltInk: Color(0xFFF4F5F3),
    accent: Color(0xFFDD6F1F), // 한라봉
    accentSoft: Color(0xFFFBE6D5),
    accentInk: Color(0xFFFFFFFF),
    sea: Color(0xFF17806F), // 바다
    seaSoft: Color(0xFFD6EFEA),
    good: Color(0xFF2F8A4F),
    warn: Color(0xFFB7800D),
    bad: Color(0xFFC0413A),
    goodSoft: Color(0xFFDCEFE2),
    warnSoft: Color(0xFFF6EAD0),
    badSoft: Color(0xFFF6DCDA),
  );

  static const darkColors = AppColors(
    dark: true,
    bg: Color(0xFF141617),
    surface: Color(0xFF1D2021),
    surface2: Color(0xFF272B2C),
    ink: Color(0xFFECEEEC),
    muted: Color(0xFF9CA39F),
    line: Color(0xFF343A3B),
    basalt: Color(0xFF0D0F10),
    basaltInk: Color(0xFFECEEEC),
    accent: Color(0xFFF08D3E),
    accentSoft: Color(0xFF3E2A1A),
    accentInk: Color(0xFF1A1210),
    sea: Color(0xFF3DBBA8),
    seaSoft: Color(0xFF15332E),
    good: Color(0xFF57C27C),
    warn: Color(0xFFE2B04A),
    bad: Color(0xFFEC6E64),
    goodSoft: Color(0xFF17301F),
    warnSoft: Color(0xFF362B12),
    badSoft: Color(0xFF3A1C1A),
  );

  /// --shadow
  List<BoxShadow> get shadow => dark
      ? const [
          BoxShadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, 6)),
        ]
      : const [
          BoxShadow(color: Color(0x0F1E2223), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x0F1E2223), blurRadius: 20, offset: Offset(0, 6)),
        ];

  /// 지역·매장 점수 색 (70+ good, 60+ sea, 55+ warn, 그 외 bad)
  Color scoreColor(num s) => s >= 70 ? good : s >= 60 ? sea : s >= 55 ? warn : bad;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) =>
      other is AppColors && t >= .5 ? other : this;
}

ThemeData buildTheme(AppColors c) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: c.dark ? Brightness.dark : Brightness.light,
    fontFamily: kFontBody,
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: c.dark ? Brightness.dark : Brightness.light,
      primary: c.accent,
      onPrimary: c.accentInk,
      surface: c.surface,
      onSurface: c.ink,
    ),
    splashFactory: NoSplash.splashFactory,
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.accent, selectionColor: c.accent.withValues(alpha: .3)),
    extensions: [c],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink, fontFamily: kFontBody),
  );
}

extension AppThemeX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}

/// 글자 스타일 도우미. display = Do Hyeon(제목), mono = IBM Plex Mono(숫자).
TextStyle tx(
  BuildContext context, {
  double size = fsMd,
  FontWeight weight = FontWeight.w400,
  Color? color,
  bool mono = false,
  bool display = false,
  double? height,
  double? letterSpacing,
}) {
  final c = context.c;
  return TextStyle(
    fontFamily: display ? kFontDisplay : mono ? kFontMono : kFontBody,
    fontSize: size,
    fontWeight: display ? FontWeight.w400 : weight,
    color: color ?? c.ink,
    height: height ?? (display ? 1.25 : 1.6),
    letterSpacing: letterSpacing ?? (display ? size * .01 : null),
    fontFeatures: mono ? const [FontFeature.tabularFigures()] : null,
  );
}
