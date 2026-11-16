// 상권 주인: 건강 점수, 주간 추이, AI 제안, 세부 지표, 리뷰, AI 질문, 메뉴·이벤트 등록
import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/ui.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});
  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  Json? _d;
  final List<(bool, String)> _chat = [(false, '가게 지표에 대해 궁금한 점을 물어보세요.')];
  bool _asking = false;
  final _action = TextEditingController();
  final List<String> _saved = [];

  @override
  void initState() {
    super.initState();
    getOwnerDashboard().then((d) => mounted ? setState(() => _d = d) : null);
  }

  @override
  void dispose() {
    _action.dispose();
    super.dispose();
  }

  Future<void> _ask(String q) async {
    setState(() {
      _asking = true;
      _chat.add((true, q));
    });
    final a = await askOwnerAgent(q);
    if (!mounted) return;
    setState(() {
      _asking = false;
      _chat.add((false, a));
    });
  }

  Future<void> _register() async {
    final t = _action.text.trim();
    if (t.isEmpty) return;
    await registerAction('메뉴·이벤트', t);
    setState(() {
      _saved.insert(0, t);
      _action.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) return const PageBody(children: [Loading()]);
    final store = d['store'] as Json, score = d['score'] as Json, trend = d['trend'] as Json, report = d['report'] as Json;
    final delta = score['delta'] as num;
    final topics = [...(d['topics'] as List).cast<Json>()]..sort((a, b) => (a['pos'] as num).compareTo(b['pos'] as num));

    return PageBody(children: [
      VStack(gap: 2, children: [T.label('${store['dong']} · ${store['category']}'), T.h1(store['name'])]),
      Grid(cols: 2, children: [
        AppCard(
          child: VStack(gap: 8, children: [
            const T.label('상권 건강 점수'),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${score['score']}', style: tx(size: 48, weight: FontWeight.w700, color: C.skyDeep, height: 1)),
              const SizedBox(width: 6),
              const T.muted('/ 100'),
            ]),
            Wrap(spacing: 8, runSpacing: 6, children: [
              Pill('${delta >= 0 ? '▲' : '▼'} ${delta.abs()}점 지난주 대비', tone: delta >= 0 ? 'good' : 'bad'),
              Pill('같은 업종 ${score['peers']}곳 중 상위 ${100 - (score['percentile'] as num)}%'),
            ]),
          ]),
        ),
        AppCard(
          child: VStack(gap: 10, children: [
            const Between(left: T.h3('주간 추이'), right: T.muted('최근 12주')),
            LineChart(
              data: [for (final v in trend['values'] as List) (v as num).toDouble()],
              labels: (trend['labels'] as List).cast<String>(),
            ),
          ]),
        ),
      ]),
      AppCard(
        child: VStack(gap: 12, children: [
          Between(left: const T.h3('이번 주 AI 제안'), right: T.muted(report['week'])),
          T(report['summary'], size: 15),
          Grid(cols: 3, children: [
            for (final a in (report['actions'] as List).cast<Json>())
              AppCard(
                color: C.surface2,
                border: false,
                padding: 14,
                child: VStack(gap: 4, cross: CrossAxisAlignment.start, children: [
                  T(a['title'], weight: FontWeight.w700),
                  T.muted(a['why'], size: 13),
                  Pill(a['impact']),
                ]),
              ),
          ]),
        ]),
      ),
      Grid(cols: 3, children: [for (final m in (d['indicators'] as List).cast<Json>()) _Indicator(m)]),
      Grid(cols: 2, children: [
        AppCard(
          child: VStack(gap: 12, children: [
            const T.h3('리뷰 주제별 반응'),
            for (final t in topics)
              VStack(gap: 4, children: [
                Between(
                  left: Wrap(spacing: 6, children: [T.small(t['topic']), if ((t['pos'] as num) < 60) const Pill('개선 필요', tone: 'bad')]),
                  right: T.muted('긍정 ${t['pos']}% · ${t['mentions']}건', size: 13),
                ),
                Bar((t['pos'] as num) / 100, color: (t['pos'] as num) < 60 ? C.bad : C.sky),
              ]),
            const SizedBox(height: 4),
            const T.h3('최근 리뷰'),
            for (final r in (d['reviews'] as List).cast<Json>())
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
                child: VStack(gap: 2, children: [
                  Between(left: Align(alignment: Alignment.centerLeft, child: Stars(value: r['stars'])), right: T.muted(r['at'], size: 13)),
                  T.small(r['text']),
                ]),
              ),
          ]),
        ),
        VStack(children: [
          ChatPanel(
            title: 'AI에게 물어보기',
            messages: _chat,
            suggestions: ownerSuggestedQuestions,
            onSend: _ask,
            busy: _asking,
            hint: '예: 평일 저녁 손님을 늘리려면?',
            sendLabel: '질문',
          ),
          AppCard(
            child: VStack(gap: 12, children: [
              const VStack(gap: 2, children: [T.h3('메뉴·이벤트 등록'), T.muted('등록하면 관광객 코스 추천 문구에 반영돼요.')]),
              AppInput(controller: _action, hint: '예: 17~19시 커플 세트', onChanged: (_) => setState(() {}), onSubmitted: (_) => _register()),
              Btn('등록하기', primary: true, block: true, onPressed: _action.text.trim().isEmpty ? null : _register),
              for (final s in _saved) Between(left: T.small(s), right: const Pill('등록됨', tone: 'good')),
            ]),
          ),
        ]),
      ]),
    ]);
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator(this.m);
  final Json m;
  @override
  Widget build(BuildContext context) {
    final delta = (m['delta'] as num?) ?? 0;
    final good = m['good'] == true;
    final color = delta == 0 ? C.ink : (delta > 0) == good ? C.good : C.bad;
    return AppCard(
      child: VStack(gap: 4, children: [
        T.label(m['name']),
        Text.rich(TextSpan(children: [
          TextSpan(text: '${m['value']}', style: tx(size: 24, weight: FontWeight.w700, height: 1.3)),
          TextSpan(text: ' ${m['unit']}', style: tx(size: 13, color: C.muted)),
        ])),
        Text(delta == 0 ? '변화 없음' : '${delta > 0 ? '▲' : '▼'} ${delta.abs()} 지난달 대비', style: tx(size: 14, color: color)),
      ]),
    );
  }
}
