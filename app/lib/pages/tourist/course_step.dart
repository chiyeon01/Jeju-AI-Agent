import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../api/course_edit.dart';
import '../../api/hub.dart';
import '../../api/planner.dart';
import '../../api/weather.dart';
import '../../data/tourist_mock.dart';
import '../../theme.dart';
import '../../widgets/kakao_map.dart';
import '../../widgets/place_link.dart';
import '../../widgets/ui.dart';

// 대화로 코스 고치기 예시 (백엔드 대화 Agent 가 아이 동반·분위기 좋은 카페·해산물로 알아듣습니다)
const _suggest = ['아기가 놀기 좋은 곳으로 수정해줘.', '분좋카를 원해.', '회를 먹고싶어.'];

class CourseStep extends StatefulWidget {
  const CourseStep({super.key, required this.profile, required this.origin, required this.onDone, required this.onBack});
  final Profile profile;
  final Region origin;
  final void Function(Course course, LiveWeather? live) onDone;
  final VoidCallback onBack;
  @override
  State<CourseStep> createState() => _CourseStepState();
}

class _CourseStepState extends State<CourseStep> {
  CourseOpts _opts = const CourseOpts();
  bool _ready = false; // 실시간 날씨를 확인했는지
  Course? _course;
  late String _startTime = widget.profile.startTime;
  late final List<(bool, String)> _msgs = [(false, '${widget.origin.name}에서 출발하는 코스를 짜고 있어요.')];
  int _req = 0;
  bool _busy = false;
  LiveWeather? _live;
  HubData? _hub;
  List<String> _added = const []; // 대화로 추가한 장소 id (백엔드가 코스를 다시 짜도 유지)
  final Set<String> _seen = {}; // 지금까지 보여 준 장소 ("다른 코스 보기"에서 피함)

  void _show(Course c) {
    _course = c;
    _seen.addAll(c.stops.map((s) => s.place.id));
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  // 1) 출발 지역 기준 실시간 날씨(12초) + 제주데이터허브(혼잡도·관광지 방문객, 5초)까지만 기다림
  //    날씨는 사용자가 고르지 않고 항상 실시간 값을 씁니다. 비나 눈이면 실내 코스로 시작 → 2) 코스
  Future<void> _start() async {
    setState(() => _ready = false);
    Future<V?> soft<V>(Future<V> f, [int secs = 5]) => f.timeout(Duration(seconds: secs)).then<V?>((v) => v).catchError((_) => null);
    final wf = soft(getLiveWeather(widget.origin.lat, widget.origin.lon), 12);
    final hf = soft(getHubData());
    final w = await wf;
    final h = await hf;
    if (!mounted) return;
    setState(() {
      _live = w;
      _hub = h;
      _ready = true;
      if (w != null) _opts = _opts.copyWith(weather: w.code);
    });
    _plan();
  }

  // 코스 만들기: GPT(성향 + 실시간 날씨 + 출발지) → 안 되면 기존 방식
  Future<void> _plan() async {
    final my = ++_req;
    setState(() {
      _course = null;
      _startTime = widget.profile.startTime;
    });
    final ai = await planCourseAI(profile: widget.profile, origin: widget.origin, weather: _opts.weather, live: _live, hub: _hub);
    final Course c;
    if (ai != null) {
      c = ai;
    } else {
      // 규칙 기반 코스에도 허브 근거(방문객·혼잡도)를 붙입니다
      final rule = await planCourse(profile: widget.profile, origin: widget.origin, opts: _opts);
      final kept = keepAdded(rule.stops, _added, widget.profile.startTime);
      final withHub = applyHub([for (final s in kept) s.place], _hub);
      c = Course(rule.weather, [for (var i = 0; i < kept.length; i++) Stop(withHub[i], kept[i].at, kept[i].move, why: kept[i].why)],
          summary: rule.summary, source: rule.source);
    }
    if (!mounted || my != _req) return;
    setState(() {
      _show(c);
      final first = _msgs.length == 1;
      final text = c.summary.isNotEmpty
          ? '${c.summary} 바꾸고 싶은 점을 편하게 말해 주세요.'
          : '${widget.origin.name}에서 출발하는 코스예요. 바꾸고 싶은 점을 말해 주세요.';
      if (first) {
        _msgs[0] = (false, text);
      } else if (c.summary.isNotEmpty) {
        _msgs.add((false, text));
      }
    });
  }

  Future<void> _send(String m) async {
    final course = _course;
    if (_busy || course == null) return;
    final history = [..._msgs];
    setState(() {
      _msgs.add((true, m));
      _busy = true;
    });
    try {
      final ai = await chatCourseAI(
          message: m, history: history, course: course, profile: widget.profile, origin: widget.origin,
          weather: _opts.weather, live: _live, hub: _hub, startTime: _startTime);
      if (!mounted) return;
      if (ai != null) {
        setState(() {
          _msgs.add((false, ai.reply));
          if (ai.course != null) {
            _show(ai.course!);
            _startTime = ai.startTime ?? _startTime;
          }
        });
        return;
      }
      // 서버 Agent(GPT)에게 사용자 말을 그대로 보내고, 고친 코스를 받습니다
      final r = await chatCourse(m, stopIds: [for (final s in course.stops) s.place.id], history: history);
      if (!mounted) return;
      final edited = r.course;
      if (edited != null) {
        final withHub = applyHub([for (final s in edited.stops) s.place], _hub);
        setState(() {
          _added = const [];
          _msgs.add((false, r.reply));
          _show(Course(edited.weather, [for (var i = 0; i < edited.stops.length; i++) Stop(withHub[i], edited.stops[i].at, edited.stops[i].move)],
              summary: course.summary, source: edited.source));
        });
        return;
      }
      final p = r.patch;
      if (p != null) {
        setState(() => _msgs.add((false, r.reply)));
        // 줄이기는 대화로 추가한 장소부터 뺍니다
        var remove = p.removeCount;
        if (remove < 0) _added = const []; // "처음 코스로 되돌려줘"
        while (remove > 0 && _added.isNotEmpty) {
          _added = _added.sublist(0, _added.length - 1);
          remove--;
        }
        _opts = _opts.copyWith(weather: p.weather, seafood: p.seafood, removeCount: _opts.removeCount + remove);
        _plan();
        return;
      }
      // GPT 가 없는 서버: "늘려줘·미술관 넣어줘" 는 앱에서 장소를 골라 넣습니다
      final add = addToCourse(m, course, startTime: _startTime, rain: _opts.weather == 'rain', hub: _hub);
      setState(() {
        if (add == null) {
          _msgs.add((false, r.reply));
          return;
        }
        _msgs.add((false, add.reply));
        if (add.course != null) {
          _show(add.course!);
          _added = [..._added, ...add.added];
        }
      });
    } catch (e) {
      if (mounted) setState(() => _msgs.add((false, '지금은 답하지 못했어요. 잠시 뒤 다시 말해 주세요.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // 다른 코스 보기: 지금까지 본 장소를 피해서 Agent(GPT)가 새로 고릅니다
  Future<void> _another() async {
    if (_course == null || _busy) return;
    setState(() => _busy = true);
    _added = const [];
    final my = ++_req;
    try {
      final c = await alternativeCourse(profile: widget.profile, origin: widget.origin, opts: _opts, avoid: _seen);
      final withHub = applyHub([for (final s in c.stops) s.place], _hub);
      if (!mounted || my != _req) return;
      setState(() {
        _show(Course(c.weather, [for (var i = 0; i < c.stops.length; i++) Stop(withHub[i], c.stops[i].at, c.stops[i].move)],
            summary: c.summary, source: c.source));
        _startTime = widget.profile.startTime;
        _msgs.add((false, '${c.summary.isNotEmpty ? c.summary : '다른 코스를 찾았어요.'} 바꾸고 싶은 점을 말해 주세요.'));
      });
    } catch (_) {
      if (mounted) setState(() => _msgs.add((false, '다른 코스를 찾지 못했어요. 잠시 뒤 다시 눌러 주세요.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final indoorAsked = _opts.weather == 'rain' && _live?.code != 'rain';
    final left = VStack(children: [
      Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
        VStack(gap: 2, cross: CrossAxisAlignment.start, children: [
          T.label('${widget.origin.name} 출발 · ${widget.profile.name}'),
          const T.h2('오늘의 추천 코스'),
        ]),
      ]),
      Note(!_ready
          ? '실시간 날씨를 불러오는 중…'
          : _live != null
              ? '${_live!.line}${indoorAsked ? ' · 요청대로 실내 위주' : ''}'
              : '실시간 날씨를 불러오지 못했어요. 날씨와 상관없이 짠 코스예요'),
      if (_ready && _live == null) Align(alignment: Alignment.centerLeft, child: Btn('날씨 다시 불러오기', small: true, ghost: true, onPressed: _start)),
      Between(
        left: T.small('${_course?.source == 'gpt' ? 'AI가 고른 코스예요' : '내 성향에 맞춰 짠 코스예요'} · 이름을 누르면 네이버 지도로 열려요', color: C.muted),
        right: Btn(_busy && _course != null ? '찾는 중…' : '다른 코스 보기', small: true, ghost: true, onPressed: _course == null || _busy ? null : _another),
      ),
      AppCard(
        child: _course == null
            ? const T.muted('코스를 만드는 중…')
            : Column(children: [
                for (var i = 0; i < _course!.stops.length; i++) _StopRow(stop: _course!.stops[i], first: i == 0, last: i == _course!.stops.length - 1),
              ]),
      ),
    ]);
    final right = VStack(children: [
      KakaoMap(
        lat: widget.origin.lat,
        lon: widget.origin.lon,
        level: 9,
        path: true,
        markers: [for (final s in _course?.stops ?? const <Stop>[]) MapMarker(s.place.lat, s.place.lon, s.place.name)],
      ),
      ChatPanel(title: '대화로 코스 고치기', messages: _msgs, suggestions: _suggest, onSend: _send, busy: _busy || _course == null, hint: '예: 카페는 바다 보이는 곳으로'),
      Between(
        left: Align(alignment: Alignment.centerLeft, child: Btn('위치 다시 고르기', ghost: true, onPressed: widget.onBack)),
        right: Btn('여행 끝, 평가하기', primary: true, onPressed: _course == null ? null : () => widget.onDone(_course!, _live)),
      ),
    ]);
    return Grid(cols: 2, children: [left, right]);
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop, required this.first, required this.last});
  final Stop stop;
  final bool first, last;
  @override
  Widget build(BuildContext context) {
    final p = stop.place;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: C.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 56, child: Text(stop.at, style: tx(weight: FontWeight.w700, color: C.skyDeep))),
        Expanded(
          child: VStack(gap: 4, children: [
            if (!first) T.muted('이동 약 ${stop.move}분'),
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              PlaceLink(p.name),
              ...placeMeta(p.name, kind: p.kind, label: p.label, addr: p.addr),
            ]),
            PlacePhoto(p.name),
          ]),
        ),
      ]),
    );
  }
}
