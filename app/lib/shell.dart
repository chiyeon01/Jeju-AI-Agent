// 앱 셸: 상단 바(로고·메뉴·테마 전환) + 모바일 하단 탭 (React 의 Shell.jsx / App.jsx 라우팅)
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'api/client.dart' show isMock;
import 'main.dart' show ThemeController;
import 'pages/console/main_console.dart';
import 'pages/home.dart';
import 'pages/owner/owner_dashboard.dart';
import 'pages/tourist/tourist_flow.dart';
import 'theme.dart';
import 'widgets/ui.dart';

/// 화면 이동 ('/', '/tourist', '/owner', '/console')
class AppNav extends InheritedWidget {
  const AppNav({super.key, required this.route, required this.go, required super.child});
  final String route;
  final ValueChanged<String> go;

  static AppNav of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppNav>()!;

  @override
  bool updateShouldNotify(AppNav old) => old.route != route;
}

const _nav = [
  ('/tourist', '여행 코스', '🧭'),
  ('/owner', '사장님', '🏪'),
  ('/console', 'Main PC', '🖥️'),
];

class Shell extends StatefulWidget {
  const Shell({super.key, required this.theme});
  final ThemeController theme;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  String _route = '/';

  void _go(String r) => setState(() => _route = r);

  Widget _page() => switch (_route) {
        '/tourist' => const TouristFlow(key: ValueKey('/tourist')),
        '/owner' => const OwnerDashboard(key: ValueKey('/owner')),
        '/console' => const MainConsole(key: ValueKey('/console')),
        _ => const HomePage(key: ValueKey('/')),
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final mobile = screenW(context) <= 720;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: c.basalt,
        systemNavigationBarColor: mobile ? c.surface : c.bg,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: PopScope(
        canPop: _route == '/',
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _go('/');
        },
        child: AppNav(
          route: _route,
          go: _go,
          child: Scaffold(
            backgroundColor: c.bg,
            body: Column(
              children: [
                _TopBar(route: _route, go: _go, mobile: mobile, isDark: isDark, onToggle: () => widget.theme.toggle(isDark)),
                Expanded(child: _page()),
              ],
            ),
            bottomNavigationBar: mobile ? _BottomNav(route: _route, go: _go) : null,
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.route, required this.go, required this.mobile, required this.isDark, required this.onToggle});
  final String route;
  final ValueChanged<String> go;
  final bool mobile;
  final bool isDark;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pad = MediaQuery.paddingOf(context);
    return Container(
      color: c.basalt,
      padding: EdgeInsets.only(top: pad.top, left: 16 + pad.left, right: 16 + pad.right),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                Tap(
                  onTap: () => go('/'),
                  child: Row(
                    children: [
                      SizedBox(width: 26, height: 26, child: CustomPaint(painter: LogoPainter(accent: c.accent, sea: c.sea))),
                      const SizedBox(width: 10),
                      Text('제주잇다', style: tx(context, display: true, size: 21.6, color: c.basaltInk)),
                      if (isMock) ...[
                        const SizedBox(width: 10),
                        Opacity(
                          opacity: .65,
                          child: Text('목업 모드',
                              style: tx(context, size: fsXs, color: c.basaltInk, letterSpacing: fsXs * .04)),
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                if (!mobile)
                  for (final (to, label, _) in _nav) ...[
                    const SizedBox(width: 4),
                    _TopLink(label: label, active: route == to, onTap: () => go(to)),
                  ],
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: isDark ? '밝은 화면으로' : '어두운 화면으로',
                  child: Tap(
                    onTap: onToggle,
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: .2)),
                      ),
                      child: Text(isDark ? '☀' : '☾', style: TextStyle(color: c.basaltInk, fontSize: 16, height: 1)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopLink extends StatefulWidget {
  const _TopLink({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_TopLink> createState() => _TopLinkState();
}

class _TopLinkState extends State<_TopLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Tap(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.active ? c.accent : (_hover ? Colors.white.withValues(alpha: .08) : Colors.transparent),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Opacity(
            opacity: widget.active || _hover ? 1 : .75,
            child: Text(widget.label,
                style: tx(context, size: fsSm, color: widget.active ? c.accentInk : c.basaltInk, height: 1.45)),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.route, required this.go});
  final String route;
  final ValueChanged<String> go;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final items = [('/', '홈', '🏠'), ..._nav];
    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final (to, label, icon) in items)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: route == to,
                  child: Tap(
                    onTap: () => go(to),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(icon, style: const TextStyle(fontSize: 16, height: 1.3)),
                          const SizedBox(height: 2),
                          Text(label,
                              style: tx(context,
                                  size: fsXs,
                                  height: 1.3,
                                  weight: route == to ? FontWeight.w700 : FontWeight.w400,
                                  color: route == to ? c.accent : c.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 로고: 한라봉 주황 곡선(오름) + 바다색 원(해)
class LogoPainter extends CustomPainter {
  const LogoPainter({required this.accent, required this.sea, this.background});
  final Color accent, sea;
  final Color? background;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64;
    canvas.scale(s);
    if (background != null) {
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 64, 64), const Radius.circular(14)), Paint()..color = background!);
    }
    final arc = Path()
      ..moveTo(8, 42)
      ..cubicTo(15, 27, 25, 21, 32, 21)
      ..cubicTo(39, 21, 49, 27, 56, 42);
    canvas.drawPath(
      arc,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = accent,
    );
    canvas.drawCircle(const Offset(32, 22), 7, Paint()..color = sea);
  }

  @override
  bool shouldRepaint(covariant LogoPainter old) => old.accent != accent || old.sea != sea;
}
