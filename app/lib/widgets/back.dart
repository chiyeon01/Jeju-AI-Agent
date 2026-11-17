// ─────────────────────────────────────────────
// 왼쪽 위 뒤로가기
//  - 화면 안 단계(여행 코스 단계, 성향 테스트 문항)는 BackRegistration 으로 뒤로가기 동작을 등록합니다.
//  - 상단 바의 AppBackButton 은 가장 나중에 등록된 동작을 부르고, 없으면 Shell 이 넘긴 fallback 을 부릅니다.
//  - 안드로이드 시스템 뒤로 가기도 같은 순서를 따릅니다 (Shell 의 PopScope).
// ─────────────────────────────────────────────
import 'package:material_ui/material_ui.dart';

import '../theme.dart';

class BackController extends ChangeNotifier {
  final List<VoidCallback> _stack = [];

  /// 지금 쓸 화면 안 뒤로가기 (없으면 null)
  VoidCallback? get current => _stack.isEmpty ? null : _stack.last;

  void _add(VoidCallback fn) {
    _stack.add(fn);
    notifyListeners();
  }

  void _remove(VoidCallback fn) {
    if (_stack.remove(fn)) notifyListeners();
  }
}

/// 앱 전체에서 하나만 씁니다
final backController = BackController();

/// onBack 이 null 이 아니면 그동안 상단 뒤로가기가 onBack 을 부릅니다
class BackRegistration extends StatefulWidget {
  const BackRegistration({super.key, required this.onBack, required this.child});
  final VoidCallback? onBack;
  final Widget child;
  @override
  State<BackRegistration> createState() => _BackRegistrationState();
}

class _BackRegistrationState extends State<BackRegistration> {
  VoidCallback? _registered;

  void _sync() {
    final fn = widget.onBack;
    if (fn == _registered) return; // 같은 메서드 tear-off 는 == 로 같습니다
    final old = _registered;
    _registered = fn;
    // 빌드 중에는 상단 바를 다시 그릴 수 없으므로 프레임이 끝난 뒤 반영합니다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (old != null) backController._remove(old);
      if (fn != null && _registered == fn) backController._add(fn);
    });
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(BackRegistration oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    final fn = _registered;
    _registered = null;
    if (fn != null) WidgetsBinding.instance.addPostFrameCallback((_) => backController._remove(fn));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 상단 왼쪽 뒤로가기 아이콘. onPressed 가 null 이면 흐리게
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, required this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: '뒤로가기',
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: C.skyDeep,
        disabledColor: C.skyDeep.withValues(alpha: .3),
        visualDensity: VisualDensity.compact,
      );
}
