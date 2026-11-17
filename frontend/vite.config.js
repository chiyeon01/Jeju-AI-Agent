import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig(({ mode }) => {
  // 개발 서버가 /api, /ws 요청을 넘길 백엔드. 배포 서버로 붙을 때는 .env 에
  // VITE_PROXY_TARGET=https://jejuai.duckdns.org 를 넣습니다 (브라우저 CORS 설정 없이 바로 붙음).
  const env = loadEnv(mode, process.cwd(), '');
  const target = env.VITE_PROXY_TARGET || 'http://localhost:8000';
  return {
    plugins: [react()],
    server: {
      port: 5173,
      proxy: {
        '/api': { target, changeOrigin: true, secure: true },
        '/ws': { target, changeOrigin: true, secure: true, ws: true },
        // 기상청(공공데이터포털) API 는 브라우저 CORS 를 허용하지 않아 개발 서버가 대신 부릅니다
        '/kma': { target: 'https://apis.data.go.kr', changeOrigin: true, secure: true, rewrite: (p) => p.replace(/^\/kma/, '') },
      },
    },
  };
});
