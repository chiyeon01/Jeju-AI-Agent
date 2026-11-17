import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App.jsx';
import { AuthProvider } from './auth/AuthContext.jsx';
import './styles.css';
import { applySettings } from './settings.js';

applySettings(); // 저장해 둔 화면 밝기

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <App />
        <div className="dimmer" aria-hidden="true" />
      </AuthProvider>
    </BrowserRouter>
  </React.StrictMode>,
);
