import { Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { useEffect } from 'react';
import { useAuth, RequireRole, HOME_BY_ROLE } from './auth/AuthContext.jsx';
import Shell from './components/Shell.jsx';
import Login from './pages/Login.jsx';
import Signup from './pages/Signup.jsx';
import TouristFlow from './pages/tourist/TouristFlow.jsx';
import OwnerDashboard from './pages/owner/OwnerDashboard.jsx';
import MainConsole from './pages/console/MainConsole.jsx';

function Start() {
  const { user } = useAuth();
  return <Navigate to={user ? HOME_BY_ROLE[user.role] : '/login'} replace />;
}

export default function App() {
  const { pathname } = useLocation();
  useEffect(() => { window.scrollTo(0, 0); }, [pathname]);
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/signup" element={<Signup />} />
      <Route element={<RequireRole><Shell /></RequireRole>}>
        <Route path="/tourist" element={<RequireRole roles={['USER', 'ADMIN']}><TouristFlow /></RequireRole>} />
        <Route path="/owner" element={<RequireRole roles={['MERCHANT', 'ADMIN']}><OwnerDashboard /></RequireRole>} />
        <Route path="/console" element={<RequireRole roles={['ADMIN']}><MainConsole /></RequireRole>} />
      </Route>
      <Route path="*" element={<Start />} />
    </Routes>
  );
}
