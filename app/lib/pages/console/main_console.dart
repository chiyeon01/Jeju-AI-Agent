// 관리자(제주시 Main PC): 현황 · Agent 보고서 · 데이터 · 계정·보안 · 백업
import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../data/auth_mock.dart';
import '../../theme.dart';
import '../../widgets/kakao_map.dart';
import '../../widgets/markdown.dart';
import '../../widgets/ui.dart';

const _tabs = ['현황', 'Agent 보고서', '데이터', '계정·보안', '백업'];
const _tone = {'ok': 'good', 'good': 'good', 'warn': 'warn', 'err': 'bad', 'bad': 'bad'};
// 지역 점수 0~10 (관광객 별점·코스 선택·허브 혼잡도로 실시간 계산)
Color _scoreColor(num s) => s >= 7 ? C.good : s >= 5 ? C.sky : C.bad;
String _fmtAt(String? iso) => iso == null || iso.length < 16 ? '' : iso.substring(5, 16).replaceFirst('T', ' ');

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
        KeyedSubtree(key: ValueKey(_tab), child: [const _Overview(), const _Reports(), const _DataTab(), const _Security(), const _Backups()][_tab]),
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
  Json? _scores;
  List<Json>? _places;
  Timer? _every, _soon;

  // 지역 점수: 30초마다, 그리고 코스 선택·평가 이벤트가 오면 (2초 모아서) 다시 계산
  Future<void> _loadScores() async {
    try {
      final s = await getRegionScores();
      if (mounted) setState(() => _scores = s);
    } catch (_) {}
    try {
      final p = await getPlaceOverview();
      if (mounted) setState(() => _places = p);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadScores();
    _every = Timer.periodic(const Duration(seconds: 30), (_) => _loadScores());
    _stop = subscribeEvents((e) {
      if (!mounted) return;
      setState(() {
        _events.insert(0, e);
        if (_events.length > 30) _events.removeLast();
      });
      _soon?.cancel();
      _soon = Timer(const Duration(seconds: 2), _loadScores);
    });
  }

  @override
  void dispose() {
    _stop();
    _every?.cancel();
    _soon?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Loader(
        load: getAdminOverview,
        builder: (d, _) {
          final o = d['overview'] as Json;
          final pos = {for (final h in (d['health'] as List).cast<Json>()) h['regionId']: h};
          final scores = ((_scores?['regions'] as List?) ?? const []).cast<Json>();
          return VStack(children: [
            Grid(cols: 4, minCols: 2, children: [
              for (final (k, v) in [('오늘 방문 인증', o['visits']), ('오늘 평가', o['reviews']), ('오늘 만든 코스', o['courses']), ('초당 이벤트', o['eventsPerSec'])])
                AppCard(child: VStack(gap: 4, children: [T.label(k), Text(comma(v as num), style: tx(size: 24, weight: FontWeight.w700, height: 1.3))])),
            ]),
            Grid(cols: 2, children: [
              AppCard(
                child: VStack(gap: 12, children: [
                  Between(left: const T.h3('지역 점수 (0~10)'), right: T.muted(_scores == null ? '계산 중…' : '${_fmtAt(_scores!['updatedAt'])} 계산', size: 13)),
                  T.muted('관광객 별점 만족도 50% · 최근 7일 코스 선택과 평가 30% · 데이터허브 혼잡도 20%${_scores?['crowdDate'] != null ? ' (${_scores!['crowdDate']})' : ''}', size: 13),
                  KakaoMap(circles: [
                    for (final r in scores)
                      if (pos[r['regionId']] != null)
                        MapCircle((pos[r['regionId']]!['lat'] as num).toDouble(), (pos[r['regionId']]!['lon'] as num).toDouble(), _scoreColor(r['score'] as num), '${r['name']} ${r['score']}'),
                  ]),
                  SimpleTable(
                    head: const ['지역', '점수', '만족도', '수요', '쾌적함', '평가'],
                    flex: const [3, 1, 1, 1, 1, 2],
                    right: const {1, 2, 3, 4, 5},
                    rows: [
                      for (final r in scores)
                        [
                          T.small(r['name']), T.small('${r['score']}'), T.small('${r['satisfaction']}'), T.small('${r['demand']}'),
                          T.small('${r['comfort'] ?? '-'}'), T.small('${r['reviews']}${r['avgStars'] != null ? ' ★${r['avgStars']}' : ''}'),
                        ],
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
            AppCard(
              child: VStack(gap: 12, children: [
                const T.h3('장소별 평가 (고유 번호)'),
                const T.muted('평가가 들어오면 사장님 화면에 바로 알리고 Agent가 분석해요', size: 13),
                if (_places == null) const T.muted('불러오는 중…'),
                if (_places != null)
                  SimpleTable(
                    head: const ['번호', '장소', '평가', '평균', '사장님', '최근 분석'],
                    flex: const [1, 3, 1, 1, 1, 2],
                    right: const {0, 2, 3},
                    rows: [
                      for (final p in [
                        ..._places!.where((p) => (p['reviews'] as num? ?? 0) > 0 || p['owner'] == true),
                        ..._places!.where((p) => (p['reviews'] as num? ?? 0) == 0 && p['owner'] != true),
                      ].take(30))
                        [
                          T.small('#${p['no']}'), T.small('${p['name']}'), T.small('${p['reviews']}'),
                          T.small(p['avgStars'] != null ? '★${p['avgStars']}' : '-'),
                          p['owner'] == true ? const Align(alignment: Alignment.centerLeft, child: Pill('연결', tone: 'good')) : const T.muted('-', size: 13),
                          T.muted(p['lastAnalysis'] == null ? '-' : _fmtAt((p['lastAnalysis'] as Json)['createdAt']), size: 13),
                        ],
                    ],
                  ),
              ]),
            ),
          ]);
        },
      );
}

class _Reports extends StatefulWidget {
  const _Reports();
  @override
  State<_Reports> createState() => _ReportsState();
}

class _ReportsState extends State<_Reports> {
  List<Json>? _list;
  Json? _open;
  bool _busy = false;
  String _err = '';

  @override
  void initState() {
    super.initState();
    getRegionReports().then((l) {
      if (mounted) setState(() { _list = l; _open = l.isEmpty ? null : l.first; });
    }).catchError((Object e) {
      if (mounted) setState(() { _list = []; _err = '$e'; });
    });
  }

  Future<void> _make() async {
    setState(() { _busy = true; _err = ''; });
    try {
      final r = await createRegionReport();
      if (mounted) setState(() { _list = [r, ...?_list]; _open = r; });
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Grid(cols: 2, children: [
        AppCard(
          child: VStack(gap: 10, children: [
            Between(left: const T.h3('저장된 보고서'), right: Btn(_busy ? '작성 중…' : '지금 보고서 만들기', small: true, primary: true, onPressed: _busy ? null : _make)),
            const T.muted('Agent가 관광객 평가·코스 선택·지역 점수를 읽고 문서를 써서 Main PC에 저장해요. 허브 수치는 등급으로만 넘겨요.', size: 13),
            if (_err.isNotEmpty) Note(_err),
            if (_list == null) const Loading()
            else if (_list!.isEmpty) const T.muted('아직 보고서가 없어요.')
            else
              for (final r in _list!)
                GestureDetector(
                  onTap: () => setState(() => _open = r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: _open?['id'] == r['id'] ? C.mist : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                    child: Between(left: T.small(r['title'] ?? ''), right: Pill(r['source'] == 'gpt' ? 'GPT' : '규칙')),
                  ),
                ),
          ]),
        ),
        AppCard(
          child: _open == null
              ? const T.muted('보고서를 고르거나 새로 만들어 주세요.')
              : VStack(gap: 8, children: [T.h3(_open!['title'] ?? ''), Markdown(_open!['body'] ?? '')]),
        ),
      ]);
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
