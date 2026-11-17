import { useCallback, useState } from 'react';
import { useBackHandler } from '../../components/BackButton.jsx';
import PersonalityTest from './PersonalityTest.jsx';
import LocationStep from './LocationStep.jsx';
import CourseStep from './CourseStep.jsx';
import ReviewStep from './ReviewStep.jsx';

export default function TouristFlow() {
  const [step, setStep] = useState(0);
  const [profile, setProfile] = useState(null);
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
      {step === 0 && <PersonalityTest onDone={(p) => { setProfile(p); go(1); }} />}
      {step === 1 && <LocationStep profile={profile} onBack={() => go(0)} onDone={(o) => { setOrigin(o); go(2); }} />}
      {step === 2 && <CourseStep profile={profile} origin={origin} onBack={() => go(1)} onDone={(c) => { setCourse(c); go(3); }} />}
      {step === 3 && <ReviewStep course={course} profile={profile} onRestart={() => { setProfile(null); setOrigin(null); setCourse(null); go(0); }} />}
    </main>
  );
}
