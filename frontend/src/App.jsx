import { Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { useEffect } from 'react';
import Shell from './components/Shell.jsx';
import Home from './pages/Home.jsx';
import TouristFlow from './pages/tourist/TouristFlow.jsx';
import OwnerDashboard from './pages/owner/OwnerDashboard.jsx';
import MainConsole from './pages/console/MainConsole.jsx';

export default function App() {
  const { pathname } = useLocation();
  useEffect(() => { window.scrollTo(0, 0); }, [pathname]);
  return (
    <Shell>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/tourist" element={<TouristFlow />} />
        <Route path="/owner" element={<OwnerDashboard />} />
        <Route path="/console" element={<MainConsole />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Shell>
  );
}
