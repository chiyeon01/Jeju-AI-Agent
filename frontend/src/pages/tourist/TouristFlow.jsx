import { useCallback, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../../auth/AuthContext.jsx';
import { recordProfile, recordCourse, recordReviews } from '../../api/history.js';
import { useBackHandler } from '../../components/BackButton.jsx';
import PersonalityTest from './PersonalityTest.jsx';
import TripStep from './TripStep.jsx';
import LocationStep from './LocationStep.jsx';
import CourseStep from './CourseStep.jsx';
import ReviewStep from './ReviewStep.jsx';

const STEP_NAMES = ['성향 테스트', '여행 정보', '출발 지역', '추천 코스', '방문 후 평가'];

export default function TouristFlow() {
  const { user } = useAuth();
  const nav = useNavigate();
  const state = useLocation().state ?? {};
  // 홈에서 지난 유형을 고르면 성향 테스트를 건너뛰고 여행 정보(시간·이동 수단)부터
  // 홈에서 "평가하기"를 누르면 지난 코스를 바로 평가합니다
  const saved = state.profile ?? null;
  const reviewOnly = state.review ?? null;
  const STEPS = STEP_NAMES.length;
  const [step, setStep] = useState(reviewOnly ? 4 : saved ? 1 : 0);
  const [profile, setProfile] = useState(saved);
  const [origin, setOrigin] = useState(null);
  const [course, setCourse] = useState(reviewOnly);
  const go = (n) => { setStep(n); window.scrollTo({ top: 0, behavior: 'smooth' }); };
  // 왼쪽 위 뒤로가기: 2단계 이상이면 이전 단계로
  const back = useCallback(() => { setStep((s) => Math.max(0, s - 1)); window.scrollTo({ top: 0, behavior: 'smooth' }); }, []);
  useBackHandler(step > 0 && !reviewOnly ? back : null);

  return (
    <main className={`page ${step === 3 ? '' : 'narrow'}`}>
      {!reviewOnly && (
        <div className="stepper" aria-label={`${step + 1} / ${STEPS} 단계 · ${STEP_NAMES[step]}`}>
          <span className="now">{STEP_NAMES[step]}</span>
          <span className="track" aria-hidden="true"><span style={{ width: `${((step + 1) / STEPS) * 100}%` }} /></span>
          <span className="count">{step + 1} / {STEPS}</span>
        </div>
      )}
      {step === 0 && <PersonalityTest onDone={(p) => { setProfile(p); recordProfile(user.id, p); go(1); }} />}
      {step === 1 && <TripStep profile={profile} onBack={() => go(0)} onDone={(p) => { setProfile(p); go(2); }} />}
      {step === 2 && <LocationStep profile={profile} onBack={() => go(1)} onDone={(o) => { setOrigin(o); go(3); }} />}
      {step === 3 && <CourseStep profile={profile} origin={origin} onBack={() => go(2)} onDone={(c, live) => { setCourse(c); recordCourse(user.id, { course: c, origin, profile, live }); go(4); }}
        onSave={(c, live) => { recordCourse(user.id, { course: c, origin, profile, live }); nav('/tourist'); }} />}
      {step === 4 && <ReviewStep course={course} profile={reviewOnly ? null : profile} onSent={(items) => recordReviews(user.id, items)} onRestart={() => nav('/tourist')} />}
    </main>
  );
}
