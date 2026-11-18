import { useEffect } from 'react';
import { NavLink, Link, Outlet, useLocation } from 'react-router-dom';
import { useAuth, HOME_BY_ROLE } from '../auth/AuthContext.jsx';
import { isMock } from '../api/client.js';
import { ROLE_LABEL, isTestAdmin } from '../mock/auth.js';
import BackButton, { BackProvider } from './BackButton.jsx';

const Icon = ({ d }) => (
  <svg width="20" height="20" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">{d}</svg>
);
const ICONS = {
  tourist: <Icon d={<><path d="M3 20c3-1 4.5-6 9-6s6 5 9 6" /><circle cx="12" cy="7" r="3" /></>} />,
  owner: <Icon d={<><path d="M4 10l1.5-5h13L20 10" /><path d="M4 10h16v1a3 3 0 0 1-5.3 2 3 3 0 0 1-5.4 0A3 3 0 0 1 4 11z" /><path d="M5 13.5V20h14v-6.5" /><path d="M10 20v-4h4v4" /></>} />,
  console: <Icon d={<><rect x="3" y="4" width="18" height="12" rx="2" /><path d="M8 20h8M12 16v4" /><path d="M7 12l3-3 2 2 4-4" /></>} />,
  me: <Icon d={<><circle cx="12" cy="8" r="4" /><path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6" /></>} />,
};

// 역할마다 보이는 메뉴가 다릅니다. 관리자는 모든 화면을 볼 수 있습니다.
const NAV = [
  { to: '/tourist', label: '여행 코스', icon: 'tourist', roles: ['USER', 'ADMIN'] },
  { to: '/owner', label: '내 가게', icon: 'owner', roles: ['MERCHANT', 'ADMIN'] },
  { to: '/console', label: '관리', icon: 'console', roles: ['ADMIN'] },
];

// 화면(경로)마다 색 테마: 관광객=바다, 사장님=감귤, 관리=현무암 (styles.css 의 data-theme)
const ROLE_THEME = { USER: 'tourist', MERCHANT: 'owner', ADMIN: 'admin' };
function themeFor(pathname, role) {
  if (pathname.startsWith('/owner')) return 'owner';
  if (pathname.startsWith('/console')) return 'admin';
  if (pathname.startsWith('/tourist')) return 'tourist';
  return ROLE_THEME[role] ?? 'tourist';
}

export default function Shell() {
  const { user, logout } = useAuth();
  const { pathname } = useLocation();
  const items = NAV.filter((n) => n.roles.includes(user.role));
  // 테스트 관리자 계정으로 들어오면 글씨·카드·표를 더 크고 굵게 (styles.css 의 .ui-bold)
  const bold = isTestAdmin(user);
  useEffect(() => {
    document.documentElement.classList.toggle('ui-bold', bold);
    return () => document.documentElement.classList.remove('ui-bold');
  }, [bold]);
  const theme = themeFor(pathname, user.role);
  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    return () => { delete document.documentElement.dataset.theme; };
  }, [theme]);
  const initial = (user.name || '?').trim().slice(0, 1);
  // 모바일 하단 메뉴: 메뉴 + 내 정보 (메뉴가 하나뿐인 역할도 내 정보로 바로 갈 수 있게)
  const bottom = [...items, { to: '/me', label: '내 정보', icon: 'me' }];
  return (
    <BackProvider>
      <header className="topbar">
        <div className="topbar-inner">
          <BackButton home={NAV.some((n) => n.to === pathname) || pathname === '/'} />
          <Link to={HOME_BY_ROLE[user.role]} className="brand"><span className="dot" aria-hidden="true" /><span>제주<span className="space">잇다</span></span></Link>
          {items.length > 1 && (
            <nav className="topnav" aria-label="주 메뉴">
              {items.map((n) => <NavLink key={n.to} to={n.to}>{ICONS[n.icon]}{n.label}</NavLink>)}
            </nav>
          )}
          <div className="who">
            {isMock && <span className="pill warn">목업</span>}
            <Link to="/me" className="name-link" title="내 정보·설정">
              <span className="avatar" aria-hidden="true">{initial}</span>
              <span className="name">{user.name}<span className="role"> · {ROLE_LABEL[user.role]}</span></span>
            </Link>
            <button className="btn sm ghost" onClick={logout}>로그아웃</button>
          </div>
        </div>
      </header>
      <Outlet />
      <nav className="bottomnav" aria-label="하단 메뉴">
        {bottom.map((n) => <NavLink key={n.to} to={n.to}>{ICONS[n.icon]}<span>{n.label}</span></NavLink>)}
      </nav>
    </BackProvider>
  );
}
