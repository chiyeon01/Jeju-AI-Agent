# 제주잇다 (Jeju-ITDA)

> 관광객의 취향과 제주 상권을 데이터로 잇는 AI Agent 서비스
> 제주 AI·빅데이터 활용 AI Agent 개발 챌린지 최종 결과물

관광객은 **성향 테스트 → 출발 지역 → AI 코스(실측 혼잡도·관광지 방문객·실시간 날씨 반영) → 방문 후 평가**,
상권 주인은 **관광객 평가를 근거로 한 리뷰 분석·개선 제안 Agent**,
제주시 Main PC 는 **지역 점수·실시간 이벤트·원천 데이터 관리 콘솔**을 씁니다.
관광객 평가가 다시 장소 평점·상권 지표·지역 점수로 돌아가는 순환 구조입니다.

## 제출 문서

| 문서 | 내용 |
|---|---|
| [01 실행환경 및 사용자 매뉴얼](docs/01_실행환경_및_사용자_매뉴얼.md) | 설치·실행 절차, 의존성, 환경변수 예시, 사용자 매뉴얼, 오류·제약사항 |
| [02 데이터 활용 명세](docs/02_데이터_활용_명세.md) | 제주데이터허브 API 11종·파일 10종 사용 내역, 출처·이용조건, 전처리·분석 흐름, 외부 데이터·오픈소스 |
| [03 결과 설명자료](docs/03_결과_설명자료.md) | 문제 정의, Agent 구조, 주요 기능, 실행 결과, 검증·한계, 센터 활용 방안 |
| [04 소스코드 안내](docs/04_소스코드_안내.md) | Agent 실행 코드, Prompt, Tool/API 연동·데이터 처리 코드, 사용 모델·라이브러리 |
| [실행 결과 원문](docs/실행결과/) | 실제 데이터허브·GPT·날씨로 실행한 23단계 응답 (JSON) |

## 빠른 시작

```bash
# 1) Agent 서버
cd backend
python -m venv .venv
.venv\Scripts\activate                 # macOS·Linux: source .venv/bin/activate
pip install -r requirements.txt
copy .env.example .env                  # 키 입력: OPENAI_API_KEY, JEJU_DATA_HUB_API_KEY 등
uvicorn app.main:app --port 8000        # http://localhost:8000/docs

# 2) 웹 (새 터미널)
cd frontend
npm install
copy .env.example .env                  # VITE_PROXY_TARGET=http://localhost:8000, VITE_KAKAO_MAP_KEY
npm run dev                             # http://localhost:5173
```

또는 서버 한 대에: `docker compose up -d --build` (자세한 내용은 매뉴얼 3-4).

시연 계정 (비밀번호 `jeju1234`): `user@jeju.kr` 관광객 · `owner@jeju.kr` 상권 주인 · `admin@jeju.kr` 관리자

## 구성

| 폴더 | 기술 | 역할 |
|---|---|---|
| `backend/` | Python · FastAPI · SQLite · OpenAI | Agent 서버, 제주데이터허브 연동 |
| `frontend/` | React 18 · Vite 5 · 카카오맵 | 웹 |
| `app/` | Flutter | Android·iOS 앱 |
| `기획/` | | 기획서, 구성도 |

키(.env), 데이터허브 원천 데이터(`data/`), DB(`backend/storage/`)는 저장소와 제출물에 포함하지 않습니다.
