// 상권 주인 대시보드 (React 의 OwnerDashboard.jsx)
import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../data/owner_mock.dart';
import '../../theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/ui.dart';

final _weeks = [
  for (var i = 0; i < scoreTrend.length; i++) i == scoreTrend.length - 1 ? '이번 주' : '${scoreTrend.length - 1 - i}주 전',
];

String _fmt(num v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  final List<(bool, String)> _chat = [];
  final _q = TextEditingController();
  bool _asking = false;
  String _kind = '메뉴';
  final _title = TextEditingController();
  final List<(String, String)> _registered = [];

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _q.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _ask([String? question]) async {
    final text = (question ?? _q.text).trim();
    if (text.isEmpty) return;
    _q.clear();
    setState(() {
      _chat.add((true, text));
      _asking = true;
    });
    final a = await askOwnerAgent(text);
    if (!mounted) return;
    setState(() {
      _asking = false;
      _chat.add((false, a));
    });
  }

  Future<void> _submitAction() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    await registerAction(_kind, title);
    if (!mounted) return;
    setState(() => _registered.insert(0, (_kind, title)));
    _title.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final priority = [...reviewTopics]..sort((a, b) => a.$2.compareTo(b.$2));

    return PageBody(
      child: VStack(gap: 24, children: [
        // 머리말
        CardHead(
          bottom: 0,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Eyebrow('${store.dong} · ${store.category}'),
            Heading(store.name, size: 33.6),
          ]),
          trailing: Pill('시연용 가상 매장 · ${store.basis}', wrap: true),
        ),

        // 요약: 종합 점수 + 추이
        Grid(columns: Grid.g2(context), children: [
          AppCard(raised: true, child: _healthSummary(context)),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const CardHead(title: Heading.card('주간 점수 추이'), trailing: Small('최근 12주', muted: true)),
              LineChart(data: scoreTrend, labels: _weeks),
            ]),
          ),
        ]),

        // AI 개선 제안
        AppCard(
          raised: true,
          child: VStack(children: [
            CardHead(
              bottom: 0,
              title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: const [
                Eyebrow('AI 상권 컨설팅 · $weeklyWeek'),
                Heading.card('이번 주 개선 제안'),
              ]),
              trailing: const Pill('상권 분석 Agent', tone: Tone.accent),
            ),
            Container(
              padding: const EdgeInsets.only(left: 16),
              decoration: BoxDecoration(border: Border(left: BorderSide(color: c.accent, width: 3))),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: Text(weeklySummary, style: tx(context))),
              ),
            ),
            Grid(columns: Grid.g3(context), children: [
              for (var i = 0; i < weeklyActions.length; i++)
                AppCard(
                  color: c.bg,
                  child: VStack(gap: 6, cross: CrossAxisAlignment.start, children: [
                    Num('제안 ${i + 1}', color: c.accent),
                    Text(weeklyActions[i].title, style: tx(context, weight: FontWeight.w700)),
                    Small(weeklyActions[i].why, muted: true),
                    Pill(weeklyActions[i].impact, tone: Tone.sea, wrap: true),
                  ]),
                ),
            ]),
          ]),
        ),

        // 세부 지표
        VStack(children: [
          const CardHead(
            bottom: 0,
            title: Heading.card('세부 지표'),
            trailing: Small('D1~D8: 제주데이터허브 원천 데이터 · 자체: 앱 평가', muted: true),
          ),
          Grid(columns: Grid.g3(context), children: [
            for (final m in indicators.where((m) => m.key != 'fit')) _IndicatorCard(m: m),
          ]),
        ]),

        // 리뷰 인사이트 + 대화
        Grid(columns: Grid.g2(context), stretch: false, children: [
          _reviewInsight(context, priority),
          VStack(children: [
            _fitCard(context),
            _askCard(context),
            _actionCard(context),
          ]),
        ]),
      ]),
    );
  }

  Widget _healthSummary(BuildContext context) {
    final narrow = screenW(context) <= 640;
    final info = VStack(
      gap: 10,
      cross: narrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Column(crossAxisAlignment: narrow ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
          const Eyebrow('상권 건강 점수'),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '${store.dong} 한식 업종 ${store.peers}곳 중 '),
              TextSpan(text: '상위 ${100 - store.percentile}%', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            textAlign: narrow ? TextAlign.center : TextAlign.start,
            style: tx(context, size: 18.4),
          ),
        ]),
        HWrap(align: narrow ? WrapAlignment.center : WrapAlignment.start, children: [
          Pill('▲ ${store.scoreDelta}점 지난주 대비', tone: Tone.good),
          Pill('백분위 ${store.percentile}'),
        ]),
        Small('카드·유동인구는 매장이 아닌 읍면동·업종 단위입니다. 매장 점수는 그 지역 지표에 앱 평가를 더해 계산합니다.',
            muted: true, align: narrow ? TextAlign.center : TextAlign.start),
      ],
    );
    if (narrow) return VStack(gap: 28, cross: CrossAxisAlignment.center, children: [Gauge(value: store.score), info]);
    return Row(children: [Gauge(value: store.score), const SizedBox(width: 28), Expanded(child: info)]);
  }

  Widget _reviewInsight(BuildContext context, List<(String, int, int)> priority) {
    final c = context.c;
    return AppCard(
      child: VStack(children: [
        const CardHead(bottom: 0, title: Heading.card('리뷰 인사이트'), trailing: Small('최근 30일 · 128건', muted: true)),
        DataTableX(
          cols: const [Col('개선 순위'), Col('주제'), Col('긍정 비율', minWidth: 140), Col('언급', right: true)],
          rows: [
            for (var i = 0; i < priority.length; i++)
              [
                Num('${i + 1}'),
                HWrap(gap: 4, children: [
                  Text(priority[i].$1),
                  if (priority[i].$2 < 60) const Pill('개선 필요', tone: Tone.bad),
                ]),
                SizedBox(
                  width: 140,
                  child: Row(children: [
                    Expanded(
                      child: Bar(
                        value: priority[i].$2 / 100,
                        color: priority[i].$2 < 60 ? c.bad : priority[i].$2 < 75 ? c.warn : c.good,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Num('${priority[i].$2}%'),
                  ]),
                ),
                Num('${priority[i].$3}', align: TextAlign.right),
              ],
          ],
        ),
        VStack(gap: 10, children: [
          const Eyebrow('최근 리뷰'),
          for (final r in recentReviews)
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
              child: VStack(gap: 2, children: [
                SpaceBetween(left: Stars(value: r.stars), right: Num(r.at, color: c.muted)),
                Small(r.text),
                HWrap(gap: 6, runGap: 4, children: [
                  Pill(r.type),
                  for (final t in r.tags) Pill(t, tone: t.endsWith('−') ? Tone.bad : Tone.good),
                ]),
              ]),
            ),
        ]),
      ]),
    );
  }

  Widget _fitCard(BuildContext context) => AppCard(
        child: VStack(gap: 8, children: [
          const Source('자체 평가 · 실시간'),
          const Small('성향 적합도 · 이 매장을 높게 평가한 관광객', weight: FontWeight.w600),
          for (final (name, pct) in fitDist)
            VStack(gap: 2, children: [
              SpaceBetween(left: Small(name), right: Num('$pct%')),
              Bar(value: pct * 2.5 / 100),
            ]),
        ]),
      );

  Widget _askCard(BuildContext context) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const CardHead(title: Heading.card('AI에게 물어보기')),
          ChatBox(children: [
            if (_chat.isEmpty)
              const Bubble(text: '매장 지표에 대해 궁금한 점을 물어보세요. 계산은 데이터 도구가 하고, 저는 근거와 함께 설명해 드려요.', me: false),
            for (final (me, t) in _chat) Bubble(text: t, me: me),
            if (_asking) const Bubble(text: '지표 계산 중…', me: false, muted: true),
          ]),
          const SizedBox(height: 10),
          Chips(children: [for (final s in ownerQa.keys) ChipBtn(s, onTap: () => _ask(s))]),
          ChatInput(controller: _q, hint: '예: 평일 저녁 손님을 늘리려면?', button: '질문', onSend: () => _ask()),
        ]),
      );

  Widget _actionCard(BuildContext context) {
    final c = context.c;
    return AppCard(
      child: VStack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Heading.card('개선 조치 등록'),
          Small('등록한 메뉴·이벤트는 관광객 코스의 추천 문구에 반영되고, 이후 평가로 효과를 측정해요.', muted: true),
        ]),
        Align(
          alignment: Alignment.centerLeft,
          child: Seg<String>(
            options: const [('메뉴', '메뉴'), ('이벤트', '이벤트'), ('좌석·시설', '좌석·시설')],
            value: _kind,
            onChanged: (k) => setState(() => _kind = k),
          ),
        ),
        Field(
          label: '내용',
          child: AppInput(controller: _title, hint: '예: 17~19시 커플 세트 (고기국수 2 + 음료)', onSubmitted: (_) => _submitAction()),
        ),
        Btn('등록하기', kind: BtnKind.primary, onPressed: _title.text.trim().isEmpty ? null : _submitAction),
        for (final (kind, title) in _registered)
          SpaceBetween(
            left: Text.rich(
              TextSpan(children: [
                WidgetSpan(alignment: PlaceholderAlignment.middle, child: Pill(kind, tone: Tone.accent)),
                TextSpan(text: ' $title'),
              ]),
              style: tx(context, size: fsSm, color: c.ink),
            ),
            right: const Pill('등록됨 · 효과 측정 시작', tone: Tone.good),
          ),
      ]),
    );
  }
}

class _IndicatorCard extends StatelessWidget {
  const _IndicatorCard({required this.m});
  final Indicator m;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = m.delta;
    final deltaColor = d == null || d == 0 ? c.ink : ((d > 0) == m.good ? c.good : c.bad);
    final v = m.value;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Small(m.name, weight: FontWeight.w600)),
            const SizedBox(width: 8),
            Source(m.src),
          ]),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: v is num
                    ? Text.rich(
                        TextSpan(children: [
                          TextSpan(text: _fmt(v)),
                          TextSpan(text: ' ${m.unit}', style: tx(context, size: fsSm, color: c.muted)),
                        ]),
                        style: tx(context, mono: true, size: 25.6, weight: FontWeight.w500, height: 1.4),
                      )
                    : Text('$v', style: tx(context, display: true, size: 20.8, color: c.accent)),
              ),
              if (m.spark != null) Sparkline(data: m.spark!, width: 96, height: 32, color: m.good ? c.sea : c.warn),
            ],
          ),
          const SizedBox(height: 8),
          Small(m.desc, muted: true),
          const SizedBox(height: 8),
          SpaceBetween(
            left: d != null
                ? Text('${d > 0 ? '▲' : d < 0 ? '▼' : '–'} ${_fmt(d.abs())}${m.unit == '%' ? '%p' : ''} 지난달 대비',
                    style: tx(context, mono: true, size: fsSm, color: deltaColor))
                : const Small('상위 성향 비중 31%', muted: true),
            right: Source('기준 ${m.basis}'),
          ),
        ],
      ),
    );
  }
}
