import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { signup } from '../api/client.js';
import { useAuth, HOME_BY_ROLE } from '../auth/AuthContext.jsx';
import BackButton from '../components/BackButton.jsx';

// 백엔드 /auth/signup 규칙과 같게 미리 확인해, 서버의 영어 검증 문구 대신 한국어로 알려 줍니다
const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
export function checkSignup(f) {
  const merchant = f.role === 'MERCHANT';
  if (!f.name.trim()) return '이름을 입력해 주세요.';
  if (f.name.trim().length > 50) return '이름은 50자까지 쓸 수 있어요.';
  if (!EMAIL.test(f.email.trim())) return '이메일 형식이 올바르지 않아요.';
  if (f.password.length < 8) return '비밀번호는 8자 이상이어야 해요.';
  if (f.password.length > 128) return '비밀번호는 128자까지 쓸 수 있어요.';
  if (merchant && !f.storeName.trim()) return '상호를 입력해 주세요.';
  if (merchant && f.storeName.trim().length > 80) return '상호는 80자까지 쓸 수 있어요.';
  if (merchant && f.businessNo.replace(/\D/g, '').length !== 10) return '사업자등록번호는 숫자 10자리예요.';
  return '';
}

// 관리자 계정은 화면에서 만들 수 없습니다. 관리자가 콘솔에서 직접 만듭니다.
export default function Signup() {
  const [form, setForm] = useState({ role: 'USER', email: '', password: '', name: '', storeName: '', businessNo: '' });
  const [error, setError] = useState('');
  const [done, setDone] = useState(null);
  const [busy, setBusy] = useState(false);
  const { login } = useAuth();
  const nav = useNavigate();
  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });
  const merchant = form.role === 'MERCHANT';

  const submit = async (e) => {
    e.preventDefault();
    const problem = checkSignup(form);
    if (problem) { setError(problem); return; }
    setBusy(true);
    setError('');
    try {
      const body = { email: form.email.trim().toLowerCase(), password: form.password, name: form.name.trim(), role: form.role };
      if (merchant) Object.assign(body, { storeName: form.storeName.trim(), businessNo: form.businessNo.replace(/\D/g, '') });
      const user = await signup(body);
      // 관광객은 바로 쓸 수 있으니 가입한 정보로 로그인까지 이어서 합니다
      if (user.status === 'ACTIVE') {
        try {
          const u = await login(body.email, body.password);
          nav(HOME_BY_ROLE[u.role], { replace: true });
          return;
        } catch { /* 로그인만 실패하면 완료 화면에서 직접 로그인하게 둡니다 */ }
      }
      setDone(user);
    } catch (err) {
      setError(err.code === 'EMAIL_TAKEN' ? '이미 가입된 이메일이에요. 로그인해 주세요.' : err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <main className="auth">
      <div className="auth-back"><BackButton fallback="/login" /></div>
      <div className="card">
        <div className="title"><h1>회원가입</h1></div>
        {done ? (
          <div className="stack">
            <p>{done.status === 'PENDING'
              ? '가입 신청을 받았어요. 관리자가 사업자 정보를 확인하면 로그인할 수 있어요.'
              : '가입이 끝났어요. 로그인해 주세요.'}</p>
            <Link className="btn primary block" to="/login">로그인으로</Link>
          </div>
        ) : (
          <form className="stack" onSubmit={submit}>
            <div className="seg" role="group" aria-label="계정 종류" style={{ alignSelf: 'center' }}>
              <button type="button" className={!merchant ? 'on' : ''} onClick={() => setForm({ ...form, role: 'USER' })}>관광객</button>
              <button type="button" className={merchant ? 'on' : ''} onClick={() => setForm({ ...form, role: 'MERCHANT' })}>상권 주인</button>
            </div>
            <label className="field"><span>이름</span><input className="input" value={form.name} onChange={set('name')} required /></label>
            <label className="field"><span>이메일</span><input className="input" type="email" value={form.email} onChange={set('email')} required /></label>
            <label className="field"><span>비밀번호 (8자 이상)</span><input className="input" type="password" autoComplete="new-password" value={form.password} onChange={set('password')} required /></label>
            {merchant && (
              <>
                <label className="field"><span>상호</span><input className="input" value={form.storeName} onChange={set('storeName')} required /></label>
                <label className="field"><span>사업자등록번호</span><input className="input" inputMode="numeric" placeholder="000-00-00000" value={form.businessNo} onChange={set('businessNo')} required /></label>
                <p className="note">상권 주인 계정은 관리자 승인 후 사용할 수 있어요.</p>
              </>
            )}
            {error && <p className="error" role="alert">{error}</p>}
            <button className="btn primary block" type="submit" disabled={busy}>{busy ? '보내는 중…' : '가입하기'}</button>
            <p className="small muted" style={{ textAlign: 'center' }}><Link to="/login">로그인으로 돌아가기</Link></p>
          </form>
        )}
      </div>
    </main>
  );
}
