// 상권 주인 대시보드 (React 의 pages/owner/OwnerDashboard.jsx 와 같음)
// 처음 들어오면 내 가게(관광객 평점을 받은 가게)를 먼저 고르고, 연결된 뒤에만 아래 분석이 열립니다.
// 모든 값은 관광객이 앱에서 실제로 남긴 별점·리뷰로 만듭니다 (시연용 고정 데이터 없음).
import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';
import 'my_reviews.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});
  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  Json? _d; // 연결된 내 가게 (null 이면 가게 선택 화면)
  Json? _topics;
  String _topicsErr = '';
  int? _topicsFor; // 주제 분석을 불러온 리뷰 수 (새 평가가 오면 다시 불러옴)
  final List<(bool, String)> _chat = [(false, '관광객 별점·리뷰에 대해 궁금한 점을 물어보세요.')];
  bool _asking = false;
  final _action = TextEditingController();
  final List<String> _saved = [];

  @override
  void dispose() {
    _action.dispose();
    super.dispose();
  }

  void _onData(Json? d) {
    setState(() => _d = d);
    final count = ((d?['summary'] as Json?)?['count'] as num?)?.toInt();
    if (d != null && count != _topicsFor) {
      _topicsFor = count;
      setState(() { _topics = null; _topicsErr = ''; });
      getReviewTopics().then((t) => mounted ? setState(() => _topics = t) : null).catchError((Object e) {
        if (mounted) setState(() => _topicsErr = '$e');
      });
    }
  }

  Future<void> _ask(String q) async {
    setState(() {
      _asking = true;
      _chat.add((true, q));
    });
    String a;
    try {
      a = await askOwnerAgent(q);
    } catch (e) {
      a = '$e';
    }
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

  Widget _topicsCard() {
    final t = _topics;
    final topics = [...((t?['topics'] as List?) ?? const []).cast<Json>()]..sort((a, b) => (a['pos'] as num).compareTo(b['pos'] as num));
    return AppCard(
      child: VStack(gap: 12, children: [
        Between(
          left: const T.h3('리뷰 주제별 반응'),
          right: t == null ? const SizedBox.shrink() : T.muted('${t['source'] == 'gpt' ? 'GPT 분석' : '규칙 기반 분석'} · 리뷰 ${t['textCount']}건', size: 13),
        ),
        if (_topicsErr.isNotEmpty) Note(_topicsErr),
        if (t == null && _topicsErr.isEmpty) const T.muted('GPT가 리뷰를 읽고 있어요…', size: 13),
        if (t != null && topics.isEmpty) const T.muted('아직 분석할 리뷰 글이 없어요. 관광객이 한 줄 평을 남기면 주제별로 정리해 드려요.', size: 13),
        for (final x in topics)
          VStack(gap: 4, children: [
            Between(
              left: Wrap(spacing: 6, children: [T.small(x['topic']), if ((x['pos'] as num) < 60) const Pill('개선 필요', tone: 'bad')]),
              right: T.muted('긍정 ${x['pos']}% · ${x['mentions']}건', size: 13),
            ),
            Bar((x['pos'] as num) / 100, color: (x['pos'] as num) < 60 ? C.bad : C.sky),
            if ((x['summary'] ?? '').toString().isNotEmpty) T.muted(x['summary'], size: 13),
          ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final place = d?['place'] as Json?;
    final region = d?['regionScore'] as Json?;
    return PageBody(children: [
      if (place == null)
        const T.h1('내 가게를 선택해 주세요')
      else
        VStack(gap: 2, children: [
          T.label([if (region != null) region['name'], storeKinds[place['kind']] ?? place['kind']].join(' · ')),
          T.h1(place['name']),
        ]),
      MyReviews(onData: _onData),
      if (place != null)
        Grid(cols: 2, children: [
          _topicsCard(),
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
