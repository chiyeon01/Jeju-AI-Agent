// ─────────────────────────────────────────────
// GPT 프롬프트 모음
// 프롬프트 문장은 assets/prompts/*.md 에 있습니다 (웹 frontend/src/prompts 와 같은 파일).
// 말투나 규칙을 바꿀 때는 .md 만 고치면 됩니다.
//   await renderPrompt('course_plan', {'context': '...', 'variation': '...'})
// .md 안의 {{이름}} 은 넘긴 값으로 바뀌고, 맨 위 <!-- --> 주석은 GPT 에 보내지 않습니다.
// ─────────────────────────────────────────────
import 'package:flutter/services.dart' show rootBundle;

final _cache = <String, String>{};
final _comment = RegExp(r'^\s*<!--[\s\S]*?-->\s*');
final _var = RegExp(r'\{\{\s*(\w+)\s*\}\}');

/// 테스트에서 파일 대신 문자열을 넣을 때 씁니다
void debugSetPrompt(String name, String text) => _cache[name] = text;

Future<String> renderPrompt(String name, Map<String, Object?> values) async {
  final raw = _cache[name] ??= await rootBundle.loadString('assets/prompts/$name.md');
  final text = raw.replaceFirst(_comment, '').trim();
  return text.replaceAllMapped(_var, (m) {
    final k = m.group(1)!;
    if (!values.containsKey(k)) throw StateError('프롬프트 $name.md 에 값이 없는 변수가 있어요: $k');
    return '${values[k]}';
  });
}
