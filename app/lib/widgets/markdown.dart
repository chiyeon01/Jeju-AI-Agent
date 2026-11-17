// Agent 가 쓴 짧은 마크다운(제목 ##, 글머리표 -, 굵게 **)만 그립니다. (React 의 components/Markdown.jsx 와 같음)
import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'ui.dart';

List<TextSpan> _inline(String text, {double size = 14, FontWeight weight = FontWeight.w400}) => [
      for (final part in _split(text))
        part.startsWith('**') && part.endsWith('**') && part.length > 4
            ? TextSpan(text: keepAll(part.substring(2, part.length - 2)), style: tx(size: size, weight: FontWeight.w700))
            : TextSpan(text: keepAll(part), style: tx(size: size, weight: weight)),
    ];

List<String> _split(String text) {
  final out = <String>[];
  var last = 0;
  for (final m in RegExp(r'\*\*[^*]+\*\*').allMatches(text)) {
    if (m.start > last) out.add(text.substring(last, m.start));
    out.add(m.group(0)!);
    last = m.end;
  }
  if (last < text.length) out.add(text.substring(last));
  return out;
}

class Markdown extends StatelessWidget {
  const Markdown(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final kids = <Widget>[];
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final h = RegExp(r'^#{1,4}\s+(.*)').firstMatch(line);
      final li = RegExp(r'^(?:[-*•]|\d+[.)])\s+(.*)').firstMatch(line);
      if (h != null) {
        kids.add(Padding(
          padding: EdgeInsets.only(top: kids.isEmpty ? 0 : 10),
          child: Text.rich(TextSpan(children: _inline(h.group(1)!, size: 15, weight: FontWeight.w700))),
        ));
      } else if (li != null) {
        kids.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('•  ', style: tx(size: 14, color: C.muted)),
          Expanded(child: Text.rich(TextSpan(children: _inline(li.group(1)!)))),
        ]));
      } else {
        kids.add(Text.rich(TextSpan(children: _inline(line))));
      }
    }
    return VStack(gap: 4, children: kids);
  }
}
