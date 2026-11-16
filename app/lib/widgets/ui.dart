// 공통 컴포넌트: styles.css 의 .card / .pill / .btn / .chip / .seg / .bar / table.data 등을 위젯으로 옮겼습니다.
import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// 화면 폭 (CSS 미디어 쿼리 대신 사용)
double screenW(BuildContext context) => MediaQuery.sizeOf(context).width;

/// 세로로 쌓기 (.stack, 기본 간격 16)
class VStack extends StatelessWidget {
  const VStack({super.key, required this.children, this.gap = 16, this.cross = CrossAxisAlignment.stretch});
  final List<Widget> children;
  final double gap;
  final CrossAxisAlignment cross;

  @override
  Widget build(BuildContext context) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0 && gap > 0) out.add(SizedBox(height: gap));
      out.add(children[i]);
    }
    return Column(crossAxisAlignment: cross, mainAxisSize: MainAxisSize.min, children: out);
  }
}

/// 가로로 놓고 넘치면 줄바꿈 (.row, 기본 간격 12)
class HWrap extends StatelessWidget {
  const HWrap({super.key, required this.children, this.gap = 12, this.runGap, this.cross = WrapCrossAlignment.center, this.align = WrapAlignment.start});
  final List<Widget> children;
  final double gap;
  final double? runGap;
  final WrapCrossAlignment cross;
  final WrapAlignment align;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: gap,
        runSpacing: runGap ?? gap / 1.5,
        crossAxisAlignment: cross,
        alignment: align,
        children: children,
      );
}

/// 양 끝 정렬 줄 (row + justify-content: space-between). 좁으면 줄바꿈합니다.
class SpaceBetween extends StatelessWidget {
  const SpaceBetween({super.key, required this.left, required this.right, this.gap = 12, this.cross = WrapCrossAlignment.center});
  final Widget left;
  final Widget right;
  final double gap;
  final WrapCrossAlignment cross;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: cross,
        spacing: gap,
        runSpacing: 8,
        children: [left, right],
      );
}

/// 반응형 격자 (.grid .g2/.g3/.g4). columns 는 현재 화면 폭에서의 열 수.
/// stretch=true 이면 한 줄의 카드 높이를 맞춥니다 (CSS grid 기본 동작).
class Grid extends StatelessWidget {
  const Grid({super.key, required this.columns, required this.children, this.gap = 16, this.stretch = true, this.flex});
  final int columns;
  final List<Widget> children;
  final double gap;
  final bool stretch;

  /// 열 비율 (예: [1.25, 1]). 지정하지 않으면 같은 폭.
  final List<double>? flex;

  /// g2: 640 이하 1열 / g3: 960 이하 2열, 640 이하 1열 / g4: 960 이하 2열
  static int g2(BuildContext context) => screenW(context) <= 640 ? 1 : 2;
  static int g3(BuildContext context) {
    final w = screenW(context);
    return w <= 640 ? 1 : w <= 960 ? 2 : 3;
  }

  static int g4(BuildContext context) => screenW(context) <= 960 ? 2 : 4;

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) return VStack(gap: gap, children: children);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final cells = <Widget>[];
      for (var j = 0; j < columns; j++) {
        if (j > 0) cells.add(SizedBox(width: gap));
        final idx = i + j;
        final f = flex != null && j < flex!.length ? flex![j] : 1.0;
        cells.add(Expanded(
          flex: (f * 100).round(),
          child: idx < children.length ? children[idx] : const SizedBox.shrink(),
        ));
      }
      final row = Row(
        crossAxisAlignment: stretch ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
        children: cells,
      );
      rows.add(stretch ? IntrinsicHeight(child: row) : row);
    }
    return VStack(gap: gap, children: rows);
  }
}

/// .card (.raised: 그림자, .flat)
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.raised = false, this.color, this.borderColor, this.radius = rMd});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool raised;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? (raised ? Colors.transparent : c.line)),
        boxShadow: raised ? c.shadow : null,
      ),
      child: child,
    );
  }
}

/// .card-head : 제목과 오른쪽 요소를 양 끝에 둡니다.
class CardHead extends StatelessWidget {
  const CardHead({super.key, required this.title, this.trailing, this.bottom = 14});
  final Widget title;
  final Widget? trailing;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: trailing == null
            ? Align(alignment: Alignment.centerLeft, child: title)
            : Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.start,
                spacing: 12,
                runSpacing: 8,
                children: [title, trailing!],
              ),
      );
}

/// 제목 글자 (h1/h2/h3, Do Hyeon)
class Heading extends StatelessWidget {
  const Heading(this.text, {super.key, this.size = fsXl, this.color});
  final String text;
  final double size;
  final Color? color;

  /// 카드 머리말 h3 (1.15rem)
  const Heading.card(this.text, {super.key, this.color}) : size = 18.4;

  @override
  Widget build(BuildContext context) => Text(keepAll(text), style: tx(context, display: true, size: size, color: color));
}

/// .eyebrow
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color, this.opacity = 1});
  final String text;
  final Color? color;
  final double opacity;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: opacity,
        child: Text(text,
            style: tx(context, size: fsXs, weight: FontWeight.w600, color: color ?? context.c.muted, letterSpacing: fsXs * .08)),
      );
}

/// 작은 글자 (.small / .small.muted)
class Small extends StatelessWidget {
  const Small(this.text, {super.key, this.muted = false, this.color, this.weight = FontWeight.w400, this.mono = false, this.align});
  final String text;
  final bool muted;
  final Color? color;
  final FontWeight weight;
  final bool mono;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) => Text(
        keepAll(text),
        textAlign: align,
        style: tx(context, size: fsSm, weight: weight, mono: mono, color: color ?? (muted ? context.c.muted : null)),
      );
}

/// 숫자 글자 (.num)
class Num extends StatelessWidget {
  const Num(this.text, {super.key, this.size = fsSm, this.color, this.weight = FontWeight.w400, this.align});
  final String text;
  final double size;
  final Color? color;
  final FontWeight weight;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) =>
      Text(text, textAlign: align, style: tx(context, mono: true, size: size, color: color, weight: weight));
}

enum Tone { none, good, warn, bad, sea, accent }

Tone toneOf(String s) => switch (s) {
      'good' => Tone.good,
      'warn' => Tone.warn,
      'bad' => Tone.bad,
      'sea' => Tone.sea,
      'accent' => Tone.accent,
      _ => Tone.none,
    };

(Color bg, Color fg) toneColors(BuildContext context, Tone t) {
  final c = context.c;
  return switch (t) {
    Tone.good => (c.goodSoft, c.good),
    Tone.warn => (c.warnSoft, c.warn),
    Tone.bad => (c.badSoft, c.bad),
    Tone.sea => (c.seaSoft, c.sea),
    Tone.accent => (c.accentSoft, c.accent),
    Tone.none => (c.surface2, c.muted),
  };
}

/// .pill
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.tone = Tone.none, this.leading, this.wrap = false, this.minWidth, this.center = false});
  final String text;
  final Tone tone;
  final Widget? leading;
  final bool wrap;
  final double? minWidth;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(context, tone);
    final label = Text(
      text,
      softWrap: wrap,
      textAlign: center ? TextAlign.center : null,
      style: tx(context, size: fsXs, weight: FontWeight.w600, color: fg, height: 1.5),
    );
    return Container(
      constraints: BoxConstraints(minWidth: minWidth ?? 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          wrap ? Flexible(child: label) : label,
        ],
      ),
    );
  }
}

enum BtnKind { normal, primary, dark, ghost }

/// .btn (.primary / .dark / .ghost / .sm / .block)
class Btn extends StatelessWidget {
  const Btn(this.label, {super.key, this.onPressed, this.kind = BtnKind.normal, this.small = false, this.block = false});
  final String label;
  final VoidCallback? onPressed;
  final BtnKind kind;
  final bool small;
  final bool block;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg, border) = switch (kind) {
      BtnKind.primary => (c.accent, c.accentInk, c.accent),
      BtnKind.dark => (c.basalt, c.basaltInk, c.basalt),
      BtnKind.ghost => (Colors.transparent, c.ink, c.line),
      BtnKind.normal => (c.surface, c.ink, c.line),
    };
    final enabled = onPressed != null;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(999), side: BorderSide(color: border));
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Material(
        color: bg,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          hoverColor: kind == BtnKind.primary ? Colors.white.withValues(alpha: .06) : c.surface2,
          highlightColor: c.ink.withValues(alpha: .06),
          child: Padding(
            padding: small ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6) : const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: tx(context, size: small ? fsXs : fsSm, weight: FontWeight.w600, color: fg, height: 1.45),
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

/// .chip (.on)
class ChipBtn extends StatelessWidget {
  const ChipBtn(this.label, {super.key, this.on = false, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: on ? c.accentSoft : c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999), side: BorderSide(color: on ? c.accent : c.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: c.surface2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(label,
              style: tx(context, size: fsSm, weight: on ? FontWeight.w600 : FontWeight.w400, color: on ? c.accent : c.ink, height: 1.45)),
        ),
      ),
    );
  }
}

/// .chips
class Chips extends StatelessWidget {
  const Chips({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: children);
}

/// .seg : 둥근 묶음 버튼
class Seg<T> extends StatelessWidget {
  const Seg({super.key, required this.options, required this.value, required this.onChanged});
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(999)),
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        children: [
          for (final (v, label) in options)
            GestureDetector(
              onTap: () => onChanged(v),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: v == value ? c.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: v == value ? c.shadow : null,
                  ),
                  child: Text(label,
                      style: tx(context,
                          size: fsSm,
                          weight: v == value ? FontWeight.w600 : FontWeight.w400,
                          color: v == value ? c.ink : c.muted,
                          height: 1.45)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// .bar : 가로 막대 (value 0~1)
class Bar extends StatelessWidget {
  const Bar({super.key, required this.value, this.color, this.height = 8});
  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: c.surface2,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0, 1).toDouble(),
          heightFactor: 1,
          child: Container(
            decoration: BoxDecoration(color: color ?? c.sea, borderRadius: BorderRadius.circular(999)),
          ),
        ),
      ),
    );
  }
}

/// .source : 데이터 출처 표기
class Source extends StatelessWidget {
  const Source(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: tx(context, size: fsXs, mono: true, color: context.c.muted));
}

/// .mock-note : 점선 안내
class MockNote extends StatelessWidget {
  const MockNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(rSm),
        border: Border.all(color: c.line), // Flutter 기본 테두리에는 점선이 없어 실선으로 표시합니다.
      ),
      child: Text(text, style: tx(context, size: fsXs, color: c.muted)),
    );
  }
}

/// .input
class AppInput extends StatelessWidget {
  const AppInput({super.key, required this.controller, this.hint, this.maxLength, this.onSubmitted, this.onChanged, this.enabled = true});
  final TextEditingController controller;
  final String? hint;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    OutlineInputBorder b(Color col, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(rSm), borderSide: BorderSide(color: col, width: w));
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLength: maxLength,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: tx(context, size: fsMd, height: 1.4),
      decoration: InputDecoration(
        isDense: true,
        counterText: '',
        hintText: hint,
        hintStyle: tx(context, size: fsMd, color: c.muted, height: 1.4),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: b(c.line),
        enabledBorder: b(c.line),
        disabledBorder: b(c.line),
        focusedBorder: b(c.accent, 2),
      ),
    );
  }
}

/// .field : 라벨 + 입력
class Field extends StatelessWidget {
  const Field({super.key, required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => VStack(gap: 6, children: [
        Text(label, style: tx(context, size: fsSm, weight: FontWeight.w600)),
        child,
      ]);
}

/// 채팅 말풍선 (.bubble.me / .bubble.ai)
class Bubble extends StatelessWidget {
  const Bubble({super.key, required this.text, required this.me, this.muted = false});
  final String text;
  final bool me;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return LayoutBuilder(
      builder: (context, box) => Align(
        alignment: me ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: box.maxWidth * .85),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: me ? c.accent : c.surface2,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(me ? 14 : 4),
                bottomRight: Radius.circular(me ? 4 : 14),
              ),
            ),
            child: Text(keepAll(text), style: tx(context, size: fsSm, color: me ? c.accentInk : (muted ? c.muted : c.ink))),
          ),
        ),
      ),
    );
  }
}

/// 채팅 영역 (.chat: 최대 높이 360, 새 메시지가 오면 아래로 스크롤)
class ChatBox extends StatefulWidget {
  const ChatBox({super.key, required this.children});
  final List<Widget> children;
  @override
  State<ChatBox> createState() => _ChatBoxState();
}

class _ChatBoxState extends State<ChatBox> {
  final _ctrl = ScrollController();

  @override
  void didUpdateWidget(covariant ChatBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_ctrl.hasClients) {
        _ctrl.animateTo(_ctrl.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: SingleChildScrollView(
          controller: _ctrl,
          padding: const EdgeInsets.only(right: 4),
          child: VStack(gap: 10, children: widget.children),
        ),
      );
}

/// 채팅 입력줄 (.chat-input)
class ChatInput extends StatelessWidget {
  const ChatInput({super.key, required this.controller, required this.hint, required this.button, required this.onSend});
  final TextEditingController controller;
  final String hint;
  final String button;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(children: [
          Expanded(child: AppInput(controller: controller, hint: hint, onSubmitted: (_) => onSend())),
          const SizedBox(width: 8),
          Btn(button, kind: BtnKind.dark, onPressed: onSend),
        ]),
      );
}

/// 표 열 정의
class Col {
  const Col(this.label, {this.right = false, this.maxWidth, this.minWidth});
  final String label;
  final bool right;
  final double? maxWidth;
  final double? minWidth;
}

/// table.data : 좁은 화면에서는 가로로 스크롤합니다 (.table-wrap)
class DataTableX extends StatelessWidget {
  const DataTableX({super.key, required this.cols, required this.rows, this.header = true});
  final List<Col> cols;
  final List<List<Widget>> rows;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget cell(Widget w, Col col, {bool th = false}) {
      Widget child = Align(alignment: col.right ? Alignment.topRight : Alignment.topLeft, child: w);
      if (col.maxWidth != null || col.minWidth != null) {
        child = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: col.maxWidth ?? double.infinity, minWidth: col.minWidth ?? 0),
          child: child,
        );
      }
      return Padding(padding: th ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.all(10), child: child);
    }

    final tableRows = <TableRow>[
      if (header)
        TableRow(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          children: [
            for (final col in cols)
              cell(
                Text(col.label,
                    softWrap: false,
                    style: tx(context, size: fsXs, weight: FontWeight.w600, color: c.muted, letterSpacing: fsXs * .04)),
                col,
                th: true,
              ),
          ],
        ),
      for (var i = 0; i < rows.length; i++)
        TableRow(
          decoration: i < rows.length - 1 ? BoxDecoration(border: Border(bottom: BorderSide(color: c.line))) : null,
          children: [
            for (var j = 0; j < cols.length; j++)
              cell(DefaultTextStyle.merge(style: tx(context, size: fsSm), child: rows[i][j]), cols[j]),
          ],
        ),
    ];

    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: box.maxWidth),
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: tableRows,
          ),
        ),
      ),
    );
  }
}

/// 페이지 본문 폭 (.page / .page.narrow)
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child, this.narrow = false, this.controller});
  final Widget child;
  final bool narrow;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: narrow ? 728 : 1168),
          child: child,
        ),
      ),
    );
  }
}

/// 링크처럼 누를 수 있는 영역
class Tap extends StatelessWidget {
  const Tap({super.key, required this.child, required this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
      );
}

String comma(num n) {
  final s = n.toString();
  return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
}

/// CSS word-break: keep-all 흉내. 한글 낱말 중간에서 줄이 바뀌지 않도록 글자 사이에 줄바꿈 금지 문자를 넣습니다.
String keepAll(String s) => s.replaceAllMapped(RegExp(r'(?<=[가-힣])(?=[가-힣])'), (_) => '\u2060');

String pad2(int n) => n.toString().padLeft(2, '0');
