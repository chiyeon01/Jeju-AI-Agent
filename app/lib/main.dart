// 제주잇다 Flutter 앱 진입점
// 로그인 상태에 따라 로그인 화면 또는 역할별 화면(Shell)을 보여 줍니다.
import 'package:material_ui/material_ui.dart';

import 'api/client.dart' as api;
import 'pages/login.dart';
import 'settings.dart';
import 'shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final user = await api.loadSession();
  await loadSettings(); // 저장해 둔 화면 밝기
  runApp(ItdaApp(initialUser: user));
}

/// 로그인한 사용자. null 이면 로그인 전
class AuthController extends ValueNotifier<api.AppUser?> {
  AuthController(super.value) {
    api.onUnauthorized = () => value = null; // 토큰 갱신 실패 → 로그인 화면
  }

  Future<api.AppUser> login(String email, String password) async => value = await api.login(email, password);

  Future<void> logout() async {
    await api.logout();
    value = null;
  }
}

class ItdaApp extends StatefulWidget {
  const ItdaApp({super.key, this.initialUser});
  final api.AppUser? initialUser;

  @override
  State<ItdaApp> createState() => _ItdaAppState();
}

class _ItdaAppState extends State<ItdaApp> {
  late final AuthController _auth = AuthController(widget.initialUser);

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '제주잇다',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        builder: (context, child) => Dimmer(child: child ?? const SizedBox.shrink()),
        home: ValueListenableBuilder<api.AppUser?>(
          valueListenable: _auth,
          builder: (context, user, _) => user == null
              ? LoginPage(auth: _auth)
              : Shell(key: ValueKey(user.id), auth: _auth, user: user),
        ),
      );
}
