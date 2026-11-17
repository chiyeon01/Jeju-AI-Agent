// 로그인 · 회원가입 (관광객 / 상권 주인). 관리자 계정은 백엔드에서 만듭니다.
import 'package:material_ui/material_ui.dart';

import '../api/client.dart' as api;
import '../main.dart';
import '../data/tourist_mock.dart' show places;
import '../theme.dart';
import '../widgets/back.dart';
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
            child: Stack(children: [
              Center(
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
              // 회원가입처럼 쌓인 화면이면 왼쪽 위에 뒤로가기
              if (Navigator.canPop(context)) Positioned(top: 8, left: 8, child: AppBackButton(onPressed: () => Navigator.maybePop(context))),
            ]),
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

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await widget.auth.login(_email.text.trim(), _pw.text);
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
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SignupPage(auth: widget.auth))),
              child: Text('계정이 없나요? 회원가입', style: tx(size: 14, color: C.skyDeep).copyWith(decoration: TextDecoration.underline)),
            ),
          ),
        ],
      );
}

/// 백엔드 /auth/signup 규칙과 같게 미리 확인합니다 (서버의 영어 검증 문구 대신 한국어로 안내)
String checkSignup({required String role, required String name, required String email, required String password, String store = '', String biz = ''}) {
  final merchant = role == 'MERCHANT';
  if (name.trim().isEmpty) return '이름을 입력해 주세요.';
  if (name.trim().length > 50) return '이름은 50자까지 쓸 수 있어요.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim())) return '이메일 형식이 올바르지 않아요.';
  if (password.length < 8) return '비밀번호는 8자 이상이어야 해요.';
  if (password.length > 128) return '비밀번호는 128자까지 쓸 수 있어요.';
  if (merchant && store.trim().isEmpty) return '상호를 입력해 주세요.';
  if (merchant && store.trim().length > 80) return '상호는 80자까지 쓸 수 있어요.';
  if (merchant && biz.replaceAll(RegExp(r'\D'), '').length != 10) return '사업자등록번호는 숫자 10자리예요.';
  return '';
}

class SignupPage extends StatefulWidget {
  const SignupPage({super.key, required this.auth});
  final AuthController auth;
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
  String? _placeId; // 관광객 평가를 받을 내 가게 (선택)

  @override
  void dispose() {
    for (final c in [_name, _email, _pw, _store, _biz]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final merchant = _role == 'MERCHANT';
    final problem = checkSignup(role: _role, name: _name.text, email: _email.text, password: _pw.text, store: _store.text, biz: _biz.text);
    if (problem.isNotEmpty) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final email = _email.text.trim().toLowerCase();
      final u = await api.signup({
        'email': email,
        'password': _pw.text,
        'name': _name.text.trim(),
        'role': _role,
        if (merchant) 'storeName': _store.text.trim(),
        if (merchant) 'businessNo': _biz.text.replaceAll(RegExp(r'\D'), ''),
        if (merchant && _placeId != null) 'placeId': _placeId,
      });
      // 관광객은 바로 쓸 수 있으니 가입한 정보로 로그인까지 이어서 합니다
      if (u.status == 'ACTIVE') {
        try {
          await widget.auth.login(email, _pw.text);
          if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
          return;
        } catch (_) {
          // 로그인만 실패하면 완료 화면에서 직접 로그인하게 둡니다
        }
      }
      if (mounted) setState(() => _done = u);
    } catch (e) {
      if (mounted) setState(() => _error = e is api.ApiError && e.code == 'EMAIL_TAKEN' ? '이미 가입된 이메일이에요. 로그인해 주세요.' : '$e');
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
        Field('관광객 평가를 받을 내 가게 (선택)',
            child: DropdownButton<String?>(
              isExpanded: true,
              value: _placeId,
              items: [
                const DropdownMenuItem(value: null, child: T.small('나중에 연결할게요')),
                for (final p in places.where((p) => api.storeKinds.containsKey(p.kind))) DropdownMenuItem(value: p.id, child: T.small(p.name)),
              ],
              onChanged: (v) => setState(() => _placeId = v),
            )),
        const Note('상권 주인 계정은 관리자 승인 후 사용할 수 있어요.'),
      ],
      if (_error.isNotEmpty) T.small(_error, color: C.bad),
      Btn(_busy ? '보내는 중…' : '가입하기', primary: true, block: true, onPressed: _busy ? null : _submit),
      Center(child: Btn('로그인으로 돌아가기', ghost: true, small: true, onPressed: () => Navigator.of(context).pop())),
    ]);
  }
}
