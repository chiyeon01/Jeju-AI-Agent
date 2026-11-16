// 제주시 Main PC 통합 데이터 관리 콘솔 (React 의 MainConsole.jsx)
import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../data/console_mock.dart';
import '../../data/tourist_mock.dart';
import '../../theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/jeju_map.dart';
import '../../widgets/ui.dart';

const _tabs = [
  ('overview', '통합 현황'),
  ('data', '데이터 관리'),
  ('security', '접근·보안'),
  ('backup', '백업·복구'),
];
const _status = {'ok': (Tone.good, '정상'), 'warn': (Tone.warn, '주의'), 'err': (Tone.bad, '오류')};

String _now() {
  final d = DateTime.now();
  return '${pad2(d.hour)}:${pad2(d.minute)}:${pad2(d.second)}';
}

class MainConsole extends StatefulWidget {
  const MainConsole({super.key});

  @override
  State<MainConsole> createState() => _MainConsoleState();
}

class _MainConsoleState extends State<MainConsole> {
  String _tab = 'overview';

  @override
  Widget build(BuildContext context) {
    final narrow = screenW(context) <= 860;

    final side = narrow
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final (id, label) in _tabs) ...[
                _SideButton(label: label, on: _tab == id, onTap: () => setState(() => _tab = id)),
                const SizedBox(width: 4),
              ],
            ]),
          )
        : SizedBox(
            width: 220,
            child: VStack(gap: 4, children: [
              for (final (id, label) in _tabs) _SideButton(label: label, on: _tab == id, onTap: () => setState(() => _tab = id)),
            ]),
          );

    final content = switch (_tab) {
      'data' => const _DataManage(),
      'security' => const _Security(),
      'backup' => const _Backup(),
      _ => const _Overview(),
    };

    return PageBody(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardHead(
          bottom: 20,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: const [
            Eyebrow('제주시 Main PC'),
            Heading('통합 데이터 관리 콘솔', size: 33.6),
          ]),
          trailing: const Pill('2026-11-10 · 시연용 합성 데이터'),
        ),
        if (narrow)
          VStack(gap: 24, children: [side, content])
        else
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            side,
            const SizedBox(width: 24),
            Expanded(child: content),
          ]),
      ]),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: on ? c.basalt : Colors.transparent, borderRadius: BorderRadius.circular(rSm)),
        child: Text(label, softWrap: false, style: tx(context, weight: FontWeight.w500, color: on ? c.basaltInk : c.muted, height: 1.4)),
      ),
    );
  }
}

// ── 통합 현황 ────────────────────────────

class _LiveEvent {
  _LiveEvent(this.id, this.type, this.text, this.at, {this.fresh = false});
  final int id;
  final String type, text, at;
  final bool fresh;
}

class _Overview extends StatefulWidget {
  const _Overview();

  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  // 실시간 이벤트 스트림 (실서비스: WebSocket 구독)
  final _rand = math.Random();
  late List<_LiveEvent> _events = [
    for (var i = 0; i < 6; i++) _LiveEvent(i, eventSamples[i].$1, eventSamples[i].$2, '09:1${5 - math.min(i, 5)}:0$i'),
  ];
  var _visits = 9770, _reviews = 1129, _courses = 3412, _eps = 42;
  List<double> _epsHist = [31, 35, 38, 33, 40, 44, 39, 42, 46, 41, 43, 42];
  int _seq = 100;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) => _tick());
  }

  void _tick() {
    final (type, text) = eventSamples[_rand.nextInt(eventSamples.length)];
    _seq += 1;
    setState(() {
      _events = [_LiveEvent(_seq, type, text, _now(), fresh: true), ..._events].take(30).toList();
      if (type == '방문 인증') _visits += 1;
      if (type == '평가 등록') _reviews += 1;
      if (type == '코스 선택') _courses += 1;
      _eps = 36 + _rand.nextInt(15);
      _epsHist = [..._epsHist.skip(1), (36 + _rand.nextInt(15)).toDouble()];
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ranked = [for (final r in regions) (r, regionHealth[r.id]!)]..sort((a, b) => b.$2.score.compareTo(a.$2.score));
    final wideMain = screenW(context) > 1100;

    Widget kpi(String label, Widget value, String note) => AppCard(
          child: VStack(gap: 4, children: [Eyebrow(label), value, Small(note, muted: true)]),
        );
    Widget big(String v) => Text(v, style: tx(context, mono: true, size: 30.4, height: 1.1));

    final mapCard = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardHead(
          title: const Heading.card('지역별 상권 건강 점수 · 인기 코스 흐름'),
          trailing: HWrap(gap: 10, children: [
            Small('● 70+', color: c.good),
            Small('● 60–69', color: c.sea),
            Small('● 55–59', color: c.warn),
            Small('● 55 미만', color: c.bad),
          ]),
        ),
        const JejuMap(health: regionHealth, flows: popularCourses),
        const SizedBox(height: 8),
        const Small('원 크기 = 오늘 방문 인증 수, 점선 굵기 = 코스 선택 수', muted: true),
      ]),
    );

    final feedCard = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardHead(
          title: const Heading.card('실시간 이벤트'),
          trailing: Pill('수신 중', tone: Tone.good, leading: const _PulseDot()),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: ListView(
            shrinkWrap: true,
            children: [for (final e in _events) _FeedRow(key: ValueKey(e.id), e: e)],
          ),
        ),
      ]),
    );

    return VStack(gap: 20, children: [
      Grid(columns: Grid.g4(context), children: [
        kpi('오늘 방문 인증', big(comma(_visits)), '어제 같은 시각 대비 +6%'),
        kpi('오늘 평가', big(comma(_reviews)), '허위 의심 차단 7건'),
        kpi('오늘 코스 선택', big(comma(_courses)), '완주율 63%'),
        kpi(
          '이벤트 처리량',
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Text.rich(
                softWrap: false,
                TextSpan(children: [
                  TextSpan(text: '$_eps', style: tx(context, mono: true, size: 30.4, height: 1.1)),
                  TextSpan(text: ' /초', style: tx(context, size: fsSm, color: c.muted)),
                ]),
              ),
            ),
            Sparkline(data: _epsHist, width: 90, height: 34),
          ]),
          '평균 지연 0.8초',
        ),
      ]),
      if (wideMain)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 150, child: mapCard),
          const SizedBox(width: 16),
          Expanded(flex: 100, child: feedCard),
        ])
      else
        VStack(children: [mapCard, feedCard]),
      Grid(columns: Grid.g2(context), stretch: false, children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const CardHead(title: Heading.card('지역 순위'), trailing: Small('상권 건강 점수 평균', muted: true)),
            DataTableX(
              cols: const [Col('지역'), Col('점수', minWidth: 120), Col('방문', right: true), Col('평가', right: true)],
              rows: [
                for (final (r, h) in ranked)
                  [
                    Text(r.name),
                    SizedBox(
                      width: 120,
                      child: Row(children: [
                        Expanded(child: Bar(value: h.score / 100, color: c.scoreColor(h.score))),
                        const SizedBox(width: 8),
                        Num('${h.score}'),
                      ]),
                    ),
                    Num(comma(h.visits), align: TextAlign.right),
                    Num('${h.reviews}', align: TextAlign.right),
                  ],
              ],
            ),
          ]),
        ),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const CardHead(title: Heading.card('인기 코스'), trailing: Small('오늘 선택·완주 기준', muted: true)),
            VStack(gap: 12, children: [
              for (var i = 0; i < popularCourses.length; i++)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 20, child: Num('${i + 1}', size: fsMd, color: c.accent)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(popularCourses[i].name, style: tx(context)),
                      Small('주 이용 성향 · ${popularCourses[i].type}', muted: true),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Num('${popularCourses[i].count}'),
                ]),
            ]),
          ]),
        ),
      ]),
    ]);
  }
}

class _FeedRow extends StatefulWidget {
  const _FeedRow({super.key, required this.e});
  final _LiveEvent e;

  @override
  State<_FeedRow> createState() => _FeedRowState();
}

class _FeedRowState extends State<_FeedRow> with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    if (widget.e.fresh) _flash.forward();
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final e = widget.e;
    return AnimatedBuilder(
      animation: _flash,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          color: e.fresh && _flash.isAnimating ? Color.lerp(c.accentSoft, c.accentSoft.withValues(alpha: 0), Curves.easeOut.transform(_flash.value)) : null,
          border: Border(bottom: BorderSide(color: c.line)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: child,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 70, child: Text(e.at, softWrap: false, style: tx(context, mono: true, size: fsSm, color: c.muted))),
          const SizedBox(width: 10),
          SizedBox(width: 84, child: Align(alignment: Alignment.centerLeft, child: Pill(e.type, tone: toneOf(eventPill[e.type] ?? '')))),
          const SizedBox(width: 10),
          Expanded(child: Small(e.text)),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 1.0, end: .3).animate(CurvedAnimation(parent: _a, curve: Curves.easeInOut)),
        child: Container(width: 8, height: 8, decoration: BoxDecoration(color: context.c.good, shape: BoxShape.circle)),
      );
}

// ── 데이터 관리 ──────────────────────────

class _DataManage extends StatelessWidget {
  const _DataManage();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return VStack(gap: 20, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const CardHead(title: Heading.card('원천 데이터 적재 이력'), trailing: Small('제주데이터허브 · 매일 API는 03시 일 배치', muted: true)),
          DataTableX(
            cols: const [
              Col('코드'),
              Col('데이터', maxWidth: 260),
              Col('갱신 주기'),
              Col('기준 시점'),
              Col('마지막 적재'),
              Col('누적 행', right: true),
              Col('상태'),
            ],
            rows: [
              for (final s in sources)
                [
                  Num(s.id),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.name),
                    if (s.note != null) Small(s.note!, muted: true),
                  ]),
                  Text(s.cycle, softWrap: false),
                  Num(s.basis),
                  Num(s.last),
                  Num(s.rows, align: TextAlign.right),
                  Pill(_status[s.status]!.$2, tone: _status[s.status]!.$1),
                ],
            ],
          ),
        ]),
      ),
      Grid(columns: Grid.g2(context), stretch: false, children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const CardHead(title: Heading.card('실시간 생성 데이터'), trailing: Small('이벤트 → Redis Streams → 처리 워커', muted: true)),
            DataTableX(
              cols: const [Col('데이터', maxWidth: 240), Col('저장소'), Col('반영 지연')],
              rows: [
                for (final (name, desc, st, lag) in derived)
                  [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Small(desc, muted: true),
                    ]),
                    Num(st),
                    Num(lag),
                  ],
              ],
            ),
          ]),
        ),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const CardHead(title: Heading.card('품질 점검'), trailing: Small('오늘 03:40 실행', muted: true)),
            for (final (check, target, result, level) in quality)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Pill(check, tone: toneOf(level), minWidth: 64, center: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Small(target, weight: FontWeight.w600),
                      Small(result, muted: true),
                    ]),
                  ),
                ]),
              ),
          ]),
        ),
      ]),
    ]);
  }
}

// ── 접근·보안 ────────────────────────────

class _Security extends StatelessWidget {
  const _Security();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return VStack(gap: 20, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CardHead(title: const Heading.card('계정별 권한'), trailing: Btn('계정 추가', small: true, onPressed: () {})),
          DataTableX(
            cols: const [Col('계정'), Col('역할'), Col('권한 범위', maxWidth: 260), Col('마지막 접속')],
            rows: [
              for (final (name, role, scope, last) in accounts)
                [
                  Text(name),
                  Pill(role, tone: role == '관리자' ? Tone.accent : role == '서비스' ? Tone.sea : Tone.none),
                  Text(scope),
                  Num(last),
                ],
            ],
          ),
        ]),
      ),
      Grid(columns: Grid.g2(context), stretch: false, children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const CardHead(title: Heading.card('조회·반출 로그')),
            DataTableX(
              cols: const [Col('시각'), Col('계정', maxWidth: 200), Col('요청'), Col('결과')],
              rows: [
                for (final (at, who, action, target, ok) in accessLog)
                  [
                    Num(at),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(who), Small(target, muted: true)]),
                    Text(action, softWrap: false),
                    Pill(ok ? '허용' : '거부', tone: ok ? Tone.good : Tone.bad),
                  ],
              ],
            ),
          ]),
        ),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const CardHead(title: Heading.card('개인 식별 위험 마스킹 규칙')),
            for (final (rule, how) in masking)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Small(rule, weight: FontWeight.w600),
                  Small(how, muted: true),
                ]),
              ),
          ]),
        ),
      ]),
    ]);
  }
}

// ── 백업·복구 ────────────────────────────

class _Backup extends StatefulWidget {
  const _Backup();

  @override
  State<_Backup> createState() => _BackupState();
}

class _BackupState extends State<_Backup> {
  String _msg = '';

  @override
  Widget build(BuildContext context) {
    return Grid(columns: Grid.g2(context), stretch: false, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CardHead(
            title: const Heading.card('스냅샷 이력'),
            trailing: Btn('지금 백업', small: true, kind: BtnKind.dark, onPressed: () => setState(() => _msg = '수동 스냅샷 요청을 보냈어요. (목업)')),
          ),
          if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: MockNote(_msg)),
          DataTableX(
            cols: const [Col('시각'), Col('종류'), Col('크기', right: true), Col('상태'), Col('')],
            rows: [
              for (final (at, kind, size) in backups)
                [
                  Num(at),
                  Text(kind, softWrap: false),
                  Num(size, align: TextAlign.right),
                  const Pill('완료', tone: Tone.good),
                  Btn('복구', small: true, kind: BtnKind.ghost, onPressed: () => setState(() => _msg = '$at 스냅샷 복구는 관리자 2인 승인이 필요해요. (목업)')),
                ],
            ],
          ),
        ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const CardHead(title: Heading.card('보관 기간 정책')),
          DataTableX(
            header: false,
            cols: const [Col(''), Col('', right: true)],
            rows: [for (final (what, keep) in retention) [Text(what), Num(keep, align: TextAlign.right)]],
          ),
          const SizedBox(height: 12),
          const Small('저장소: PostgreSQL + PostGIS, TimescaleDB, pgvector (Main PC)', muted: true),
        ]),
      ),
    ]);
  }
}
