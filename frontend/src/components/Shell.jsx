import { NavLink, Link } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { isMock } from '../api/client.js';

function useTheme() {
  const [theme, setTheme] = useState(() => {
    try { return localStorage.getItem('itda-theme') || ''; } catch { return ''; }
  });
  useEffect(() => {
    if (theme) document.documentElement.setAttribute('data-theme', theme);
    else document.documentElement.removeAttribute('data-theme');
    try { theme ? localStorage.setItem('itda-theme', theme) : localStorage.removeItem('itda-theme'); } catch { /* 저장 불가 환경 */ }
  }, [theme]);
  const isDark = theme ? theme === 'dark' : window.matchMedia?.('(prefers-color-scheme: dark)').matches;
  return [isDark, () => setTheme(isDark ? 'light' : 'dark')];
}

const NAV = [
  { to: '/tourist', label: '여행 코스', icon: '🧭' },
  { to: '/owner', label: '사장님', icon: '🏪' },
  { to: '/console', label: 'Main PC', icon: '🖥️' },
];

export default function Shell({ children }) {
  const [isDark, toggle] = useTheme();
  return (
    <>
      <header className="topbar">
        <div className="topbar-inner">
          <Link to="/" className="brand">
            <svg width="26" height="26" viewBox="0 0 64 64" aria-hidden="true"><path d="M8 42c7-15 17-21 24-21s17 6 24 21" fill="none" stroke="var(--accent)" strokeWidth="7" strokeLinecap="round" /><circle cx="32" cy="22" r="7" fill="var(--sea)" /></svg>
            제주잇다 {isMock && <small>목업 모드</small>}
          </Link>
          <nav className="topnav" aria-label="주 메뉴">
            {NAV.map((n) => <NavLink key={n.to} to={n.to}>{n.label}</NavLink>)}
          </nav>
          <button className="icon-btn" onClick={toggle} aria-label={isDark ? '밝은 화면으로' : '어두운 화면으로'}>
            {isDark ? '☀' : '☾'}
          </button>
        </div>
      </header>
      {children}
      <nav className="bottomnav" aria-label="하단 메뉴">
        <NavLink to="/" end><span aria-hidden="true">🏠</span>홈</NavLink>
        {NAV.map((n) => <NavLink key={n.to} to={n.to}><span aria-hidden="true">{n.icon}</span>{n.label}</NavLink>)}
      </nav>
    </>
  );
}
