import { useState } from 'react';
import PersonalityTest from './PersonalityTest.jsx';
import LocationStep from './LocationStep.jsx';
import CourseStep from './CourseStep.jsx';
import ReviewStep from './ReviewStep.jsx';

const STEPS = ['성향 테스트', '위치 선택', 'AI 코스', '방문 평가'];

export default function TouristFlow() {
  const [step, setStep] = useState(0);
  const [profile, setProfile] = useState(null);
  const [origin, setOrigin] = useState(null);
  const [course, setCourse] = useState(null);

  const go = (n) => { setStep(n); window.scrollTo({ top: 0, behavior: 'smooth' }); };

  return (
    <main className={`page ${step === 0 || step === 3 ? 'narrow' : ''}`}>
      <div className="stepper" aria-label="진행 단계">
        {STEPS.map((s, i) => (
          <div key={s} className={i <= step ? 'on' : ''} aria-current={i === step ? 'step' : undefined}>
            <div className="track" />
            <div className="label">{i + 1}. {s}</div>
          </div>
        ))}
      </div>

      {step === 0 && <PersonalityTest onDone={(p) => { setProfile(p); go(1); }} />}
      {step === 1 && <LocationStep profile={profile} onBack={() => go(0)} onDone={(o) => { setOrigin(o); go(2); }} />}
      {step === 2 && <CourseStep profile={profile} origin={origin} onBack={() => go(1)} onDone={(c) => { setCourse(c); go(3); }} />}
      {step === 3 && <ReviewStep profile={profile} course={course} onRestart={() => { setProfile(null); setOrigin(null); setCourse(null); go(0); }} />}
    </main>
  );
}
