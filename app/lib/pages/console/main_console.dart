// 관리자(제주시 Main PC): 현황 · 데이터 · 계정·보안 · 백업
import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../data/auth_mock.dart';
import '../../theme.dart';
import '../../widgets/kakao_map.dart';
import '../../widgets/ui.dart';

const _tabs = ['현황', '데이터', '계정·보안', '백업'];
const _tone = {'ok': 'good', 'good': 'good', 'warn': 'warn', 'err': 'bad', 'bad': 'bad'};
Color _scoreColor(num s) => s >= 70 ? C.good : s >= 60 ? C.sky : C.bad;

class MainConsole extends StatefulWidget {
  const MainConsole({super.key});
  @override
  State<MainConsole> createState() => _MainConsoleState();
}

class _MainConsoleState extends State<MainConsole> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) => PageBody(gap: 16, children: [
        const T.h1('통합 관리'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var i = 0; i < _tabs.length; i++)
              Semantics(
                selected: _tab == i,
                button: true,
                child: GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: _tab == i ? C.sky : Colors.transparent, borderRadius: BorderRadius.circular(999)),
                    child: Text(_tabs[i], style: tx(weight: FontWeight.w600, color: _tab == i ? C.skyInk : C.muted)),
                  ),
                ),
              ),
          ]),
        ),
        KeyedSubtree(key: ValueKey(_tab), child: [const _Overview(), const _DataTab(), const _Security(), const _Backups()][_tab]),
      ]);
}

/// 데이터를 한 번 불러와 그리는 도우미
class _Loader extends StatefulWidget {
  const _Loader({required this.load, required this.builder});
  final Future<Json> Function() load;
  final Widget Function(Json d, void Function(void Function()) update) builder;
  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  Json? _d;
  @override
  void initState() {
    super.initState();
    widget.load().then((d) => mounted ? setState(() => _d = d) : null);
  }

  @override
  Widget build(BuildContext context) => _d == null ? const Loading() : widget.builder(_d!, setState);
}

class _Overview extends StatefulWidget {
  const _Overview();
  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  final List<Json> _events = [];
  late final void Function() _stop;

  @override
  void initState() {
    super.initState();
    _stop = subscribeEvents((e) {
      if (!mounted) return;
      setState(() {
        _events.insert(0, e);
        if (_events.length > 30) _events.removeLast();
      });
    });
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Loader(
        load: getAdminOverview,
        builder: (d, _) {
          final o = d['overview'] as Json;
          final health = [...(d['health'] as List).cast<Json>()]..sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
          return VStack(children: [
            Grid(cols: 4, minCols: 2, children: [
              for (final (k, v) in [('오늘 방문 인증', o['visits']), ('오늘 평가', o['reviews']), ('오늘 만든 코스', o['courses']), ('초당 이벤트', o['eventsPerSec'])])
                AppCard(child: VStack(gap: 4, children: [T.label(k), Text(comma(v as num), style: tx(size: 24, weight: FontWeight.w700, height: 1.3))])),
            ]),
            Grid(cols: 2, children: [
              AppCard(
                child: VStack(gap: 12, children: [
                  const T.h3('지역별 상권 점수'),
                  KakaoMap(circles: [
                    for (final h in health) MapCircle((h['lat'] as num).toDouble(), (h['lon'] as num).toDouble(), _scoreColor(h['score']), '${h['name']} ${h['score']}'),
                  ]),
                  SimpleTable(
                    head: const ['지역', '점수', '방문', '평가'],
                    flex: const [3, 1, 2, 1],
                    right: const {1, 2, 3},
                    rows: [
                      for (final h in health)
                        [T.small(h['name']), T.small('${h['score']}'), T.small(comma(h['visits'])), T.small('${h['reviews']}')],
                    ],
                  ),
                ]),
              ),
              AppCard(
                child: VStack(gap: 8, children: [
                  Between(
                    left: const T.h3('실시간 이벤트'),
                    right: Container(width: 8, height: 8, decoration: const BoxDecoration(color: C.good, shape: BoxShape.circle)),
                  ),
                  if (_events.isEmpty) const T.muted('이벤트를 기다리는 중…'),
                  for (final e in _events)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 70, child: Text(e['at'] ?? '', softWrap: false, style: tx(size: 13, color: C.muted))),
                        Expanded(
                          child: Text.rich(TextSpan(children: [
                            TextSpan(text: '${e['type']} ', style: tx(size: 14, weight: FontWeight.w700)),
                            TextSpan(text: keepAll('${e['text']}'), style: tx(size: 14)),
                          ])),
                        ),
                      ]),
                    ),
                ]),
              ),
            ]),
          ]);
        },
      );
}

class _DataTab extends StatelessWidget {
  const _DataTab();
  @override
  Widget build(BuildContext context) => _Loader(
        load: getAdminData,
        builder: (d, _) => VStack(children: [
          AppCard(
            child: VStack(gap: 10, children: [
              const T.h3('원천 데이터 (제주데이터허브)'),
              SimpleTable(
                head: const ['코드', '데이터', '주기', '마지막 적재', '상태'],
                flex: const [1, 5, 2, 2, 2],
                rows: [
                  for (final s in (d['sources'] as List).cast<Json>())
                    [
                      T.small(s['id']),
                      T.small(s['name']),
                      T.small(s['cycle']),
                      T.small(s['last']),
                      Pill(s['status'] == 'ok' ? '정상' : '${s['note'] ?? '확인 필요'}', tone: _tone[s['status']] ?? ''),
                    ],
                ],
              ),
            ]),
          ),
          Grid(cols: 2, children: [
            AppCard(
              child: VStack(gap: 10, children: [
                const T.h3('파생 데이터'),
                for (final x in (d['derived'] as List).cast<Json>())
                  Between(left: VStack(gap: 0, children: [T.small(x['name']), T.muted(x['desc'], size: 13)]), right: Pill(x['lag'])),
              ]),
            ),
            AppCard(
              child: VStack(gap: 10, children: [
                const T.h3('품질 점검'),
                for (final x in (d['quality'] as List).cast<Json>())
                  Between(
                    left: VStack(gap: 0, children: [T.small('${x['check']} · ${x['target']}'), T.muted(x['result'], size: 13)]),
                    right: Pill(x['level'] == 'good' ? '정상' : x['level'] == 'warn' ? '주의' : '조치', tone: _tone[x['level']] ?? ''),
                  ),
              ]),
            ),
          ]),
        ]),
      );
}

class _Security extends StatelessWidget {
  const _Security();
  @override
  Widget build(BuildContext context) => _Loader(
        load: getAdminSecurity,
        builder: (d, update) {
          final users = (d['users'] as List).cast<Json>();
          Future<void> approve(Json u) async {
            await updateUser(u['id'], {'status': 'ACTIVE'});
            update(() => u['status'] = 'ACTIVE');
          }

          return VStack(children: [
            AppCard(
              child: VStack(gap: 10, children: [
                const T.h3('계정'),
                SimpleTable(
                  head: const ['이름', '이메일', '역할', ''],
                  flex: const [3, 4, 2, 2],
                  right: const {3},
                  rows: [
                    for (final u in users)
                      [
                        T.small(u['name']),
                        T.muted(u['email']),
                        T.small(roleLabel[u['role']] ?? u['role']),
                        u['status'] == 'PENDING'
                            ? Btn('가입 승인', primary: true, small: true, onPressed: () => approve(u))
                            : Pill(u['status'] == 'ACTIVE' ? '사용 중' : '정지', tone: u['status'] == 'ACTIVE' ? 'good' : 'bad'),
                      ],
                  ],
                ),
              ]),
            ),
            Grid(cols: 2, children: [
              AppCard(
                child: VStack(gap: 10, children: [
                  const T.h3('접근 기록'),
                  for (final l in (d['logs'] as List).cast<Json>())
                    Between(
                      left: VStack(gap: 0, children: [T.small('${l['at']} · ${l['who']}'), T.muted('${l['action']} · ${l['target']}', size: 13)]),
                      right: Pill(l['ok'] == true ? '허용' : '차단', tone: l['ok'] == true ? 'good' : 'bad'),
                    ),
                ]),
              ),
              AppCard(
                child: VStack(gap: 10, children: [
                  const T.h3('개인정보 보호 규칙'),
                  for (final m in (d['masking'] as List).cast<Json>()) VStack(gap: 0, children: [T.small(m['rule']), T.muted(m['how'], size: 13)]),
                ]),
              ),
            ]),
          ]);
        },
      );
}

class _Backups extends StatefulWidget {
  const _Backups();
  @override
  State<_Backups> createState() => _BackupsState();
}

class _BackupsState extends State<_Backups> {
  String _msg = '';
  @override
  Widget build(BuildContext context) => _Loader(
        load: getAdminBackups,
        builder: (d, _) => Grid(cols: 2, children: [
          AppCard(
            child: VStack(gap: 10, children: [
              Between(
                left: const T.h3('백업'),
                right: Btn('지금 백업', primary: true, small: true, onPressed: () async {
                  final m = await requestBackup();
                  if (mounted) setState(() => _msg = m);
                }),
              ),
              if (_msg.isNotEmpty) Note(_msg),
              SimpleTable(
                head: null,
                flex: const [3, 3, 2, 2],
                right: const {2, 3},
                rows: [
                  for (final b in (d['backups'] as List).cast<Json>())
                    [
                      T.small(b['at']),
                      T.small(b['kind']),
                      T.small(b['size']),
                      Btn('복구', small: true, onPressed: () async {
                        final m = await restoreBackup(b['id']);
                        if (mounted) setState(() => _msg = m);
                      }),
                    ],
                ],
              ),
            ]),
          ),
          AppCard(
            child: VStack(gap: 10, children: [
              const T.h3('보관 기간'),
              for (final r in (d['retention'] as List).cast<Json>()) Between(left: T.small(r['what']), right: T.small(r['keep'])),
            ]),
          ),
        ]),
      );
}
