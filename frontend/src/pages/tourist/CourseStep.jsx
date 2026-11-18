import { useEffect, useRef, useState } from 'react';
import KakaoMap from '../../components/KakaoMap.jsx';
import { planCourse, alternativeCourse, chatCourse, getHubData, naverPlaceUrl } from '../../api/client.js';
import PlaceLink, { PlacePhoto, PlaceMeta } from '../../components/PlaceLink.jsx';
import { getLiveWeather, weatherLine } from '../../api/weather.js';
import { planCourseAI, chatCourseAI } from '../../api/planner.js';
import { applyHub } from '../../api/hub.js';
import { addToCourse, keepAdded } from '../../api/courseEdit.js';
import { courseSummary, leaveAt, kakaoRouteUrl, duration } from '../../utils/format.js';

// 대화로 코스 고치기 예시 (백엔드 대화 Agent 가 아이 동반·분위기 좋은 카페·해산물로 알아듣습니다)
const SUGGEST = ['아기가 놀기 좋은 곳으로 수정해줘.', '분좋카를 원해.', '회를 먹고싶어.'];

// 실시간 날씨·허브 값은 5초까지만 기다리고, 늦으면 없이 코스를 먼저 짭니다
const withTimeout = (p, ms) => Promise.race([p, new Promise((r) => setTimeout(() => r(null), ms))]);

// 추천 이유 (기획서: 각 장소마다 데이터 근거와 함께). 소개 문장은 맨 아래 회색으로
const WHY_LABEL = { AI: '추천', D1: '소비', D2: '혼잡', D3: '인기', D4: '인기', D5: '상권', D6: '교통', D7: '날씨', D8: '리뷰' };
function Why({ reasons }) {
  const list = (reasons ?? []).filter((r) => r?.[1]);
  if (!list.length) return null;
  const data = list.filter(([src]) => src !== '소개').slice(0, 2);
  const intro = list.find(([src]) => src === '소개');
  return (
    <ul className="why">
      {data.map(([src, text]) => <li key={src + text}><b>{WHY_LABEL[src] ?? '데이터'}</b><span>{text}</span></li>)}
      {intro && <li className="intro">{intro[1]}</li>}
    </ul>
  );
}

export default function CourseStep({ profile, origin, onDone, onSave, onBack }) {
  const [opts, setOpts] = useState(null); // 날씨를 확인한 뒤 { weather, seafood, removeCount } 로 채웁니다
  const [course, setCourse] = useState(null);
  const [startTime, setStartTime] = useState(profile.startTime || '15:00');
  const [live, setLive] = useState(null);
  const [hub, setHub] = useState(null);
  const [liveTry, setLiveTry] = useState(0); // "날씨 다시 불러오기"
  const [msgs, setMsgs] = useState([{ from: 'ai', text: `${origin.name}에서 출발하는 코스를 짜고 있어요.` }]);
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const chatRef = useRef(null);
  const addedRef = useRef([]); // 대화로 추가한 장소 id (백엔드가 코스를 다시 짜도 유지)
  const seenRef = useRef(new Set()); // 지금까지 보여 준 장소 ("다른 코스 보기"에서 피함)
  useEffect(() => { course?.stops.forEach((s) => seenRef.current.add(s.id)); }, [course]);

  // 1) 출발지(현재 위치를 썼다면 그 좌표) 기준 실시간 날씨 + 제주데이터허브(혼잡도·관광지 방문객)
  //    비나 눈이면 실내 코스로 시작합니다. 날씨는 사용자가 고르지 않고 항상 실시간 값을 씁니다
  useEffect(() => {
    let alive = true;
    const p = origin.at ?? origin;
    Promise.all([
      withTimeout(getLiveWeather(p.lat, p.lon), 12000),
      withTimeout(getHubData(), 5000),
    ]).then(([w, h]) => {
      if (!alive) return;
      setLive(w);
      setHub(h);
      setOpts((o) => ({ seafood: false, removeCount: 0, ...o, weather: w?.code ?? o?.weather ?? 'clear' }));
    });
    return () => { alive = false; };
  }, [origin, liveTry]);

  // 2) 코스 만들기: GPT(성향 + 실시간 날씨 + 출발지) → 안 되면 기존 방식
  useEffect(() => {
    if (!opts) return undefined;
    let alive = true;
    setCourse(null);
    (async () => {
      const ai = await planCourseAI({ profile, origin, weather: opts.weather, live, hub, startTime });
      const rule = ai ? null : await planCourse({ profile, origin, startTime, ...opts });
      const c = ai ?? { ...rule, stops: applyHub(keepAdded(rule.stops, addedRef.current, startTime), hub) };
      if (!alive) return;
      setCourse(c);
      if (c.summary) {
        const m = { from: 'ai', text: `${c.summary} 바꾸고 싶은 점을 편하게 말해 주세요.` };
        setMsgs((x) => (x.length === 1 ? [m] : [...x, m]));
      }
      else setMsgs((x) => (x.length === 1 ? [{ from: 'ai', text: `${origin.name}에서 출발하는 코스예요. 바꾸고 싶은 점을 말해 주세요.` }] : x));
    })();
    return () => { alive = false; };
    // startTime 은 대화로 바뀔 때 코스와 함께 바뀌므로 다시 짜지 않습니다
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [opts, profile, origin]);

  useEffect(() => { chatRef.current?.scrollTo({ top: 99999 }); }, [msgs]);

  const send = async (m) => {
    const message = (m ?? text).trim();
    if (!message || busy || !course) return;
    setText('');
    const history = [...msgs, { from: 'me', text: message }];
    setMsgs(history);
    setBusy(true);
    try {
      const ai = await chatCourseAI({ message, history: msgs, course, profile, origin, weather: opts.weather, live, hub, startTime });
      if (ai) {
        setMsgs((x) => [...x, { from: 'ai', text: ai.reply }]);
        if (ai.course) { setCourse(ai.course); if (ai.startTime) setStartTime(ai.startTime); }
        return;
      }
      // 서버 Agent(GPT)에게 사용자 말을 그대로 보내고, 고친 코스를 받습니다
      const res = await chatCourse(message, { stopIds: course.stops.map((s) => s.id), history: msgs });
      if (res.course) {
        addedRef.current = [];
        setMsgs((x) => [...x, { from: 'ai', text: res.reply }]);
        setCourse({ ...course, ...res.course, summary: course.summary, stops: applyHub(res.course.stops, hub) });
        return;
      }
      if (res.patch) {
        setMsgs((x) => [...x, { from: 'ai', text: res.reply }]);
        // 줄이기는 대화로 추가한 장소부터 뺍니다
        let remove = res.patch.removeCount || 0;
        if (remove < 0) addedRef.current = []; // "처음 코스로 되돌려줘"
        while (remove > 0 && addedRef.current.length) { addedRef.current = addedRef.current.slice(0, -1); remove -= 1; }
        setOpts((o) => ({ ...o, ...res.patch, removeCount: (o.removeCount || 0) + remove }));
        return;
      }
      // GPT 가 없는 서버: "늘려줘·미술관 넣어줘" 는 화면에서 장소를 골라 넣습니다
      const add = addToCourse(message, course, { startTime, rain: opts.weather === 'rain', hub });
      if (add) {
        setMsgs((x) => [...x, { from: 'ai', text: add.reply }]);
        if (add.course) {
          setCourse(add.course);
          addedRef.current = [...addedRef.current, ...add.added];
        }
        return;
      }
      setMsgs((x) => [...x, { from: 'ai', text: res.reply }]);
    } catch (e) {
      setMsgs((x) => [...x, { from: 'ai', text: `지금은 답하지 못했어요. 잠시 뒤 다시 말해 주세요. (${e.message})` }]);
    } finally {
      setBusy(false);
    }
  };

  // 다른 코스 보기: 지금까지 본 장소를 피해서 Agent(GPT)가 새로 고릅니다
  const another = async () => {
    if (!course || busy) return;
    setBusy(true);
    addedRef.current = [];
    try {
      const c = await alternativeCourse({ profile, origin, startTime, ...opts, avoid: [...seenRef.current] });
      setCourse({ ...c, stops: applyHub(c.stops, hub) });
      setMsgs((x) => [...x, { from: 'ai', text: `${c.summary ?? '다른 코스를 찾았어요.'} 바꾸고 싶은 점을 말해 주세요.` }]);
    } catch (e) {
      setMsgs((x) => [...x, { from: 'ai', text: `다른 코스를 찾지 못했어요. 잠시 뒤 다시 눌러 주세요. (${e.message})` }]);
    } finally {
      setBusy(false);
    }
  };

  const indoorAsked = opts?.weather === 'rain' && live?.code !== 'rain';
  const sum = course ? courseSummary(course.stops) : null;
  // 공유: 코스를 글로 복사 (휴대폰이면 공유 창)
  const [copied, setCopied] = useState(false);
  const share = async () => {
    const text = [`[제주잇다] ${origin.name} 출발 코스 (${sum.start}~${sum.end})`, ...course.stops.map((s, i) => `${i + 1}. ${s.at} ${s.name}`)].join('\n');
    try {
      if (navigator.share) await navigator.share({ title: '제주잇다 코스', text });
      else { await navigator.clipboard.writeText(text); setCopied(true); setTimeout(() => setCopied(false), 2000); }
    } catch { /* 공유 취소 */ }
  };

  return (
    <section className="split">
      <div className="stack" style={{ gap: 20 }}>
        <div className="stack" style={{ gap: 6 }}>
          <span className="eyebrow">{origin.name} 출발 · {profile.name}</span>
          <h1 style={{ fontSize: '1.6rem' }}>오늘의 추천 코스</h1>
          {sum && <p className="course-sum"><b>{course.stops.length}곳</b><span>{sum.start} ~ {sum.end}</span><span>총 {sum.total}</span><span>이동 {sum.move}</span></p>}
          <div className="weather-bar">
            <span aria-live="polite">
              {!opts ? '날씨 확인 중…'
                : live ? `${weatherLine(live)}${indoorAsked ? ' · 요청대로 실내 위주' : ''}`
                  : '날씨 정보를 불러오지 못했어요'}
            </span>
            {opts && !live && <button className="btn sm ghost" onClick={() => setLiveTry((n) => n + 1)}>다시 불러오기</button>}
          </div>
        </div>
        <div className="row between" style={{ borderTop: '1px solid var(--line)', paddingTop: 16 }}>
          <span className="small muted">내 성향과 날씨·혼잡도에 맞춰 골랐어요</span>
          <div className="row" style={{ gap: 6 }}>
            <button className="btn sm" disabled={!course} onClick={share}>{copied ? '복사했어요' : '공유'}</button>
            <button className="btn sm" disabled={!course || busy} onClick={another}>{busy ? '찾는 중…' : '다른 코스 보기'}</button>
          </div>
        </div>
        <div aria-busy={!course}>
          {!course ? <div className="skeleton" aria-label="코스를 만드는 중"><i /><i /><i /><span className="small muted">코스를 만드는 중…</span></div> : (
            <ol className="timeline">
              {course.stops.map((s, i) => (
                <li key={s.id} className="stop">
                  <span className="t">{s.at}</span>
                  <span className="rail"><i>{i + 1}</i></span>
                  <div className="body">
                    {i > 0 && <span className="move">↓ {profile.transport?.split('·')[0] || '이동'} 약 {duration(s.move)}</span>}
                    <div className="row">
                      <PlaceLink name={s.name} />
                      <PlaceMeta name={s.name} kind={s.kind} label={s.label} addr={s.addr} />
                    </div>
                    {s.stay > 0 && <span className="small muted">{s.at} ~ {leaveAt(s)} · 머무는 시간 {duration(s.stay)}</span>}
                    <Why reasons={s.reasons} />
                    <PlacePhoto name={s.name} />
                    <div className="stop-actions">
                      <a href={kakaoRouteUrl(s)} target="_blank" rel="noopener noreferrer">길찾기</a>
                      <a href={naverPlaceUrl(s.name)} target="_blank" rel="noopener noreferrer">장소 정보</a>
                    </div>
                  </div>
                </li>
              ))}
            </ol>
          )}
        </div>
      </div>

      <div className="stack" style={{ gap: 24, position: 'sticky', top: 80 }}>
        <KakaoMap center={origin} level={9} path markers={(course?.stops ?? []).map((s) => ({ lat: s.lat, lon: s.lon, text: s.name }))} />
        <div className="chat-card">
          <div>
            <h3>바꾸고 싶은 점이 있나요?</h3>
            <span className="small muted">말로 요청하면 AI가 코스를 고쳐요</span>
          </div>
          <div className="chat" ref={chatRef} aria-live="polite">
            {msgs.map((m, i) => <div key={i} className={`bubble ${m.from}`}>{m.text}</div>)}
            {busy && <div className="bubble ai muted">코스를 고치는 중…</div>}
          </div>
          <div className="chips">
            {SUGGEST.map((s) => <button key={s} type="button" className="chip" disabled={busy || !course} onClick={() => send(s)}>{s}</button>)}
          </div>
          <form className="chat-input" onSubmit={(e) => { e.preventDefault(); send(); }}>
            <input className="input" value={text} onChange={(e) => setText(e.target.value)} placeholder="예: 카페는 바다 보이는 곳으로" aria-label="코스 수정 요청" />
            <button className="btn primary" type="submit" disabled={busy || !course}>보내기</button>
          </form>
        </div>
        <div className="cta-bar sticky">
          <button className="btn" disabled={!course} onClick={() => onDone(course, live)}>바로 평가</button>
          <button className="btn primary lg" disabled={!course} onClick={() => (onSave ?? onDone)(course, live)}>이 코스로 다녀올게요</button>
        </div>
        <p className="small muted" style={{ marginTop: -12 }}>다녀온 뒤 홈에서 평가할 수 있어요.</p>
      </div>
    </section>
  );
}
