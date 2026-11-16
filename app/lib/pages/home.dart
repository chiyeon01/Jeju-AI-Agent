// 홈: 역할 선택, 데이터 순환 구조 (React 의 pages/Home.jsx)
import 'package:material_ui/material_ui.dart';

import '../data/console_mock.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/jeju_map.dart';
import '../widgets/ui.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = screenW(context);
    final nav = AppNav.of(context);
    final oneCol = w <= 860;
    final h1 = (w * .06).clamp(38.4, 57.6).toDouble();

    final heroText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Eyebrow('제주 AI·빅데이터 활용 AI Agent'),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: keepAll('관광객의 취향과\n제주 상권을 ')),
            TextSpan(text: keepAll('데이터로 잇다'), style: TextStyle(color: c.accent)),
          ]),
          style: tx(context, display: true, size: h1),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            keepAll('관광객은 성향에 맞는 코스를 받고, 사장님은 객관적인 상권 건강 지표를 받습니다. '
            '관광객이 남긴 평가는 다시 지표와 추천으로 돌아와 제주시 Main PC에 쌓입니다.'),
            style: tx(context, size: 17.6, color: c.muted),
          ),
        ),
        const SizedBox(height: 24),
        HWrap(children: [
          Btn('성향 테스트 시작', kind: BtnKind.primary, onPressed: () => nav.go('/tourist')),
          Btn('사장님 대시보드 보기', onPressed: () => nav.go('/owner')),
        ]),
      ],
    );
    const map = JejuMap(health: regionHealth, flows: popularCourses);

    final roles = [
      _RoleCard(
        eyebrow: '관광객 · 웹/앱',
        who: '여행 코스 받기',
        items: const [
          '12문항 성향 테스트로 16유형 중 내 유형 찾기',
          '지도에서 위치 고르기 (또는 현재 위치)',
          'AI가 짠 3~5곳 코스와 데이터 근거 확인',
          '방문 후 별점과 한 줄 평가',
        ],
        onTap: () => nav.go('/tourist'),
      ),
      _RoleCard(
        eyebrow: '상권 주인 · 웹/앱',
        who: '상권 건강 지표',
        items: const [
          '빅데이터 + 관광객 평가로 만든 0~100 종합 점수',
          '7개 세부 지표와 주변 상권 대비 백분위',
          '주간 AI 개선 제안과 질문형 대화',
        ],
        onTap: () => nav.go('/owner'),
      ),
      _RoleCard(
        eyebrow: '제주시 · Main PC',
        who: '통합 데이터 관리 콘솔',
        items: const [
          '실시간 방문·평가 이벤트와 지역별 상권 점수',
          '원천 데이터 적재 이력과 품질 점검',
          '접근 권한·마스킹 규칙·백업 관리',
        ],
        dark: true,
        onTap: () => nav.go('/console'),
      ),
    ];

    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 히어로
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 40),
            child: oneCol
                ? VStack(gap: 32, children: [heroText, map])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 110, child: heroText),
                      const SizedBox(width: 32),
                      const Expanded(flex: 100, child: map),
                    ],
                  ),
          ),
          Semantics(label: '사용자별 화면', child: Grid(columns: oneCol ? 1 : 3, children: roles)),
          const SizedBox(height: 40),
          const _Loop(),
        ],
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  const _RoleCard({required this.eyebrow, required this.who, required this.items, required this.onTap, this.dark = false});
  final String eyebrow, who;
  final List<String> items;
  final VoidCallback onTap;
  final bool dark;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = widget.dark ? c.basaltInk : c.ink;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Tap(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: widget.dark ? c.basalt : c.surface,
            borderRadius: BorderRadius.circular(rLg),
            border: Border.all(color: _hover ? c.accent : (widget.dark ? c.basalt : c.line)),
          ),
          child: VStack(
            gap: 12,
            cross: CrossAxisAlignment.start,
            children: [
              Eyebrow(widget.eyebrow, color: widget.dark ? fg : null, opacity: widget.dark ? .7 : 1),
              Text(widget.who, style: tx(context, display: true, size: 25.6, color: fg)),
              Opacity(
                opacity: widget.dark ? .7 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < widget.items.length; i++)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 19,
                            child: Text('${i + 1}.', style: tx(context, size: fsSm, color: widget.dark ? fg : c.muted)),
                          ),
                          Expanded(
                            child: Text(widget.items[i], style: tx(context, size: fsSm, color: widget.dark ? fg : c.muted)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Loop extends StatelessWidget {
  const _Loop();

  static const _steps = [
    ('평가', '방문 인증된 관광객이 별점과 한 줄 평가를 남깁니다.'),
    ('상권 지표', '고객 만족·성향 적합도 지표가 바로 다시 계산됩니다.'),
    ('추천 품질', '성향-장소 선호 행렬이 갱신돼 다음 코스에 반영됩니다.'),
    ('Main PC', '새로 만들어진 데이터가 제주시 통합 저장소에 쌓입니다.'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final oneCol = screenW(context) <= 760;
    Widget cell(int i) {
      final last = i == _steps.length - 1;
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: last
              ? null
              : oneCol
                  ? Border(bottom: BorderSide(color: c.line))
                  : Border(right: BorderSide(color: c.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(_steps[i].$1, style: tx(context, display: true, size: 18.4)),
            ),
            Small(_steps[i].$2, muted: true),
          ],
        ),
      );
    }

    return Semantics(
      label: '데이터 순환 구조',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(rMd),
          border: Border.all(color: c.line),
        ),
        child: oneCol
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < 4; i++) cell(i)])
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (var i = 0; i < 4; i++) Expanded(child: cell(i))],
                ),
              ),
      ),
    );
  }
}
