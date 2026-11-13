import { Link } from 'react-router-dom';
import JejuMap from '../components/JejuMap.jsx';
import { POPULAR_COURSES, REGION_HEALTH } from '../mock/console.js';

export default function Home() {
  return (
    <main className="page">
      <section className="hero">
        <div>
          <p className="eyebrow">제주 AI·빅데이터 활용 AI Agent</p>
          <h1 style={{ marginTop: 8 }}>관광객의 취향과<br />제주 상권을 <em>데이터로 잇다</em></h1>
          <p className="lead">
            관광객은 성향에 맞는 코스를 받고, 사장님은 객관적인 상권 건강 지표를 받습니다.
            관광객이 남긴 평가는 다시 지표와 추천으로 돌아와 제주시 Main PC에 쌓입니다.
          </p>
          <div className="row" style={{ marginTop: 24 }}>
            <Link to="/tourist" className="btn primary">성향 테스트 시작</Link>
            <Link to="/owner" className="btn">사장님 대시보드 보기</Link>
          </div>
        </div>
        <JejuMap health={REGION_HEALTH} flows={POPULAR_COURSES} />
      </section>

      <section className="role-grid" aria-label="사용자별 화면">
        <Link to="/tourist" className="role">
          <span className="eyebrow">관광객 · 웹/앱</span>
          <span className="who">여행 코스 받기</span>
          <ol>
            <li>12문항 성향 테스트로 16유형 중 내 유형 찾기</li>
            <li>지도에서 위치 고르기 (또는 현재 위치)</li>
            <li>AI가 짠 3~5곳 코스와 데이터 근거 확인</li>
            <li>방문 후 별점과 한 줄 평가</li>
          </ol>
        </Link>
        <Link to="/owner" className="role">
          <span className="eyebrow">상권 주인 · 웹/앱</span>
          <span className="who">상권 건강 지표</span>
          <ol>
            <li>빅데이터 + 관광객 평가로 만든 0~100 종합 점수</li>
            <li>7개 세부 지표와 주변 상권 대비 백분위</li>
            <li>주간 AI 개선 제안과 질문형 대화</li>
          </ol>
        </Link>
        <Link to="/console" className="role console">
          <span className="eyebrow" style={{ color: 'inherit', opacity: .7 }}>제주시 · Main PC</span>
          <span className="who">통합 데이터 관리 콘솔</span>
          <ol>
            <li>실시간 방문·평가 이벤트와 지역별 상권 점수</li>
            <li>원천 데이터 적재 이력과 품질 점검</li>
            <li>접근 권한·마스킹 규칙·백업 관리</li>
          </ol>
        </Link>
      </section>

      <section className="loop" aria-label="데이터 순환 구조">
        <div><b>평가</b><span className="small muted">방문 인증된 관광객이 별점과 한 줄 평가를 남깁니다.</span></div>
        <div><b>상권 지표</b><span className="small muted">고객 만족·성향 적합도 지표가 바로 다시 계산됩니다.</span></div>
        <div><b>추천 품질</b><span className="small muted">성향-장소 선호 행렬이 갱신돼 다음 코스에 반영됩니다.</span></div>
        <div><b>Main PC</b><span className="small muted">새로 만들어진 데이터가 제주시 통합 저장소에 쌓입니다.</span></div>
      </section>
    </main>
  );
}
