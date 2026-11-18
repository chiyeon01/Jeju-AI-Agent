// 여행 만들기 (성향 테스트 → 여행 정보 → 출발 지역 → 추천 코스 → 평가)
//
// 단계마다 브라우저 기록을 한 칸씩 쌓습니다 (location.state 에 단계와 입력값을 함께 저장).
//  - 왼쪽 위 뒤로가기·브라우저 뒤로가기·휴대폰 뒤로가기 버튼이 모두 "이전 단계"로 갑니다.
//  - 이전 단계로 돌아가도 고른 값이 그대로 남아 있습니다.
//  - 코스를 저장하거나 평가를 보내면 흐름에서 쌓은 기록을 걷어 내고 홈으로 돌아갑니다.
//    (끝난 화면으로 뒤로가기해 다시 들어가거나, 같은 평가를 두 번 보내는 일이 없게)
import { useEffect, useRef } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../../auth/AuthContext.jsx';
import { recordProfile, recordCourse, recordReviews } from '../../api/history.js';
import { setFlash } from '../../utils/flash.js';
import PersonalityTest from './PersonalityTest.jsx';
import TripStep from './TripStep.jsx';
import LocationStep from './LocationStep.jsx';
import CourseStep from './CourseStep.jsx';
import ReviewStep from './ReviewStep.jsx';

const STEP_NAMES = ['성향 테스트', '여행 정보', '출발 지역', '추천 코스', '방문 후 평가'];
const historyIdx = () => window.history.state?.idx ?? 0;
// 끝낸 흐름 (뒤로가기로 다시 들어오면 홈으로 돌려보냄). 이 탭에만 저장
const DONE_KEY = 'jeju-done-flows';
const doneFlows = () => { try { return JSON.parse(sessionStorage.getItem(DONE_KEY) || '[]'); } catch { return []; } };
const markDone = (id) => { try { sessionStorage.setItem(DONE_KEY, JSON.stringify([...doneFlows(), id].slice(-30))); } catch { /* 저장 불가 */ } };

export default function TouristFlow() {
  const { user } = useAuth();
  const nav = useNavigate();
  const { pathname, state } = useLocation();
  const st = state ?? {};
  // 흐름이 시작된 기록 칸 (여기서 한 칸 더 뒤가 흐름에 들어오기 전 화면)
  const startIdx = useRef(st.startIdx ?? historyIdx()).current;
  const flowId = useRef(st.flowId ?? `${Date.now()}`).current;
  const finished = doneFlows().includes(flowId);
  useEffect(() => { if (finished) nav('/tourist', { replace: true }); }, [finished, nav]);

  // 홈에서 지난 유형을 고르면 여행 정보부터, "평가하기"를 누르면 지난 코스 평가부터
  const reviewOnly = st.review ?? null;
  const profile = st.profile ?? null;
  const origin = st.origin ?? null;
  const course = st.course ?? reviewOnly;
  let step = st.step ?? (reviewOnly ? 4 : profile ? 1 : 0);
  // 새로고침 등으로 앞 단계 값이 없으면 그 단계부터 다시
  if (step >= 1 && !profile && !reviewOnly) step = 0;
  else if (step >= 3 && !origin && !reviewOnly) step = 2;
  else if (step === 4 && !course) step = 3;

  const go = (n, patch = {}) => {
    nav(pathname, { state: { ...st, ...patch, step: n, startIdx, flowId } });
    window.scrollTo({ top: 0 });
  };
  /** 흐름을 끝내고 홈으로: 흐름에서 쌓은 기록만큼 되돌아갑니다 */
  const finish = (message) => {
    if (message) setFlash(message);
    markDone(flowId);
    const depth = historyIdx() - startIdx + 1;
    if (startIdx > 0 && depth > 0) nav(-depth);
    else nav('/tourist', { replace: true });
  };
  /** 화면 안 "이전" 버튼: 쌓인 기록이 있으면 브라우저 뒤로가기와 같게 */
  const back = () => {
    if (historyIdx() > startIdx) nav(-1);
    else if (step > 0 && !reviewOnly) nav(pathname, { replace: true, state: { ...st, step: step - 1, startIdx, flowId } });
    else finish();
  };

  if (finished) return null;
  return (
    <main className={`page ${step === 3 ? '' : 'narrow'}`}>
      {!reviewOnly && (
        <div className="stepper" aria-label={`${step + 1} / ${STEP_NAMES.length} 단계 · ${STEP_NAMES[step]}`}>
          <span className="now">{STEP_NAMES[step]}</span>
          <span className="track" aria-hidden="true"><span style={{ width: `${((step + 1) / STEP_NAMES.length) * 100}%` }} /></span>
          <span className="count">{step + 1} / {STEP_NAMES.length}</span>
        </div>
      )}
      {step === 0 && <PersonalityTest onDone={(p) => { recordProfile(user.id, p); go(1, { profile: p }); }} />}
      {step === 1 && <TripStep profile={profile} onBack={() => go(0, { profile: null })} onDone={(p) => go(2, { profile: p })} />}
      {step === 2 && <LocationStep profile={profile} initial={origin} onBack={back} onDone={(o) => go(3, { origin: o, course: null })} />}
      {step === 3 && (
        <CourseStep
          key={origin?.id}
          profile={profile}
          origin={origin}
          initial={st.course ?? null}
          onBack={back}
          onDone={(c, live) => {
            // 평가에서 뒤로 오면 같은 코스가 보이도록 지금 칸에 코스를 남겨 둡니다
            nav(pathname, { replace: true, state: { ...st, step: 3, course: c, startIdx, flowId } });
            recordCourse(user.id, { course: c, origin, profile, live });
            go(4, { course: c });
          }}
          onSave={(c, live) => {
            recordCourse(user.id, { course: c, origin, profile, live });
            finish('코스를 저장했어요. 다녀온 뒤 평가를 남겨 주세요.');
          }}
        />
      )}
      {step === 4 && (
        <ReviewStep
          course={course}
          profile={reviewOnly ? null : profile}
          onSent={(items) => { recordReviews(user.id, items); finish(`${items.length}곳의 평가를 보냈어요. 고마워요!`); }}
          onRestart={() => finish()}
        />
      )}
    </main>
  );
}
