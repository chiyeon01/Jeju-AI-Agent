import { useEffect, useRef, useState } from 'react';
import JejuMap from '../../components/JejuMap.jsx';
import TypeCard from './TypeCard.jsx';
import { Stars } from '../../components/Charts.jsx';
import { KIND_LABEL, WEATHER } from '../../mock/tourist.js';
import { planCourse, chatCourse } from '../../api/client.js';

const SUGGEST = ['저녁은 해산물로 바꿔줘', '1곳 줄여줘', '실내로 바꿔줘'];

export default function CourseStep({ profile, origin, onDone, onBack }) {
  const [opts, setOpts] = useState({ weather: 'clear', seafood: false, removeCount: 0 });
  const [course, setCourse] = useState(null);
  const [loading, setLoading] = useState(true);
  const [msgs, setMsgs] = useState([{ from: 'ai', text: `${profile.name}님을 위해 ${origin.name}에서 출발하는 코스를 짰어요. 바꾸고 싶은 점을 말해 주세요.` }]);
  const [text, setText] = useState('');
  const chatRef = useRef(null);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    planCourse({ profile, origin, startTime: profile.startTime, ...opts }).then((c) => {
      if (alive) { setCourse(c); setLoading(false); }
    });
    return () => { alive = false; };
  }, [opts, profile, origin]);

  useEffect(() => { chatRef.current?.scrollTo({ top: 99999, behavior: 'smooth' }); }, [msgs]);

  const send = async (m) => {
    const message = (m ?? text).trim();
    if (!message) return;
    setText('');
    setMsgs((x) => [...x, { from: 'me', text: message }]);
    const res = await chatCourse(message);
    setMsgs((x) => [...x, { from: 'ai', text: res.reply }]);
    if (res.patch) setOpts((o) => ({ ...o, ...res.patch, removeCount: (o.removeCount || 0) + (res.patch.removeCount || 0) }));
  };

  const w = WEATHER[opts.weather];

  return (
    <section className="grid" style={{ gridTemplateColumns: 'minmax(0, 1.25fr) minmax(0, 1fr)', alignItems: 'start' }} data-layout="course">
      <div className="stack">
        <div className="card-head" style={{ marginBottom: 0 }}>
          <div>
            <p className="eyebrow">AI 코스 플래너 · {origin.name} 출발</p>
            <h2>오늘의 {profile.companion} 코스</h2>
          </div>
          <div className="seg" role="group" aria-label="날씨 시뮬레이션">
            {Object.entries(WEATHER).map(([k, v]) => (
              <button key={k} className={opts.weather === k ? 'on' : ''} onClick={() => setOpts((o) => ({ ...o, weather: k }))}>{v.icon} {v.label}</button>
            ))}
          </div>
        </div>
        <p className={`pill ${opts.weather === 'rain' ? 'warn' : 'sea'}`} style={{ alignSelf: 'flex-start' }}>
          {w.icon} {w.label} {w.temp}°C · {w.note}
        </p>

        <div className="card" aria-busy={loading}>
          {loading || !course ? (
            <p className="muted">장소 후보를 점수화하고 이동 순서를 정하는 중…</p>
          ) : (
            <ol className="timeline">
              {course.stops.map((s, i) => (
                <li key={s.id} className="tl-item">
                  <div className="tl-time">{s.at}</div>
                  <div className="tl-rail"><b /></div>
                  <div className="tl-body">
                    {i > 0 && <div className="small muted">↓ {profile.transport === '렌터카' ? '차로' : '버스로'} 약 {s.move}분</div>}
                    <div className="row" style={{ gap: 8, marginTop: 2 }}>
                      <strong style={{ fontSize: '1.05rem' }}>{s.name}</strong>
                      <span className="pill">{KIND_LABEL[s.kind]}</span>
                      {s.indoor && <span className="pill sea">실내</span>}
                    </div>
                    <div className="row small muted" style={{ gap: 8 }}>
                      <Stars value={Math.round(s.rating)} /> <span className="num">{s.rating}</span> · 머무는 시간 {s.stay}분
                    </div>
                    <div className="stack" style={{ gap: 4, marginTop: 8 }}>
                      {s.reasons.map(([src, r]) => (
                        <div key={r} className="reason"><span className="src">{src}</span><span>{r}</span></div>
                      ))}
                    </div>
                  </div>
                </li>
              ))}
            </ol>
          )}
        </div>
        <p className="small muted">
          장소 점수 = 성향 적합도 + 데이터 인기도 + 평가 점수 − 혼잡도 − 이동시간 + 날씨 적합도. 이동 순서는 그리디 + 2-opt로 정합니다.
        </p>
      </div>

      <div className="stack">
        <TypeCard profile={profile} compact />
        <JejuMap origin={origin} stops={course?.stops} />
        <div className="card">
          <div className="card-head"><h3>대화로 코스 고치기</h3></div>
          <div className="chat" ref={chatRef} aria-live="polite">
            {msgs.map((m, i) => <div key={i} className={`bubble ${m.from}`}>{m.text}</div>)}
          </div>
          <div className="chips" style={{ marginTop: 10 }}>
            {SUGGEST.map((s) => <button key={s} type="button" className="chip" onClick={() => send(s)}>{s}</button>)}
          </div>
          <form className="chat-input" onSubmit={(e) => { e.preventDefault(); send(); }}>
            <input id="course-chat" className="input" value={text} onChange={(e) => setText(e.target.value)} placeholder="예: 카페는 바다 보이는 곳으로" />
            <button className="btn dark" type="submit">보내기</button>
          </form>
        </div>
        <div className="row" style={{ justifyContent: 'space-between' }}>
          <button className="btn ghost" onClick={onBack}>위치 다시 고르기</button>
          <button className="btn primary" disabled={!course} onClick={() => onDone(course)}>여행 끝, 평가하기</button>
        </div>
      </div>
    </section>
  );
}
