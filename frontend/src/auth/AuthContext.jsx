// 로그인 상태와 역할(USER · MERCHANT · ADMIN)을 앱 전체에 나눠 줍니다.
import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import * as api from '../api/client.js';

const AuthContext = createContext(null);

/** 역할별 첫 화면 */
export const HOME_BY_ROLE = { USER: '/tourist', MERCHANT: '/owner', ADMIN: '/console' };

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => api.loadSession()?.user ?? null);

  useEffect(() => {
    // 토큰 갱신까지 실패하면 로그인 화면으로
    api.setUnauthorizedHandler(() => setUser(null));
  }, []);

  const value = useMemo(() => ({
    user,
    async login(email, password) {
      const u = await api.login(email, password);
      setUser(u);
      return u;
    },
    async logout() {
      await api.logout();
      setUser(null);
    },
  }), [user]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  return useContext(AuthContext);
}

/** 로그인과 역할을 확인하는 보호 경로. roles 에 없는 역할이면 자기 첫 화면으로 보냅니다. */
export function RequireRole({ roles, children }) {
  const { user } = useAuth();
  const loc = useLocation();
  if (!user) return <Navigate to="/login" replace state={{ from: loc.pathname }} />;
  if (roles && !roles.includes(user.role)) return <Navigate to={HOME_BY_ROLE[user.role] || '/login'} replace />;
  return children;
}
