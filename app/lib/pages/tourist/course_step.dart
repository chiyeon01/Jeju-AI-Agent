import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../api/course_edit.dart';
import '../../api/hub.dart';
import '../../api/planner.dart';
import '../../api/weather.dart';
import '../../data/tourist_mock.dart';
import '../../theme.dart';
import '../../widgets/kakao_map.dart';
import '../../widgets/ui.dart';

// GPT 로 짠 코스면 자유로운 요청 예시, 아니면 규칙 기반이 알아듣는 예시
List<String> _suggestFor(Course? c) => c?.source == 'gpt'
    ? const ['더 여유롭게 바꿔줘', '사진 찍기 좋은 곳 넣어줘', '저녁은 해산물로', '18시에 출발할래']
    // 백엔드 대화는 해산물·줄이기·실내만 바꾸고, "더 넣어줘"류는 앱에서 직접 처리합니다 (api/course_edit.dart)
    : const ['1곳 더 넣어줘', '카페 하나 추가해줘', '저녁은 해산물로 바꿔줘', '1곳 줄여줘', '실내로 바꿔줘'];

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

  @override
  void initState() {
    super.initState();
    _start();
  }

  // 1) 출발 지역 기준 실시간 날씨 + 제주데이터허브(혼잡도·관광지 방문객), 5초까지만 기다림
  //    날씨는 사용자가 고르지 않고 항상 실시간 값을 씁니다. 비나 눈이면 실내 코스로 시작 → 2) 코스
  Future<void> _start() async {
    setState(() => _ready = false);
    Future<V?> soft<V>(Future<V> f) => f.timeout(const Duration(seconds: 5)).then<V?>((v) => v).catchError((_) => null);
    final wf = soft(getLiveWeather(widget.origin.lat, widget.origin.lon));
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
      _course = c;
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
            _course = ai.course;
            _startTime = ai.startTime ?? _startTime;
          }
        });
        return;
      }
      // 백엔드가 못 하는 "늘려줘·추가해줘" 는 앱에서 장소를 골라 넣습니다
      final add = addToCourse(m, course, startTime: _startTime, rain: _opts.weather == 'rain', hub: _hub);
      if (add != null) {
        setState(() {
          _msgs.add((false, add.reply));
          if (add.course != null) {
            _course = add.course;
            _added = [..._added, ...add.added];
          }
        });
        return;
      }
      final r = await chatCourse(m);
      if (!mounted) return;
      setState(() => _msgs.add((false, r.reply)));
      final p = r.patch;
      if (p != null) {
        // 줄이기는 대화로 추가한 장소부터 뺍니다
        var remove = p.removeCount;
        while (remove > 0 && _added.isNotEmpty) {
          _added = _added.sublist(0, _added.length - 1);
          remove--;
        }
        _opts = _opts.copyWith(weather: p.weather, seafood: p.seafood, removeCount: _opts.removeCount + remove);
        _plan();
      }
    } catch (e) {
      if (mounted) setState(() => _msgs.add((false, '지금은 답하지 못했어요. 잠시 뒤 다시 말해 주세요.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final indoorAsked = _opts.weather == 'rain' && _live?.code != 'rain';
    final hubNote = hubLine(_hub);
    final hubOn = _hub != null && !_hub!.isEmpty;
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
      if (hubNote != null) T.small(hubNote, color: C.muted),
      Between(
        left: T.small(
            _course?.source == 'gpt'
                ? 'AI(GPT) 코스 · 반영: ${['성향', if (_live != null) '실시간 날씨', if (hubOn) '데이터허브 혼잡도·방문객'].join(', ')}'
                : '데이터 점수로 짠 코스예요${_live != null ? ' · 실시간 날씨 반영' : ''}',
            color: C.muted),
        right: Btn('다른 코스 보기', small: true, ghost: true, onPressed: _course == null || _busy
                ? null
                : () {
                    _added = const [];
                    _plan();
                  }),
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
      ChatPanel(title: '대화로 코스 고치기', messages: _msgs, suggestions: _suggestFor(_course), onSend: _send, busy: _busy || _course == null, hint: '예: 카페는 바다 보이는 곳으로'),
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
              Text(p.name, style: tx(weight: FontWeight.w700)),
              Pill(kindLabel[p.kind] ?? p.kind),
            ]),
            for (final (src, text) in [if (stop.why != null) ('AI', stop.why!), ...p.reasons].take(2))
              Text.rich(TextSpan(children: [
                TextSpan(text: '$src  ', style: tx(size: 13, weight: FontWeight.w600, color: C.skyDeep)),
                TextSpan(text: keepAll(text), style: tx(size: 13, color: C.muted)),
              ])),
          ]),
        ),
      ]),
    );
  }
}
