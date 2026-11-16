// 제주잇다 Flutter 앱 진입점
// React 프론트엔드(frontend/)와 같은 화면·기능·디자인을 Flutter 로 옮겼습니다.
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/jeju_geo.dart';
import 'shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JejuGeo.load();
  String saved = '';
  try {
    final prefs = await SharedPreferences.getInstance();
    saved = prefs.getString('itda-theme') ?? '';
  } catch (_) {
    // 저장소를 쓸 수 없는 환경
  }
  runApp(ItdaApp(initialTheme: saved));
}

/// 밝은/어두운 화면 설정. '' 이면 기기 설정을 따릅니다.
class ThemeController extends ValueNotifier<String> {
  ThemeController(super.value);

  Future<void> toggle(bool isDarkNow) async {
    value = isDarkNow ? 'light' : 'dark';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('itda-theme', value);
    } catch (_) {
      // 저장 불가 환경
    }
  }
}

class ItdaApp extends StatefulWidget {
  const ItdaApp({super.key, this.initialTheme = ''});
  final String initialTheme;

  @override
  State<ItdaApp> createState() => _ItdaAppState();
}

class _ItdaAppState extends State<ItdaApp> {
  late final ThemeController _theme = ThemeController(widget.initialTheme);

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: _theme,
      builder: (context, mode, _) => MaterialApp(
        title: '제주잇다',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(AppColors.light),
        darkTheme: buildTheme(AppColors.darkColors),
        themeMode: mode == 'dark'
            ? ThemeMode.dark
            : mode == 'light'
                ? ThemeMode.light
                : ThemeMode.system,
        home: Shell(theme: _theme),
      ),
    );
  }
}
