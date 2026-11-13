import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // 백엔드(FastAPI) 연동 시 /api 요청을 프록시합니다.
    proxy: {
      '/api': { target: 'http://localhost:8000', changeOrigin: true },
    },
  },
});
