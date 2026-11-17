import { NavLink, Link, Outlet } from 'react-router-dom';
import { useAuth, HOME_BY_ROLE } from '../auth/AuthContext.jsx';
import { isMock } from '../api/client.js';
import { ROLE_LABEL } from '../mock/auth.js';
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
            <span className="name">{user.name} · {ROLE_LABEL[user.role]}</span>
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
