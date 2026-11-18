import { useState } from 'react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import { useAuth, HOME_BY_ROLE } from '../auth/AuthContext.jsx';

const ROLES = [
  { icon: '🧳', name: '관광객', desc: '성향 테스트 → 나만의 하루 코스 → 다녀온 곳 평가' },
  { icon: '🍊', name: '사장님', desc: '관광객 별점·리뷰와 AI 분석으로 내 가게 관리' },
  { icon: '🗿', name: '관리자', desc: '지역 점수·데이터허브·계정을 한 화면에서' },
];

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
      <div className="auth-split">
        <section className="auth-hero">
          <div className="logo"><span className="dot" aria-hidden="true" />제주잇다</div>
          <div className="stack" style={{ gap: 10 }}>
            <h1>여행자와 동네 가게를<br />AI로 잇는 제주 길잡이</h1>
            <p>내 여행 성향과 실시간 날씨·혼잡도로 코스를 짜고, 다녀온 평가는 동네 가게의 내일을 바꿔요.</p>
          </div>
          <div className="role-cards">
            {ROLES.map((r) => (
              <div key={r.name} className="role-card">
                <span className="ico" aria-hidden="true">{r.icon}</span>
                <div><b>{r.name}</b><span>{r.desc}</span></div>
              </div>
            ))}
          </div>
        </section>
        <section className="auth-form">
          <div className="stack" style={{ gap: 4 }}>
            <h2>다시 만나 반가워요</h2>
            <p className="small muted">이메일로 로그인해 주세요. 계정 종류에 맞는 화면으로 바로 이동해요.</p>
          </div>
          <form className="stack" onSubmit={submit}>
            <label className="field"><span>이메일</span>
              <input className="input" type="email" autoComplete="username" placeholder="name@example.com" value={email} onChange={(e) => setEmail(e.target.value)} required />
            </label>
            <label className="field"><span>비밀번호</span>
              <input className="input" type="password" autoComplete="current-password" placeholder="비밀번호" value={password} onChange={(e) => setPassword(e.target.value)} required />
            </label>
            {error && <p className="error" role="alert">{error}</p>}
            <button className="btn primary block lg" type="submit" disabled={busy}>{busy ? '로그인 중…' : '로그인'}</button>
          </form>
          <div className="divider">처음이신가요?</div>
          <Link className="btn block" to="/signup">회원가입</Link>
        </section>
      </div>
    </main>
  );
}
