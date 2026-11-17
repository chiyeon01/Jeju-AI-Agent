# 제주잇다 웹(React) 배포 이미지 — 빌드 컨텍스트는 frontend/, 이 폴더는 additional_contexts "deploy"
# 1) node 로 vite build  2) nginx 가 정적 파일 + /api·/ws·/docs 를 백엔드로 중계
FROM node:20-alpine AS build
WORKDIR /src
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
ARG VITE_USE_MOCK=false
ARG VITE_API_BASE_URL=/api/v1
ARG VITE_EVENT_STREAM_URL=/ws/events
ARG VITE_KAKAO_MAP_KEY=
ARG VITE_KMA_SERVICE_KEY=
ARG VITE_KMA_BASE_URL=/kma
ARG VITE_GPT_RELAY=
ENV VITE_USE_MOCK=$VITE_USE_MOCK VITE_API_BASE_URL=$VITE_API_BASE_URL VITE_EVENT_STREAM_URL=$VITE_EVENT_STREAM_URL \
    VITE_KAKAO_MAP_KEY=$VITE_KAKAO_MAP_KEY VITE_KMA_SERVICE_KEY=$VITE_KMA_SERVICE_KEY \
    VITE_KMA_BASE_URL=$VITE_KMA_BASE_URL VITE_GPT_RELAY=$VITE_GPT_RELAY
RUN npm run build

FROM nginx:1.27-alpine
COPY --from=deploy nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/dist /usr/share/nginx/html
