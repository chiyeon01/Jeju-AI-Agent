import { useEffect, useRef, useState } from 'react';
import KakaoMap from '../../components/KakaoMap.jsx';
import { KIND_LABEL, WEATHER } from '../../mock/tourist.js';
import { planCourse, chatCourse } from '../../api/client.js';

const SUGGEST = ['저녁은 해산물로 바꿔줘', '1곳 줄여줘', '실내로 바꿔줘'];

export default function CourseStep({ profile, origin, onDone, onBack }) {
  const [opts, setOpts] = useState({ weather: 'clear', seafood: false, removeCount: 0 });
  const [course, setCourse] = useState(null);
  const [msgs, setMsgs] = useState([{ from: 'ai', text: `${origin.name}에서 출발하는 코스예요. 바꾸고 싶은 점을 말해 주세요.` }]);
  const [text, setText] = useState('');
  const chatRef = useRef(null);

  useEffect(() => {
    let alive = true;
    setCourse(null);
    planCourse({ profile, origin, startTime: profile.startTime, ...opts }).then((c) => alive && setCourse(c));
    return () => { alive = false; };
  }, [opts, profile, origin]);

  useEffect(() => { chatRef.current?.scrollTo({ top: 99999 }); }, [msgs]);

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
    <section className="grid g2" style={{ alignItems: 'start' }}>
      <div className="stack">
        <div className="head" style={{ marginBottom: 0 }}>
          <div>
            <span className="label">{origin.name} 출발 · {profile.name}</span>
            <h2>오늘의 추천 코스</h2>
          </div>
          <div className="seg" role="group" aria-label="날씨">
            {Object.entries(WEATHER).map(([k, v]) => (
              <button key={k} className={opts.weather === k ? 'on' : ''} onClick={() => setOpts((o) => ({ ...o, weather: k }))}>{v.label}</button>
            ))}
          </div>
        </div>
        <p className="note">{w.icon} {w.label} {w.temp}°C · {w.note}</p>
        <div className="card" aria-busy={!course}>
          {!course ? <p className="muted">코스를 만드는 중…</p> : course.stops.map((s, i) => (
            <div key={s.id} className="stop">
              <span className="t num">{s.at}</span>
              <div className="stack" style={{ gap: 4 }}>
                {i > 0 && <span className="small muted">이동 약 {s.move}분</span>}
                <div className="row" style={{ gap: 8 }}>
                  <strong>{s.name}</strong>
                  <span className="pill">{KIND_LABEL[s.kind]}</span>
                </div>
                {s.reasons.slice(0, 1).map(([src, r]) => <div key={r} className="reason"><b>{src}</b>{r}</div>)}
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="stack">
        <KakaoMap center={origin} level={9} path markers={(course?.stops ?? []).map((s) => ({ lat: s.lat, lon: s.lon, text: s.name }))} />
        <div className="card">
          <h3 style={{ marginBottom: 10 }}>대화로 코스 고치기</h3>
          <div className="chat" ref={chatRef} aria-live="polite">
            {msgs.map((m, i) => <div key={i} className={`bubble ${m.from}`}>{m.text}</div>)}
          </div>
          <div className="chips" style={{ marginTop: 10 }}>
            {SUGGEST.map((s) => <button key={s} type="button" className="chip" onClick={() => send(s)}>{s}</button>)}
          </div>
          <form className="chat-input" onSubmit={(e) => { e.preventDefault(); send(); }}>
            <input className="input" value={text} onChange={(e) => setText(e.target.value)} placeholder="예: 카페는 바다 보이는 곳으로" aria-label="코스 수정 요청" />
            <button className="btn primary" type="submit">보내기</button>
          </form>
        </div>
        <div className="row between">
          <button className="btn ghost" onClick={onBack}>위치 다시 고르기</button>
          <button className="btn primary" disabled={!course} onClick={() => onDone(course)}>여행 끝, 평가하기</button>
        </div>
      </div>
    </section>
  );
}
