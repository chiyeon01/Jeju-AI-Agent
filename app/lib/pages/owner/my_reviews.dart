// 내 가게 별점·리뷰 (관광객이 앱·웹에서 남긴 실제 평가) + Agent 리뷰 분석 (React 의 pages/owner/MyReviews.jsx 와 같음)
import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/markdown.dart';
import '../../widgets/ui.dart';

String _at(String? iso) => iso == null || iso.length < 16 ? '' : iso.substring(5, 16).replaceFirst('T', ' ');

class MyReviews extends StatefulWidget {
  const MyReviews({super.key, this.onData});
  /// 연결된 내 가게 데이터가 바뀌면 알려 줍니다 (가게 미연결·다시 고르는 중이면 null)
  final void Function(Json? d)? onData;
  @override
  State<MyReviews> createState() => _MyReviewsState();
}

class _MyReviewsState extends State<MyReviews> {
  Json? _d;
  bool _loading = true, _busy = false, _relink = false;
  String _err = '';
  List<Json> _places = const [];
  String? _pick;
  String _toast = '';
  Timer? _toastTimer;
  void Function()? _off;
  String? _subPlace;
  final _q = TextEditingController();
  Timer? _searchDebounce, _refresh;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _off?.call();
    _toastTimer?.cancel();
    _searchDebounce?.cancel();
    _refresh?.cancel();
    _q.dispose();
    super.dispose();
  }

  // 실시간: 내 가게에 새 평가가 오면 알림 + 목록 새로고침, Agent 가 분석을 저장하면 결과 새로고침
  void _subscribe(String? placeId) {
    if (placeId == _subPlace) return;
    _off?.call();
    _off = null;
    _subPlace = placeId;
    if (placeId == null) return;
    _off = subscribeMyStore((e) {
      if (!mounted || (e['placeId'] != null && e['placeId'] != placeId)) return;
      final String msg;
      if (e['type'] == '평가 등록') {
        msg = '새 평가 ${'★' * ((e['stars'] as num?)?.toInt() ?? 0)} · ${e['text'] ?? ''} — Agent가 곧 분석해요';
      } else if (e['type'] == '리뷰 분석') {
        msg = 'Agent가 새 리뷰 분석을 저장했어요';
      } else {
        return;
      }
      setState(() => _toast = msg);
      _toastTimer?.cancel();
      _toastTimer = Timer(const Duration(seconds: 6), () => mounted ? setState(() => _toast = '') : null);
      _load(quiet: true);
    });
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    try {
      final d = await getMyReviews();
      if (!mounted) return;
      setState(() => _d = d);
      widget.onData?.call(d);
      _subscribe((d?['place'] as Json?)?['id'] as String?);
      if (d == null) await _loadPlaces();
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 가게 검색: 관광객이 실제로 평점을 남긴 가게만 백엔드에서 검색. 검색 화면이 열려 있는 동안 10초마다 새로고침
  Future<void> _loadPlaces() async {
    _refresh ??= Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || (_d != null && !_relink)) {
        _refresh?.cancel();
        _refresh = null;
        return;
      }
      _search(quiet: true);
    });
    await _search();
  }

  Future<void> _search({bool quiet = false}) async {
    if (!quiet && mounted) setState(() => _searching = true);
    try {
      final p = await getMerchantPlaces(_q.text);
      if (mounted) setState(() { _places = p.where((x) => ((x['reviews'] as num?) ?? 0) > 0).toList(); _err = ''; });
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _onQuery(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), _search);
  }

  Future<void> _link() async {
    if (_pick == null) return;
    try {
      await linkMyPlace(_pick!);
      _relink = false;
      await _load();
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  Future<void> _analyze() async {
    setState(() { _busy = true; _err = ''; });
    try {
      final a = await analyzeMyReviews();
      if (mounted) setState(() => _d = {...?_d, 'analysis': a});
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppCard(child: T.muted('내 가게 평가를 불러오는 중…'));
    final d = _d;
    if (d == null || _relink) {
      return AppCard(
        child: VStack(gap: 10, children: [
          const T.h3('내 가게 선택'),
          const T.muted('관광객 평점을 받은 가게만 검색돼요. 내 가게를 골라 연결하면 별점·리뷰와 AI 분석을 볼 수 있어요.', size: 13),
          AppInput(key: const ValueKey('place-search'), controller: _q, hint: '가게 이름으로 검색', onChanged: _onQuery),
          if (_searching && _places.isEmpty) const T.muted('검색 중…', size: 13),
          if (!_searching && _places.isEmpty)
            T.muted(_q.text.trim().isEmpty
                ? '아직 관광객 평점을 받은 가게가 없어요. 관광객이 앱에서 평점을 남기면 여기에 나타나요.'
                : "'${_q.text.trim()}'에 해당하는, 관광객 평점을 받은 가게가 없어요.", size: 13),
          for (final p in _places)
            Material(
              color: _pick == p['id'] ? C.skyDeep.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _pick = p['id'] as String),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Between(
                    left: T.small('${p['no'] != null ? '#${p['no']} ' : ''}${p['name']} · ${storeKinds[p['kind']] ?? p['kind']}'),
                    right: T.muted('★ ${((p['avgStars'] as num?) ?? 0).toStringAsFixed(1)} · ${p['reviews'] ?? 0}건', size: 13),
                  ),
                ),
              ),
            ),
          Btn('연결', primary: true, onPressed: _pick == null ? null : _link),
          if (_err.isNotEmpty) Note(_err),
        ]),
      );
    }
    final s = d['summary'] as Json;
    final dist = (s['dist'] as Map).map((k, v) => MapEntry('$k', (v as num).toInt()));
    final maxN = [1, ...dist.values].reduce((a, b) => a > b ? a : b);
    final count = (s['count'] as num).toInt();
    final avg = (s['avg'] as num).toDouble();
    final region = d['regionScore'] as Json?;
    final reviews = (d['reviews'] as List).cast<Json>();
    final types = (s['byType'] as List).cast<Json>();
    final a = d['analysis'] as Json?;
    final grid = Grid(cols: 2, children: [
      AppCard(
        child: VStack(gap: 10, children: [
          Between(left: const T.h3('내 가게 별점·리뷰'), right: Btn('가게 바꾸기', small: true, ghost: true, onPressed: () {
            setState(() { _relink = true; _pick = (d['place'] as Json)['id']; });
            widget.onData?.call(null);
            _loadPlaces();
          })),
          T.muted('${(d['place'] as Json)['name']}${(d['place'] as Json)['no'] != null ? ' · 장소 #${(d['place'] as Json)['no']}' : ''}${region != null ? ' · ${region['name']} 지역 점수 ${region['score']}/10' : ''}', size: 13),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(count > 0 ? avg.toStringAsFixed(1) : '-', style: tx(size: 44, weight: FontWeight.w700, color: C.skyDeep, height: 1)),
            const SizedBox(width: 6),
            const T.muted('/ 5'),
            const SizedBox(width: 14),
            VStack(gap: 2, cross: CrossAxisAlignment.start, children: [Stars(value: avg.round()), T.muted('관광객 평가 $count건', size: 13)]),
          ]),
          for (final n in [5, 4, 3, 2, 1])
            Row(children: [
              SizedBox(width: 32, child: T.small('$n점')),
              Expanded(child: Bar((dist['$n'] ?? 0) / maxN, color: C.skyDeep)),
              SizedBox(width: 32, child: T.small('${dist['$n'] ?? 0}', align: TextAlign.right)),
            ]),
          if (types.isNotEmpty) Wrap(spacing: 6, runSpacing: 6, children: [for (final t in types.take(4)) Pill('${t['name']} ${t['count']}')]),
          const T.h3('최근 리뷰'),
          if (reviews.isEmpty) const T.muted('아직 리뷰가 없어요.'),
          for (final r in reviews.take(8))
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
              child: VStack(gap: 2, children: [
                Between(left: Align(alignment: Alignment.centerLeft, child: Stars(value: (r['stars'] as num).toInt())), right: T.muted(_at(r['createdAt']), size: 12)),
                (r['text'] ?? '').toString().isEmpty ? const T.muted('별점만 남겼어요.', size: 13) : T.small(r['text']),
              ]),
            ),
        ]),
      ),
      AppCard(
        child: VStack(gap: 10, children: [
          Between(left: const T.h3('Agent 리뷰 분석'), right: Btn(_busy ? '분석 중…' : a != null ? '다시 분석' : '분석하기', small: true, primary: true, onPressed: _busy ? null : _analyze)),
          if (_err.isNotEmpty) Note(_err),
          if (a != null) ...[
            T.muted('${_at(a['createdAt'])} · ${a['source'] == 'gpt' ? 'GPT 분석' : '규칙 기반 분석'}', size: 13),
            Markdown(a['body'] ?? ''),
          ] else
            const T.muted('별점과 리뷰를 읽고 강점·개선할 점·다음 할 일을 정리해 드려요. 결과는 저장돼서 다음에 다시 볼 수 있어요.', size: 13),
        ]),
      ),
    ]);
    if (_toast.isEmpty) return grid;
    return VStack(children: [
      Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: C.skyInk, borderRadius: BorderRadius.circular(12)),
          child: T.small(_toast, color: C.surface),
        ),
      ),
      grid,
    ]);
  }
}
