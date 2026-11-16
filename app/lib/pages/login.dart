// 로그인 · 회원가입 (관광객 / 상권 주인). 관리자 계정은 백엔드에서 만듭니다.
import 'package:material_ui/material_ui.dart';

import '../api/client.dart' as api;
import '../data/auth_mock.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class _AuthFrame extends StatelessWidget {
  const _AuthFrame({required this.title, this.subtitle, required this.children});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.sky, C.sea, C.mist], stops: [0, .35, .75]),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: AppCard(
                    padding: 28,
                    child: VStack(children: [
                      Column(children: [
                        T.h1(title, color: C.skyDeep, align: TextAlign.center),
                        if (subtitle != null) T.muted(subtitle!, align: TextAlign.center),
                      ]),
                      ...children,
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth});
  final AuthController auth;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  String _error = '';
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit([String? email, String? pw]) async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await widget.auth.login(email ?? _email.text, pw ?? _pw.text);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthFrame(
        title: '제주잇다',
        subtitle: '여행자와 동네 가게를 잇는 제주 AI 길잡이',
        children: [
          Field('이메일', child: AppInput(controller: _email, keyboard: TextInputType.emailAddress)),
          Field('비밀번호', child: AppInput(controller: _pw, obscure: true, onSubmitted: (_) => _submit())),
          if (_error.isNotEmpty) T.small(_error, color: C.bad),
          Btn(_busy ? '로그인 중…' : '로그인', primary: true, block: true, onPressed: _busy ? null : _submit),
          Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupPage())),
              child: Text('계정이 없나요? 회원가입', style: tx(size: 14, color: C.skyDeep).copyWith(decoration: TextDecoration.underline)),
            ),
          ),
          if (api.isMock)
            VStack(gap: 6, children: [
              const T.label('시연 계정 (목업 모드 · 비밀번호 $demoPassword)'),
              for (final a in demoAccounts)
                Btn('${a['label']} 계정 · ${a['email']}', small: true, block: true, onPressed: _busy ? null : () => _submit(a['email'], demoPassword)),
            ]),
        ],
      );
}

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  String _role = 'USER';
  final _name = TextEditingController(), _email = TextEditingController(), _pw = TextEditingController();
  final _store = TextEditingController(), _biz = TextEditingController();
  String _error = '';
  bool _busy = false;
  api.AppUser? _done;

  @override
  void dispose() {
    for (final c in [_name, _email, _pw, _store, _biz]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final merchant = _role == 'MERCHANT';
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || (merchant && (_store.text.trim().isEmpty || _biz.text.trim().isEmpty))) {
      setState(() => _error = '빈 칸을 모두 채워 주세요.');
      return;
    }
    if (_pw.text.length < 8) {
      setState(() => _error = '비밀번호는 8자 이상이어야 해요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final u = await api.signup({
        'email': _email.text.trim(),
        'password': _pw.text,
        'name': _name.text.trim(),
        'role': _role,
        if (merchant) 'storeName': _store.text.trim(),
        if (merchant) 'businessNo': _biz.text.replaceAll(RegExp(r'\D'), ''),
      });
      setState(() => _done = u);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final merchant = _role == 'MERCHANT';
    if (_done != null) {
      return _AuthFrame(title: '회원가입', children: [
        T(_done!.status == 'PENDING' ? '가입 신청을 받았어요. 관리자가 사업자 정보를 확인하면 로그인할 수 있어요.' : '가입이 끝났어요. 로그인해 주세요.'),
        Btn('로그인으로', primary: true, block: true, onPressed: () => Navigator.of(context).pop()),
      ]);
    }
    return _AuthFrame(title: '회원가입', children: [
      Center(child: Seg<String>(options: const {'USER': '관광객', 'MERCHANT': '상권 주인'}, value: _role, onChanged: (v) => setState(() => _role = v))),
      Field('이름', child: AppInput(controller: _name)),
      Field('이메일', child: AppInput(controller: _email, keyboard: TextInputType.emailAddress)),
      Field('비밀번호 (8자 이상)', child: AppInput(controller: _pw, obscure: true)),
      if (merchant) ...[
        Field('상호', child: AppInput(controller: _store)),
        Field('사업자등록번호', child: AppInput(controller: _biz, hint: '000-00-00000', keyboard: TextInputType.number)),
        const Note('상권 주인 계정은 관리자 승인 후 사용할 수 있어요.'),
      ],
      if (_error.isNotEmpty) T.small(_error, color: C.bad),
      Btn(_busy ? '보내는 중…' : '가입하기', primary: true, block: true, onPressed: _busy ? null : _submit),
      Center(child: Btn('로그인으로 돌아가기', ghost: true, small: true, onPressed: () => Navigator.of(context).pop())),
    ]);
  }
}
