import { useState } from 'react';
import { Link } from 'react-router-dom';
import { signup } from '../api/client.js';

// 관리자 계정은 화면에서 만들 수 없습니다. 관리자가 콘솔에서 직접 만듭니다.
export default function Signup() {
  const [form, setForm] = useState({ role: 'USER', email: '', password: '', name: '', storeName: '', businessNo: '' });
  const [error, setError] = useState('');
  const [done, setDone] = useState(null);
  const [busy, setBusy] = useState(false);
  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });
  const merchant = form.role === 'MERCHANT';

  const submit = async (e) => {
    e.preventDefault();
    if (form.password.length < 8) { setError('비밀번호는 8자 이상이어야 해요.'); return; }
    setBusy(true);
    setError('');
    try {
      const body = { email: form.email, password: form.password, name: form.name, role: form.role };
      if (merchant) Object.assign(body, { storeName: form.storeName, businessNo: form.businessNo.replace(/\D/g, '') });
      setDone(await signup(body));
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <main className="auth">
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
