import { useCallback, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../../auth/AuthContext.jsx';
import { recordProfile, recordCourse, recordReviews } from '../../api/history.js';
import { useBackHandler } from '../../components/BackButton.jsx';
import PersonalityTest from './PersonalityTest.jsx';
import LocationStep from './LocationStep.jsx';
import CourseStep from './CourseStep.jsx';
import ReviewStep from './ReviewStep.jsx';

export default function TouristFlow() {
  const { user } = useAuth();
  const nav = useNavigate();
  // 홈에서 "지난 성향으로" 를 누르면 성향 테스트를 건너뛰고 출발 지역부터
  const saved = useLocation().state?.profile ?? null;
  const [step, setStep] = useState(saved ? 1 : 0);
  const [profile, setProfile] = useState(saved);
  const [origin, setOrigin] = useState(null);
  const [course, setCourse] = useState(null);
  const go = (n) => { setStep(n); window.scrollTo({ top: 0, behavior: 'smooth' }); };
  // 왼쪽 위 뒤로가기: 2단계 이상이면 이전 단계로
  const back = useCallback(() => { setStep((s) => Math.max(0, s - 1)); window.scrollTo({ top: 0, behavior: 'smooth' }); }, []);
  useBackHandler(step > 0 ? back : null);

  return (
    <main className={`page ${step === 2 ? '' : 'narrow'}`}>
      <div className="stepper" aria-label={`${step + 1} / 4 단계`}>
        {[0, 1, 2, 3].map((i) => <div key={i} className={i <= step ? 'on' : ''} />)}
      </div>
      {step === 0 && <PersonalityTest onDone={(p) => { setProfile(p); recordProfile(user.id, p); go(1); }} />}
      {step === 1 && <LocationStep profile={profile} onBack={() => go(0)} onDone={(o) => { setOrigin(o); go(2); }} />}
      {step === 2 && <CourseStep profile={profile} origin={origin} onBack={() => go(1)} onDone={(c, live) => { setCourse(c); recordCourse(user.id, { course: c, origin, profile, live }); go(3); }} />}
      {step === 3 && <ReviewStep course={course} profile={profile} onSent={(items) => recordReviews(user.id, items)} onRestart={() => nav('/tourist')} />}
    </main>
  );
}
