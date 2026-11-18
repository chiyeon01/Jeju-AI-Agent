import { useState } from 'react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import { useAuth, HOME_BY_ROLE } from '../auth/AuthContext.jsx';

// 서비스 순환 (기획서 구성도): 관광객 평가가 가게 지표와 다음 추천으로 돌아갑니다
const LOOP = [
  ['관광객', '성향 테스트로 나에게 맞는 하루 코스를 받아요'],
  ['방문·평가', '다녀온 곳에 별점과 한 줄 평을 남겨요'],
  ['사장님', '실제 평가로 만든 지표와 AI 개선 제안을 받아요'],
  ['다시 추천', '평가와 가게의 개선이 다음 여행자 추천에 반영돼요'],
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
      <section className="auth-intro">
        <div className="logo"><span className="dot" aria-hidden="true" />제주잇다</div>
        <div>
          <h1>여행자의 하루와<br />동네 가게를 잇다</h1>
          <p>제주 빅데이터와 실시간 날씨·혼잡도로 내게 맞는 코스를 짜고, 다녀온 평가는 가게의 내일을 바꿉니다.</p>
        </div>
        <ol className="loop">
          {LOOP.map(([k, v]) => <li key={k}><b>{k}</b><span>{v}</span></li>)}
        </ol>
      </section>
      <section className="auth-main">
        <div>
          <div>
            <h2>로그인</h2>
            <p className="sub">계정 종류에 맞는 화면으로 바로 이동해요.</p>
          </div>
          <form className="stack" onSubmit={submit}>
            <label className="field"><span>이메일</span>
              <input className="input" type="email" autoComplete="username" placeholder="name@example.com" value={email} onChange={(e) => setEmail(e.target.value)} required />
            </label>
            <label className="field"><span>비밀번호</span>
              <input className="input" type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} required />
            </label>
            {error && <p className="error" role="alert">{error}</p>}
            <button className="btn primary block lg" type="submit" disabled={busy}>{busy ? '로그인 중…' : '로그인'}</button>
          </form>
          <p className="auth-foot">처음이신가요? <Link to="/signup">회원가입</Link></p>
        </div>
      </section>
    </main>
  );
}
