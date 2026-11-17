import { useEffect } from 'react';
import { NavLink, Link, Outlet } from 'react-router-dom';
import { useAuth, HOME_BY_ROLE } from '../auth/AuthContext.jsx';
import { isMock } from '../api/client.js';
import { ROLE_LABEL, isTestAdmin } from '../mock/auth.js';
import BackButton, { BackProvider } from './BackButton.jsx';

// 역할마다 보이는 메뉴가 다릅니다. 관리자는 모든 화면을 볼 수 있습니다.
const NAV = [
  { to: '/tourist', label: '여행 코스', roles: ['USER', 'ADMIN'] },
  { to: '/owner', label: '내 가게', roles: ['MERCHANT', 'ADMIN'] },
  { to: '/console', label: '관리', roles: ['ADMIN'] },
];

export default function Shell() {
  const { user, logout } = useAuth();
  const items = NAV.filter((n) => n.roles.includes(user.role));
  // 테스트 관리자 계정으로 들어오면 글씨·카드·표를 더 크고 굵게 (styles.css 의 .ui-bold)
  const bold = isTestAdmin(user);
  useEffect(() => {
    document.documentElement.classList.toggle('ui-bold', bold);
    return () => document.documentElement.classList.remove('ui-bold');
  }, [bold]);
  return (
    <BackProvider>
      <header className="topbar">
        <div className="topbar-inner">
          <BackButton />
          <Link to={HOME_BY_ROLE[user.role]} className="brand"><span className="dot" aria-hidden="true" />제주잇다</Link>
          {items.length > 1 && (
            <nav className="topnav" aria-label="주 메뉴">
              {items.map((n) => <NavLink key={n.to} to={n.to}>{n.label}</NavLink>)}
            </nav>
          )}
          <div className="who">
            {isMock && <span className="pill">목업</span>}
            <Link to="/me" className="name-link" title="내 정보·설정">{user.name}<span className="role"> · {ROLE_LABEL[user.role]}</span></Link>
            <button className="btn sm" onClick={logout}>로그아웃</button>
          </div>
        </div>
      </header>
      <Outlet />
      {items.length > 1 && (
        <nav className="bottomnav" aria-label="하단 메뉴">
          {items.map((n) => <NavLink key={n.to} to={n.to}>{n.label}</NavLink>)}
        </nav>
      )}
    </BackProvider>
  );
}
