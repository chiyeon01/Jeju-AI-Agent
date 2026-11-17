import { useState } from 'react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import { useAuth, HOME_BY_ROLE } from '../auth/AuthContext.jsx';

export default function Login() {
  const { user, login } = useAuth();
  const nav = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  if (user) return <Navigate to={HOME_BY_ROLE[user.role]} replace />;

  const submit = async (e) => {
    e.preventDefault();
    setBusy(true);
    setError('');
    try {
      const u = await login(email.trim(), password);
      nav(HOME_BY_ROLE[u.role], { replace: true });
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <main className="auth">
      <div className="card">
        <div className="title">
          <h1>제주잇다</h1>
          <p className="small muted">여행자와 동네 가게를 잇는 제주 AI 길잡이</p>
        </div>
        <form className="stack" onSubmit={submit}>
          <label className="field"><span>이메일</span>
            <input className="input" type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} required />
          </label>
          <label className="field"><span>비밀번호</span>
            <input className="input" type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} required />
          </label>
          {error && <p className="error" role="alert">{error}</p>}
          <button className="btn primary block" type="submit" disabled={busy}>{busy ? '로그인 중…' : '로그인'}</button>
        </form>
        <p className="small muted" style={{ textAlign: 'center', marginTop: 14 }}>
          계정이 없나요? <Link to="/signup">회원가입</Link>
        </p>
      </div>
    </main>
  );
}
