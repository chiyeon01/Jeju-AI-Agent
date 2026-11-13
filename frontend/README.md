# 제주잇다 프론트엔드 (껍데기)

관광객의 취향과 제주 상권을 데이터로 잇는 AI Agent 서비스의 React 프론트엔드입니다.
지금은 **목업 데이터로만 동작**하며, 백엔드(FastAPI) 연동 자리는 `src/api/client.js` 에 모아 두었습니다.

## 실행 (VS Code 터미널)

```bash
cd frontend
npm install
cp .env.example .env      # Windows PowerShell: copy .env.example .env
npm run dev               # http://localhost:5173
```

Node.js 18 이상이 필요합니다.

## 화면

| 경로 | 대상 | 내용 |
| --- | --- | --- |
| `/` | 공통 | 역할 선택, 데이터 순환 구조 |
| `/tourist` | 관광객 | 성향 테스트(12문항·4축·16유형) → 위치 선택(지도/현재 위치) → AI 코스(시간표·데이터 근거·날씨 전환·대화 수정) → 방문 후 평가(별점 + 한 줄) |
| `/owner` | 상권 주인 | 상권 건강 점수(0~100)·백분위, 7개 세부 지표, 주간 AI 개선 제안, 리뷰 인사이트, AI 질문, 개선 조치 등록 |
| `/console` | 제주시 Main PC | 통합 현황(실시간 이벤트·지역 점수 지도·인기 코스), 데이터 관리(적재 이력·실시간 생성 데이터·품질 점검), 접근·보안, 백업·복구 |

웹과 모바일 모두 반응형이며, 모바일에서는 하단 탭 메뉴로 바뀝니다. 밝은/어두운 화면을 지원합니다.

## 폴더 구조

```
src/
  api/client.js        백엔드 호출 함수 (VITE_USE_MOCK=true 면 목업 응답)
  mock/                관광객·상권·콘솔 목업 데이터
  components/          제주 지도(SVG), 차트(스파크라인·게이지·라인), 앱 셸
  pages/tourist/       관광객 4단계 화면
  pages/owner/         상권 주인 대시보드
  pages/console/       Main PC 관리 콘솔
```

## 백엔드 연동 시

1. `.env` 에서 `VITE_USE_MOCK=false` 로 바꿉니다.
2. FastAPI 가 `localhost:8000` 에서 아래 엔드포인트를 제공하면 됩니다 (vite 가 `/api` 를 프록시).
   - `POST /api/tourist/profile` · `POST /api/tourist/course` · `POST /api/tourist/course/chat` · `POST /api/tourist/reviews`
   - `POST /api/owner/ask` · `POST /api/owner/actions`
3. Claude API 키와 제주데이터허브 API 키는 **백엔드 .env** 에 둡니다. 프론트 `.env` 에 넣으면 브라우저에 노출됩니다.

## 참고

- 매장·지표·리뷰·이벤트 수치는 모두 시연용 가상 데이터입니다.
- 지도는 통계청 2013 읍면동 경계(southkorea-maps)를 SVG로 변환한 `src/mock/jejuGeo.js` 를 씁니다. 장소는 실제 위도·경도로 찍습니다. 타일 지도로 바꿀 때는 `VITE_MAP_JS_KEY` 를 사용하세요.
