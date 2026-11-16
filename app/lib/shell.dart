// 상단 바 + 역할별 메뉴. 넓은 화면은 상단 메뉴, 720 이하는 하단 탭.
// USER → 여행 코스, MERCHANT → 내 가게, ADMIN → 모든 화면 + 관리
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'api/client.dart' as api;
import 'data/auth_mock.dart';
import 'main.dart';
import 'pages/console/main_console.dart';
import 'pages/owner/owner_dashboard.dart';
import 'pages/tourist/tourist_flow.dart';
import 'theme.dart';
import 'widgets/ui.dart';

class _Menu {
  const _Menu(this.label, this.icon, this.roles, this.build);
  final String label;
  final IconData icon;
  final List<String> roles;
  final Widget Function() build;
}

final _menus = [
  _Menu('여행 코스', Icons.explore_outlined, ['USER', 'ADMIN'], () => const TouristFlow()),
  _Menu('내 가게', Icons.storefront_outlined, ['MERCHANT', 'ADMIN'], () => const OwnerDashboard()),
  _Menu('관리', Icons.dashboard_outlined, ['ADMIN'], () => const MainConsole()),
];

class Shell extends StatefulWidget {
  const Shell({super.key, required this.auth, required this.user});
  final AuthController auth;
  final api.AppUser user;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late final _items = _menus.where((m) => m.roles.contains(widget.user.role)).toList();
  // 첫 화면: 관리자는 '관리', 나머지는 자기 메뉴
  late final int _home = widget.user.role == 'ADMIN' ? _items.length - 1 : 0;
  late int _i = _home;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 720;
    final many = _items.length > 1;
    return PopScope(
      canPop: _i == _home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _i = _home); // 안드로이드 뒤로 가기 → 첫 화면
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(57),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark,
            child: Container(
              decoration: const BoxDecoration(color: C.surface, border: Border(bottom: BorderSide(color: C.line))),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 56,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [C.sky, C.sea])),
                          ),
                          const SizedBox(width: 8),
                          Text('제주잇다', style: tx(size: 18, weight: FontWeight.w800, color: C.skyDeep)),
                          if (wide && many) ...[
                            const SizedBox(width: 20),
                            for (var i = 0; i < _items.length; i++) _TopTab(_items[i].label, _i == i, () => setState(() => _i = i)),
                          ],
                          const Spacer(),
                          if (api.isMock) ...[const Pill('목업'), const SizedBox(width: 10)],
                          if (wide) ...[
                            Text('${widget.user.name} · ${roleLabel[widget.user.role]}', style: tx(size: 13, color: C.muted)),
                            const SizedBox(width: 10),
                          ],
                          Btn('로그아웃', small: true, onPressed: widget.auth.logout),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: KeyedSubtree(key: ValueKey(_i), child: _items[_i].build()),
        bottomNavigationBar: !wide && many
            ? NavigationBar(
                height: 64,
                backgroundColor: C.surface,
                indicatorColor: C.mist,
                selectedIndex: _i,
                onDestinationSelected: (i) => setState(() => _i = i),
                destinations: [for (final m in _items) NavigationDestination(icon: Icon(m.icon, color: C.muted), selectedIcon: Icon(m.icon, color: C.skyDeep), label: m.label)],
              )
            : null,
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  const _TopTab(this.label, this.on, this.onTap);
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: on ? C.mist : Colors.transparent, borderRadius: BorderRadius.circular(999)),
            child: Text(label, style: tx(size: 14, weight: on ? FontWeight.w700 : FontWeight.w400, color: on ? C.skyDeep : C.muted)),
          ),
        ),
      );
}
