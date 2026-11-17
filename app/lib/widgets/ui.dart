// 공통 UI 조각 (React 의 styles.css 클래스와 1:1 로 대응)
import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// 한글 단어 중간에서 줄이 바뀌지 않게 합니다 (CSS word-break: keep-all)
String keepAll(String s) => s.replaceAllMapped(RegExp(r'(?<=[가-힣])(?=[가-힣])'), (_) => '⁠');
String comma(num n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// 제목·본문 텍스트
class T extends StatelessWidget {
  const T(this.text, {super.key, this.size = 16, this.weight = FontWeight.w400, this.color = C.ink, this.align, this.maxLines});
  const T.h1(this.text, {super.key, this.color = C.ink, this.align, this.maxLines}) : size = 26, weight = FontWeight.w700;
  const T.h2(this.text, {super.key, this.color = C.ink, this.align, this.maxLines}) : size = 21, weight = FontWeight.w700;
  const T.h3(this.text, {super.key, this.color = C.ink, this.align, this.maxLines}) : size = 17, weight = FontWeight.w700;
  const T.small(this.text, {super.key, this.color = C.ink, this.align, this.maxLines}) : size = 14, weight = FontWeight.w400;
  const T.muted(this.text, {super.key, this.size = 14, this.align, this.maxLines}) : weight = FontWeight.w400, color = C.muted;
  const T.label(this.text, {super.key, this.align, this.maxLines}) : size = 13, weight = FontWeight.w600, color = C.muted;
  final String text;
  final double size;
  final FontWeight weight;
  final Color color;
  final TextAlign? align;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(keepAll(text),
      textAlign: align,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: tx(size: size, weight: weight, color: color, height: size >= 20 ? 1.3 : 1.55));
}

/// 세로로 쌓기 (gap 간격)
class VStack extends StatelessWidget {
  const VStack({super.key, required this.children, this.gap = 16, this.cross = CrossAxisAlignment.stretch});
  final List<Widget> children;
  final double gap;
  final CrossAxisAlignment cross;
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: cross,
        children: [for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: gap), children[i]]],
      );
}

/// 양 끝 정렬 한 줄
class Between extends StatelessWidget {
  const Between({super.key, required this.left, required this.right});
  final Widget left, right;
  @override
  Widget build(BuildContext context) => Row(children: [Expanded(child: left), const SizedBox(width: 10), right]);
}

/// 반응형 격자. cols 는 넓은 화면 기준 열 수 (900 이하 2열, 640 이하 1열)
class Grid extends StatelessWidget {
  const Grid({super.key, required this.cols, required this.children, this.gap = 16, this.minCols = 1});
  final int cols, minCols;
  final List<Widget> children;
  final double gap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = MediaQuery.sizeOf(context).width;
        var n = w <= 640 ? 1 : w <= 900 ? (cols > 2 ? 2 : cols) : cols;
        if (n < minCols) n = minCols;
        final cw = (box.maxWidth - gap * (n - 1)) / n;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final c in children) SizedBox(width: cw, child: c)]);
      });
}

/// 흰 카드
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = 20, this.color = C.surface, this.border = true});
  final Widget child;
  final double padding;
  final Color color;
  final bool border;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(kRadius),
          border: border ? Border.all(color: C.line) : null,
        ),
        child: child,
      );
}

/// 상태 표시 알약. tone: '' | good | warn | bad
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.tone = ''});
  final String text, tone;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      'good' => (C.goodSoft, C.good),
      'warn' => (C.warnSoft, C.warn),
      'bad' => (C.badSoft, C.bad),
      _ => (C.mist, C.skyDeep),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, softWrap: false, style: tx(size: 12, weight: FontWeight.w600, color: fg)),
    );
  }
}

/// 둥근 버튼. primary 는 하늘색, ghost 는 테두리 없음
class Btn extends StatelessWidget {
  const Btn(this.label, {super.key, this.onPressed, this.primary = false, this.ghost = false, this.small = false, this.block = false});
  final String label;
  final VoidCallback? onPressed;
  final bool primary, ghost, small, block;
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final bg = primary ? C.sky : ghost ? Colors.transparent : C.surface;
    final fg = primary ? C.skyInk : ghost ? C.muted : C.ink;
    final child = Opacity(
      opacity: enabled ? 1 : .45,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 12 : 18, vertical: small ? 6 : 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: primary ? C.sky : ghost ? Colors.transparent : C.line),
        ),
        alignment: block ? Alignment.center : null,
        child: Text(label, softWrap: false, style: tx(size: small ? 13 : 15, weight: FontWeight.w600, color: fg)),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(onTap: onPressed, behavior: HitTestBehavior.opaque, child: child),
      ),
    );
  }
}

/// 고르기 칩
class ChipBtn extends StatelessWidget {
  const ChipBtn(this.label, {super.key, this.on = false, required this.onTap, this.accent});
  final String label;
  final bool on;
  final VoidCallback onTap;
  /// 지역 칩처럼 고유 색이 있으면 앞에 점을 찍고, 고르면 그 색으로 채웁니다
  final Color? accent;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: on ? (accent ?? C.sky) : C.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: on ? (accent ?? C.sky) : C.line),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (accent != null) ...[
                Container(width: 8, height: 8, decoration: BoxDecoration(color: on ? Colors.white : accent, shape: BoxShape.circle)),
                const SizedBox(width: 6),
              ],
              Text(label, style: tx(size: 14, weight: on ? FontWeight.w700 : FontWeight.w400, color: on ? (accent != null ? Colors.white : C.skyInk) : C.ink)),
            ]),
          ),
        ),
      );
}

class Chips extends StatelessWidget {
  const Chips({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: children);
}

/// 둘 중 하나 고르기 (세그먼트)
class Seg<V> extends StatelessWidget {
  const Seg({super.key, required this.options, required this.value, required this.onChanged});
  final Map<V, String> options;
  final V value;
  final ValueChanged<V> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: C.mist, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final e in options.entries)
            GestureDetector(
              onTap: () => onChanged(e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: e.key == value ? C.surface : Colors.transparent, borderRadius: BorderRadius.circular(999)),
                child: Text(e.value,
                    style: tx(size: 14, weight: e.key == value ? FontWeight.w700 : FontWeight.w400, color: e.key == value ? C.skyDeep : C.muted)),
              ),
            ),
        ]),
      );
}

/// 가로 막대
class Bar extends StatelessWidget {
  const Bar(this.ratio, {super.key, this.color = C.sky});
  final double ratio;
  final Color color;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 8,
          color: C.mist,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: ratio.clamp(0, 1), child: Container(color: color)),
        ),
      );
}

/// 회색 안내 상자
class Note extends StatelessWidget {
  const Note(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(10)),
        child: T(text, size: 13, color: C.muted),
      );
}

/// 입력칸
class AppInput extends StatelessWidget {
  const AppInput({super.key, required this.controller, this.hint, this.obscure = false, this.keyboard, this.onSubmitted, this.onChanged, this.maxLength});
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboard;
  final ValueChanged<String>? onSubmitted, onChanged;
  final int? maxLength;
  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c) => OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c));
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      maxLength: maxLength,
      style: tx(size: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: tx(size: 15, color: C.muted),
        isDense: true,
        counterText: '',
        filled: true,
        fillColor: C.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        enabledBorder: b(C.line),
        focusedBorder: b(C.skyDeep),
        border: b(C.line),
      ),
    );
  }
}

/// 이름표 + 입력
class Field extends StatelessWidget {
  const Field(this.label, {super.key, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      VStack(gap: 6, children: [Text(label, style: tx(size: 14, weight: FontWeight.w600)), child]);
}

/// 대화 말풍선
class Bubble extends StatelessWidget {
  const Bubble(this.text, {super.key, this.me = false, this.dim = false});
  final String text;
  final bool me, dim;
  @override
  Widget build(BuildContext context) => Align(
        alignment: me ? Alignment.centerRight : Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: .85,
          alignment: me ? Alignment.centerRight : Alignment.centerLeft,
          child: Align(
            alignment: me ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: me ? C.sky : C.surface2,
                borderRadius: BorderRadius.circular(14),
                border: me ? null : Border.all(color: C.line),
              ),
              child: T.small(text, color: me ? C.skyInk : dim ? C.muted : C.ink),
            ),
          ),
        ),
      );
}

/// 대화 목록 + 추천 질문 + 입력칸
class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key, required this.title, required this.messages, required this.suggestions, required this.onSend, this.hint = '', this.busy = false, this.sendLabel = '보내기'});
  final String title, hint, sendLabel;
  final List<(bool me, String text)> messages;
  final List<String> suggestions;
  final ValueChanged<String> onSend;
  final bool busy;
  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(ChatPanel old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? m]) {
    final msg = (m ?? _text.text).trim();
    if (msg.isEmpty) return;
    _text.clear();
    widget.onSend(msg);
  }

  @override
  Widget build(BuildContext context) => AppCard(
        child: VStack(gap: 10, children: [
          T.h3(widget.title),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView(
              controller: _scroll,
              shrinkWrap: true,
              children: [
                for (final (me, text) in widget.messages) Padding(padding: const EdgeInsets.only(bottom: 8), child: Bubble(text, me: me)),
                if (widget.busy) const Bubble('확인하는 중…', dim: true),
              ],
            ),
          ),
          Chips(children: [for (final s in widget.suggestions) ChipBtn(s, onTap: () => _send(s))]),
          Row(children: [
            Expanded(child: AppInput(controller: _text, hint: widget.hint, onSubmitted: (_) => _send())),
            const SizedBox(width: 8),
            Btn(widget.sendLabel, primary: true, onPressed: _send),
          ]),
        ]),
      );
}

/// 간단한 표. widths 가 null 인 열은 남는 폭을 나눠 가집니다.
class SimpleTable extends StatelessWidget {
  const SimpleTable({super.key, required this.head, required this.rows, this.flex, this.right = const {}});
  final List<String>? head;
  final List<List<Widget>> rows;
  final List<int>? flex;
  final Set<int> right;
  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> cells, {bool header = false, bool last = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: C.line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < cells.length; i++)
              Expanded(
                flex: flex?[i] ?? 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Align(alignment: right.contains(i) ? Alignment.centerRight : Alignment.centerLeft, child: cells[i]),
                ),
              ),
          ]),
        );
    return Column(children: [
      if (head != null) row([for (final h in head!) Text(h, style: tx(size: 12, weight: FontWeight.w600, color: C.muted))], header: true),
      for (var i = 0; i < rows.length; i++) row(rows[i], last: i == rows.length - 1),
    ]);
  }
}

/// 페이지 본문 (가운데 정렬, 최대 폭)
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.narrow = false, this.gap = 20});
  final List<Widget> children;
  final bool narrow;
  final double gap;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: narrow ? 648 : 1088),
            child: VStack(gap: gap, children: children),
          ),
        ),
      );
}

/// 불러오는 중 표시
class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.all(24), child: T.muted('불러오는 중…'));
}
