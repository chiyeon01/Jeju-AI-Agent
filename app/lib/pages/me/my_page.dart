// 내 정보 · 설정 (상단 이름을 누르면 열림) — 웹 MyPage.jsx 와 같은 내용
import 'package:material_ui/material_ui.dart';

import '../../api/client.dart' as api;
import '../../api/history.dart';
import '../../data/auth_mock.dart';
import '../../settings.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';

const _statusLabel = {'ACTIVE': '사용 중', 'PENDING': '승인 대기', 'SUSPENDED': '이용 정지'};

class MyPage extends StatefulWidget {
  const MyPage({super.key, required this.user, required this.onLogout});
  final api.AppUser user;
  final VoidCallback onLogout;
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  late api.AppUser _me = widget.user;
  String _err = '';
  int _count = 0;

  @override
  void initState() {
    super.initState();
    api.fetchMe().then((u) {
      if (mounted && u != null) setState(() => _me = u);
    }).catchError((Object e) {
      if (mounted) setState(() => _err = '$e');
    });
    loadHistory(widget.user.id).then((h) {
      if (mounted) setState(() => _count = h.count);
    });
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: T.muted(k)),
          Expanded(child: T(v, weight: FontWeight.w600, size: 15)),
        ]),
      );

  @override
  Widget build(BuildContext context) => PageBody(narrow: true, children: [
        const T.h2('내 정보'),
        AppCard(
          child: VStack(gap: 8, children: [
            _row('이름', _me.name),
            _row('이메일', _me.email),
            _row('계정 종류', roleLabel[_me.role] ?? _me.role),
            _row('상태', _statusLabel[_me.status] ?? _me.status),
            if (_me.storeId != null) _row('가게 ID', _me.storeId!),
            _row('회원 번호', _me.id),
            if (_err.isNotEmpty) T.small('최신 정보를 불러오지 못했어요: $_err', color: C.bad),
            T.muted(api.isMock ? '목업 모드라 이 기기에 저장된 정보예요.' : '서버(/auth/me)에 저장된 정보예요.', size: 13),
          ]),
        ),
        const T.h2('설정'),
        AppCard(
          child: ValueListenableBuilder<int>(
            valueListenable: brightness,
            builder: (context, b, _) => VStack(gap: 8, children: [
              Between(left: const T('화면 밝기', weight: FontWeight.w600, size: 15), right: T.muted('$b%')),
              Semantics(
                label: '화면 밝기',
                child: Slider(
                  value: b.toDouble(),
                  min: brightnessMin.toDouble(),
                  max: 100,
                  divisions: (100 - brightnessMin) ~/ 5,
                  activeColor: C.skyDeep,
                  inactiveColor: C.line,
                  onChanged: (v) => setBrightness(v.round()),
                ),
              ),
              Between(
                left: const T.muted('밤에 보기 편하게 화면을 어둡게 할 수 있어요. 이 기기에 저장돼요.', size: 13),
                right: Btn('원래 밝기', small: true, onPressed: b == 100 ? null : () => setBrightness(100)),
              ),
            ]),
          ),
        ),
        AppCard(
          child: Between(
            left: VStack(gap: 2, cross: CrossAxisAlignment.start, children: [
              const T('내 여행 기록', weight: FontWeight.w700, size: 15),
              T.muted('성향 테스트·코스·평가 기록 $_count건이 이 기기에 저장돼 있어요.', size: 13),
            ]),
            right: Btn('기록 지우기', small: true, onPressed: _count == 0
                ? null
                : () async {
                    await clearHistory(widget.user.id);
                    if (mounted) setState(() => _count = 0);
                  }),
          ),
        ),
        Align(alignment: Alignment.centerLeft, child: Btn('로그아웃', ghost: true, onPressed: widget.onLogout)),
      ]);
}
