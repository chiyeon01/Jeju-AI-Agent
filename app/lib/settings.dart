// ─────────────────────────────────────────────
// 화면 설정 (이 기기에 저장). 지금은 화면 밝기만 있습니다 — 웹 src/settings.js 와 같은 규칙.
// 밝기는 앱 전체에 어두운 막을 씌워 낮춥니다 (100 = 원래 밝기).
// ─────────────────────────────────────────────
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_ui/material_ui.dart';

const brightnessMin = 40;
const _key = 'jeju-brightness';

/// 화면 밝기 (40~100)
final brightness = ValueNotifier<int>(100);

Future<void> loadSettings() async {
  try {
    brightness.value = ((await SharedPreferences.getInstance()).getInt(_key) ?? 100).clamp(brightnessMin, 100);
  } catch (_) {}
}

Future<void> setBrightness(int v) async {
  brightness.value = v.clamp(brightnessMin, 100);
  try {
    await (await SharedPreferences.getInstance()).setInt(_key, brightness.value);
  } catch (_) {}
}

/// 앱 전체 위에 씌우는 어두운 막 (터치는 그대로 통과)
class Dimmer extends StatelessWidget {
  const Dimmer({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ValueListenableBuilder<int>(
              valueListenable: brightness,
              builder: (context, b, child) => b >= 100 ? const SizedBox.shrink() : ColoredBox(color: Colors.black.withValues(alpha: (100 - b) / 100)),
            ),
          ),
        ),
      ]);
}
