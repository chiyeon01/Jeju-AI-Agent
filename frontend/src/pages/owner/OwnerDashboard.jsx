import { useState } from 'react';
import { Gauge, LineChart, Sparkline, Stars } from '../../components/Charts.jsx';
import { STORE, SCORE_TREND, INDICATORS, FIT_DIST, WEEKLY_REPORT, REVIEW_TOPICS, RECENT_REVIEWS, OWNER_QA } from '../../mock/owner.js';
import { askOwnerAgent, registerAction } from '../../api/client.js';

const WEEKS = SCORE_TREND.map((_, i) => `${i - SCORE_TREND.length + 1 === 0 ? '이번 주' : `${SCORE_TREND.length - 1 - i}주 전`}`);

function Indicator({ m }) {
  const deltaCls = m.delta == null || m.delta === 0 ? '' : (m.delta > 0) === m.good ? 'up' : 'down';
  return (
    <div className="card metric">
      <div className="row" style={{ justifyContent: 'space-between', gap: 8 }}>
        <span className="small" style={{ fontWeight: 600 }}>{m.name}</span>
        <span className="source">{m.src}</span>
      </div>
      <div className="row" style={{ justifyContent: 'space-between', alignItems: 'flex-end' }}>
        {typeof m.value === 'number'
          ? <span className="val">{m.value}<small>{m.unit}</small></span>
          : <span style={{ fontFamily: 'var(--font-display)', fontSize: '1.3rem', color: 'var(--accent)' }}>{m.value}</span>}
        {m.spark && <Sparkline data={m.spark} width={96} height={32} color={m.good ? 'var(--sea)' : 'var(--warn)'} />}
      </div>
      <div className="row small" style={{ justifyContent: 'space-between' }}>
        <span className="muted">{m.desc}</span>
      </div>
      <div className="row small" style={{ justifyContent: 'space-between' }}>
        {m.delta != null
          ? <span className={`delta ${deltaCls} num`}>{m.delta > 0 ? '▲' : m.delta < 0 ? '▼' : '–'} {Math.abs(m.delta)}{m.unit === '%' ? '%p' : ''} 지난달 대비</span>
          : <span className="muted">상위 성향 비중 31%</span>}
        <span className="source">기준 {m.basis}</span>
      </div>
    </div>
  );
}

export default function OwnerDashboard() {
  const [chat, setChat] = useState([]);
  const [q, setQ] = useState('');
  const [asking, setAsking] = useState(false);
  const [action, setAction] = useState({ kind: '메뉴', title: '' });
  const [registered, setRegistered] = useState([]);

  const ask = async (question) => {
    const text = (question ?? q).trim();
    if (!text) return;
    setQ('');
    setChat((c) => [...c, { from: 'me', text }]);
    setAsking(true);
    const r = await askOwnerAgent(text);
    setAsking(false);
    setChat((c) => [...c, { from: 'ai', text: r.answer }]);
  };

  const submitAction = async (e) => {
    e.preventDefault();
    if (!action.title.trim()) return;
    await registerAction(action);
    setRegistered((r) => [{ ...action, at: '방금' }, ...r]);
    setAction({ ...action, title: '' });
  };

  const priority = [...REVIEW_TOPICS].sort((a, b) => a.pos - b.pos);

  return (
    <main className="page stack" style={{ gap: 24 }}>
      <div className="card-head" style={{ marginBottom: 0 }}>
        <div>
          <p className="eyebrow">{STORE.dong} · {STORE.category}</p>
          <h1 style={{ fontSize: '2.1rem' }}>{STORE.name}</h1>
        </div>
        <span className="pill" style={{ whiteSpace: 'normal' }}>시연용 가상 매장 · {STORE.basis}</span>
      </div>

      {/* 요약: 종합 점수 + 추이 */}
      <section className="grid g2">
        <div className="card raised health">
          <Gauge value={STORE.score} />
          <div className="stack" style={{ gap: 10 }}>
            <div>
              <p className="eyebrow">상권 건강 점수</p>
              <p style={{ fontSize: '1.15rem', marginTop: 4 }}>
                {STORE.dong} 한식 업종 {STORE.peers}곳 중 <b>상위 {100 - STORE.percentile}%</b>
              </p>
            </div>
            <div className="row">
              <span className="pill good">▲ {STORE.scoreDelta}점 지난주 대비</span>
              <span className="pill">백분위 {STORE.percentile}</span>
            </div>
            <p className="small muted">카드·유동인구는 매장이 아닌 읍면동·업종 단위입니다. 매장 점수는 그 지역 지표에 앱 평가를 더해 계산합니다.</p>
          </div>
        </div>
        <div className="card">
          <div className="card-head"><h3>주간 점수 추이</h3><span className="small muted">최근 12주</span></div>
          <LineChart data={SCORE_TREND} labels={WEEKS} />
        </div>
      </section>

      {/* AI 개선 제안 */}
      <section className="card raised stack">
        <div className="card-head" style={{ marginBottom: 0 }}>
          <div>
            <p className="eyebrow">AI 상권 컨설팅 · {WEEKLY_REPORT.week}</p>
            <h3>이번 주 개선 제안</h3>
          </div>
          <span className="pill accent">상권 분석 Agent</span>
        </div>
        <div className="report"><p>{WEEKLY_REPORT.summary}</p></div>
        <div className="grid g3">
          {WEEKLY_REPORT.actions.map((a, i) => (
            <div key={a.title} className="card flat stack" style={{ gap: 6, background: 'var(--bg)' }}>
              <span className="num small" style={{ color: 'var(--accent)' }}>제안 {i + 1}</span>
              <strong>{a.title}</strong>
              <span className="small muted">{a.why}</span>
              <span className="pill sea" style={{ alignSelf: 'flex-start' }}>{a.impact}</span>
            </div>
          ))}
        </div>
      </section>

      {/* 세부 지표 */}
      <section className="stack">
        <div className="card-head" style={{ marginBottom: 0 }}>
          <h3>세부 지표</h3>
          <span className="small muted">D1~D8: 제주데이터허브 원천 데이터 · 자체: 앱 평가</span>
        </div>
        <div className="grid g3">
          {INDICATORS.filter((m) => m.key !== 'fit').map((m) => <Indicator key={m.key} m={m} />)}
        </div>
      </section>

      {/* 리뷰 인사이트 + 대화 */}
      <section className="grid g2" style={{ alignItems: 'start' }}>
        <div className="card stack">
          <div className="card-head" style={{ marginBottom: 0 }}><h3>리뷰 인사이트</h3><span className="small muted">최근 30일 · 128건</span></div>
          <div className="table-wrap">
            <table className="data">
              <thead><tr><th>개선 순위</th><th>주제</th><th>긍정 비율</th><th style={{ textAlign: 'right' }}>언급</th></tr></thead>
              <tbody>
                {priority.map((t, i) => (
                  <tr key={t.topic}>
                    <td className="num">{i + 1}</td>
                    <td>{t.topic} {t.pos < 60 && <span className="pill bad">개선 필요</span>}</td>
                    <td style={{ minWidth: 140 }}>
                      <div className="row" style={{ gap: 8, flexWrap: 'nowrap' }}>
                        <div className="bar" style={{ flex: 1 }}><span style={{ width: `${t.pos}%`, background: t.pos < 60 ? 'var(--bad)' : t.pos < 75 ? 'var(--warn)' : 'var(--good)' }} /></div>
                        <span className="num small">{t.pos}%</span>
                      </div>
                    </td>
                    <td className="num" style={{ textAlign: 'right' }}>{t.mentions}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="stack" style={{ gap: 10 }}>
            <span className="eyebrow">최근 리뷰</span>
            {RECENT_REVIEWS.map((r) => (
              <div key={r.at} className="stack" style={{ gap: 2, borderTop: '1px solid var(--line)', paddingTop: 10 }}>
                <div className="row small" style={{ justifyContent: 'space-between' }}>
                  <Stars value={r.stars} />
                  <span className="muted num">{r.at}</span>
                </div>
                <p className="small">{r.text}</p>
                <div className="row" style={{ gap: 6 }}>
                  <span className="pill">{r.type}</span>
                  {r.tags.map((t) => <span key={t} className={`pill ${t.endsWith('−') ? 'bad' : 'good'}`}>{t}</span>)}
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="stack">
            <div className="card stack" style={{ gap: 8 }}>
              <span className="source">자체 평가 · 실시간</span>
              <span className="small" style={{ fontWeight: 600 }}>성향 적합도 · 이 매장을 높게 평가한 관광객</span>
              {FIT_DIST.map((f) => (
                <div key={f.name} className="stack" style={{ gap: 2 }}>
                  <div className="row small" style={{ justifyContent: 'space-between' }}><span>{f.name}</span><span className="num">{f.pct}%</span></div>
                  <div className="bar"><span style={{ width: `${f.pct * 2.5}%` }} /></div>
                </div>
              ))}
            </div>
          <div className="card">
            <div className="card-head"><h3>AI에게 물어보기</h3></div>
            <div className="chat" aria-live="polite">
              {chat.length === 0 && <div className="bubble ai">매장 지표에 대해 궁금한 점을 물어보세요. 계산은 데이터 도구가 하고, 저는 근거와 함께 설명해 드려요.</div>}
              {chat.map((m, i) => <div key={i} className={`bubble ${m.from}`}>{m.text}</div>)}
              {asking && <div className="bubble ai muted">지표 계산 중…</div>}
            </div>
            <div className="chips" style={{ marginTop: 10 }}>
              {Object.keys(OWNER_QA).map((s) => <button key={s} type="button" className="chip" onClick={() => ask(s)}>{s}</button>)}
            </div>
            <form className="chat-input" onSubmit={(e) => { e.preventDefault(); ask(); }}>
              <input id="owner-ask" className="input" value={q} onChange={(e) => setQ(e.target.value)} placeholder="예: 평일 저녁 손님을 늘리려면?" />
              <button className="btn dark" type="submit">질문</button>
            </form>
          </div>

          <form className="card stack" onSubmit={submitAction}>
            <div>
              <h3>개선 조치 등록</h3>
              <p className="small muted">등록한 메뉴·이벤트는 관광객 코스의 추천 문구에 반영되고, 이후 평가로 효과를 측정해요.</p>
            </div>
            <div className="seg" role="group" aria-label="조치 종류">
              {['메뉴', '이벤트', '좌석·시설'].map((k) => (
                <button key={k} type="button" className={action.kind === k ? 'on' : ''} onClick={() => setAction({ ...action, kind: k })}>{k}</button>
              ))}
            </div>
            <div className="field">
              <label htmlFor="action-title">내용</label>
              <input id="action-title" className="input" value={action.title} onChange={(e) => setAction({ ...action, title: e.target.value })} placeholder="예: 17~19시 커플 세트 (고기국수 2 + 음료)" />
            </div>
            <button className="btn primary" type="submit" disabled={!action.title.trim()}>등록하기</button>
            {registered.map((r, i) => (
              <div key={i} className="row small" style={{ justifyContent: 'space-between' }}>
                <span><span className="pill accent">{r.kind}</span> {r.title}</span>
                <span className="pill good">등록됨 · 효과 측정 시작</span>
              </div>
            ))}
          </form>
        </div>
      </section>
    </main>
  );
}
