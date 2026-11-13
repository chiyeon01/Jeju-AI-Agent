import { useEffect, useRef, useState } from 'react';
import JejuMap from '../../components/JejuMap.jsx';
import { Sparkline } from '../../components/Charts.jsx';
import { REGIONS } from '../../mock/tourist.js';
import {
  REGION_HEALTH, POPULAR_COURSES, EVENT_TYPES, EVENT_SAMPLES, SOURCES, DERIVED, QUALITY,
  ACCOUNTS, ACCESS_LOG, MASKING, BACKUPS, RETENTION,
} from '../../mock/console.js';

const TABS = [
  { id: 'overview', label: '통합 현황' },
  { id: 'data', label: '데이터 관리' },
  { id: 'security', label: '접근·보안' },
  { id: 'backup', label: '백업·복구' },
];
const STATUS = { ok: ['good', '정상'], warn: ['warn', '주의'], err: ['bad', '오류'] };
const pad = (n) => String(n).padStart(2, '0');
const now = () => { const d = new Date(); return `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`; };

// 실시간 이벤트 스트림 (실서비스: VITE_EVENT_STREAM_URL WebSocket 구독)
function useLiveEvents() {
  const [events, setEvents] = useState(() => EVENT_SAMPLES.slice(0, 6).map(([type, text], i) => ({ id: i, type, text, at: `09:1${5 - Math.min(i, 5)}:0${i}` })));
  const [totals, setTotals] = useState({ visits: 9770, reviews: 1129, courses: 3412, eps: 42 });
  const [eps, setEps] = useState([31, 35, 38, 33, 40, 44, 39, 42, 46, 41, 43, 42]);
  const seq = useRef(100);
  useEffect(() => {
    const t = setInterval(() => {
      const [type, text] = EVENT_SAMPLES[Math.floor(Math.random() * EVENT_SAMPLES.length)];
      seq.current += 1;
      setEvents((e) => [{ id: seq.current, type, text, at: now(), fresh: true }, ...e].slice(0, 30));
      setTotals((s) => ({
        visits: s.visits + (type === '방문 인증' ? 1 : 0),
        reviews: s.reviews + (type === '평가 등록' ? 1 : 0),
        courses: s.courses + (type === '코스 선택' ? 1 : 0),
        eps: 36 + Math.round(Math.random() * 14),
      }));
      setEps((x) => [...x.slice(1), 36 + Math.round(Math.random() * 14)]);
    }, 2600);
    return () => clearInterval(t);
  }, []);
  return { events, totals, eps };
}

function Overview() {
  const { events, totals, eps } = useLiveEvents();
  const pillOf = Object.fromEntries(EVENT_TYPES.map((e) => [e.type, e.pill]));
  const ranked = REGIONS.map((r) => ({ ...r, ...REGION_HEALTH[r.id] })).sort((a, b) => b.score - a.score);
  return (
    <div className="stack" style={{ gap: 20 }}>
      <div className="grid g4">
        <div className="card kpi"><span className="eyebrow">오늘 방문 인증</span><span className="v">{totals.visits.toLocaleString()}</span><span className="small muted">어제 같은 시각 대비 +6%</span></div>
        <div className="card kpi"><span className="eyebrow">오늘 평가</span><span className="v">{totals.reviews.toLocaleString()}</span><span className="small muted">허위 의심 차단 7건</span></div>
        <div className="card kpi"><span className="eyebrow">오늘 코스 선택</span><span className="v">{totals.courses.toLocaleString()}</span><span className="small muted">완주율 63%</span></div>
        <div className="card kpi">
          <span className="eyebrow">이벤트 처리량</span>
          <div className="row" style={{ justifyContent: 'space-between', flexWrap: 'nowrap' }}>
            <span className="v">{totals.eps}<small className="small muted"> /초</small></span>
            <Sparkline data={eps} width={90} height={34} />
          </div>
          <span className="small muted">평균 지연 0.8초</span>
        </div>
      </div>

      <div className="grid" style={{ gridTemplateColumns: 'minmax(0, 1.5fr) minmax(0, 1fr)', alignItems: 'start' }} data-layout="console-main">
        <div className="card">
          <div className="card-head">
            <h3>지역별 상권 건강 점수 · 인기 코스 흐름</h3>
            <div className="row small" style={{ gap: 10 }}>
              <span style={{ color: 'var(--good)' }}>● 70+</span>
              <span style={{ color: 'var(--sea)' }}>● 60–69</span>
              <span style={{ color: 'var(--warn)' }}>● 55–59</span>
              <span style={{ color: 'var(--bad)' }}>● 55 미만</span>
            </div>
          </div>
          <JejuMap health={REGION_HEALTH} flows={POPULAR_COURSES} />
          <p className="small muted" style={{ marginTop: 8 }}>원 크기 = 오늘 방문 인증 수, 점선 굵기 = 코스 선택 수</p>
        </div>
        <div className="card">
          <div className="card-head">
            <h3>실시간 이벤트</h3>
            <span className="pill good live"><span className="dot" /> 수신 중</span>
          </div>
          <ul className="feed" aria-live="off">
            {events.map((e) => (
              <li key={e.id} className={e.fresh ? 'new' : ''}>
                <span className="num muted small">{e.at}</span>
                <span><span className={`pill ${pillOf[e.type]}`}>{e.type}</span></span>
                <span style={{ minWidth: 0 }}>{e.text}</span>
              </li>
            ))}
          </ul>
        </div>
      </div>

      <div className="grid g2">
        <div className="card">
          <div className="card-head"><h3>지역 순위</h3><span className="small muted">상권 건강 점수 평균</span></div>
          <div className="table-wrap">
            <table className="data">
              <thead><tr><th>지역</th><th>점수</th><th style={{ textAlign: 'right' }}>방문</th><th style={{ textAlign: 'right' }}>평가</th></tr></thead>
              <tbody>
                {ranked.map((r) => (
                  <tr key={r.id}>
                    <td>{r.name}</td>
                    <td style={{ minWidth: 120 }}>
                      <div className="row" style={{ gap: 8, flexWrap: 'nowrap' }}>
                        <div className="bar" style={{ flex: 1 }}><span style={{ width: `${r.score}%`, background: r.score >= 70 ? 'var(--good)' : r.score >= 60 ? 'var(--sea)' : r.score >= 55 ? 'var(--warn)' : 'var(--bad)' }} /></div>
                        <span className="num">{r.score}</span>
                      </div>
                    </td>
                    <td className="num" style={{ textAlign: 'right' }}>{r.visits.toLocaleString()}</td>
                    <td className="num" style={{ textAlign: 'right' }}>{r.reviews}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
        <div className="card">
          <div className="card-head"><h3>인기 코스</h3><span className="small muted">오늘 선택·완주 기준</span></div>
          <div className="stack" style={{ gap: 12 }}>
            {POPULAR_COURSES.map((c, i) => (
              <div key={c.name} className="row" style={{ flexWrap: 'nowrap', alignItems: 'flex-start' }}>
                <span className="num" style={{ color: 'var(--accent)', width: 20 }}>{i + 1}</span>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div>{c.name}</div>
                  <div className="small muted">주 이용 성향 · {c.type}</div>
                </div>
                <span className="num small">{c.count}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function DataManage() {
  return (
    <div className="stack" style={{ gap: 20 }}>
      <div className="card">
        <div className="card-head"><h3>원천 데이터 적재 이력</h3><span className="small muted">제주데이터허브 · 매일 API는 03시 일 배치</span></div>
        <div className="table-wrap">
          <table className="data">
            <thead><tr><th>코드</th><th>데이터</th><th>갱신 주기</th><th>기준 시점</th><th>마지막 적재</th><th style={{ textAlign: 'right' }}>누적 행</th><th>상태</th></tr></thead>
            <tbody>
              {SOURCES.map((s) => (
                <tr key={s.id}>
                  <td className="num">{s.id}</td>
                  <td>{s.name}{s.note && <div className="small muted">{s.note}</div>}</td>
                  <td>{s.cycle}</td>
                  <td className="num">{s.basis}</td>
                  <td className="num">{s.last}</td>
                  <td className="num" style={{ textAlign: 'right' }}>{s.rows}</td>
                  <td><span className={`pill ${STATUS[s.status][0]}`}>{STATUS[s.status][1]}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      <div className="grid g2" style={{ alignItems: 'start' }}>
        <div className="card">
          <div className="card-head"><h3>실시간 생성 데이터</h3><span className="small muted">이벤트 → Redis Streams → 처리 워커</span></div>
          <div className="table-wrap">
            <table className="data">
              <thead><tr><th>데이터</th><th>저장소</th><th>반영 지연</th></tr></thead>
              <tbody>
                {DERIVED.map((d) => (
                  <tr key={d.name}><td><b>{d.name}</b><div className="small muted">{d.desc}</div></td><td className="num small">{d.store}</td><td className="num">{d.lag}</td></tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
        <div className="card">
          <div className="card-head"><h3>품질 점검</h3><span className="small muted">오늘 03:40 실행</span></div>
          <div className="stack" style={{ gap: 0 }}>
            {QUALITY.map((q) => (
              <div key={q.check + q.target} className="row" style={{ padding: '10px 0', borderBottom: '1px solid var(--line)', flexWrap: 'nowrap', alignItems: 'flex-start' }}>
                <span className={`pill ${q.level}`} style={{ minWidth: 64, justifyContent: 'center' }}>{q.check}</span>
                <div style={{ minWidth: 0 }}>
                  <div className="small" style={{ fontWeight: 600 }}>{q.target}</div>
                  <div className="small muted">{q.result}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function Security() {
  return (
    <div className="stack" style={{ gap: 20 }}>
      <div className="card">
        <div className="card-head"><h3>계정별 권한</h3><button className="btn sm">계정 추가</button></div>
        <div className="table-wrap">
          <table className="data">
            <thead><tr><th>계정</th><th>역할</th><th>권한 범위</th><th>마지막 접속</th></tr></thead>
            <tbody>
              {ACCOUNTS.map((a) => (
                <tr key={a.name}><td>{a.name}</td><td><span className={`pill ${a.role === '관리자' ? 'accent' : a.role === '서비스' ? 'sea' : ''}`}>{a.role}</span></td><td>{a.scope}</td><td className="num">{a.last}</td></tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      <div className="grid g2" style={{ alignItems: 'start' }}>
        <div className="card">
          <div className="card-head"><h3>조회·반출 로그</h3></div>
          <div className="table-wrap">
            <table className="data">
              <thead><tr><th>시각</th><th>계정</th><th>요청</th><th>결과</th></tr></thead>
              <tbody>
                {ACCESS_LOG.map((l) => (
                  <tr key={l.at + l.who}><td className="num">{l.at}</td><td>{l.who}<div className="small muted">{l.target}</div></td><td>{l.action}</td><td><span className={`pill ${l.ok ? 'good' : 'bad'}`}>{l.ok ? '허용' : '거부'}</span></td></tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
        <div className="card">
          <div className="card-head"><h3>개인 식별 위험 마스킹 규칙</h3></div>
          <div className="stack" style={{ gap: 0 }}>
            {MASKING.map((m) => (
              <div key={m.rule} style={{ padding: '10px 0', borderBottom: '1px solid var(--line)' }}>
                <div className="small" style={{ fontWeight: 600 }}>{m.rule}</div>
                <div className="small muted">{m.how}</div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function Backup() {
  const [msg, setMsg] = useState('');
  return (
    <div className="grid g2" style={{ alignItems: 'start' }}>
      <div className="card">
        <div className="card-head">
          <h3>스냅샷 이력</h3>
          <button className="btn sm dark" onClick={() => setMsg('수동 스냅샷 요청을 보냈어요. (목업)')}>지금 백업</button>
        </div>
        {msg && <p className="mock-note" style={{ marginBottom: 10 }}>{msg}</p>}
        <div className="table-wrap">
          <table className="data">
            <thead><tr><th>시각</th><th>종류</th><th style={{ textAlign: 'right' }}>크기</th><th>상태</th><th /></tr></thead>
            <tbody>
              {BACKUPS.map((b) => (
                <tr key={b.at}>
                  <td className="num">{b.at}</td><td>{b.kind}</td><td className="num" style={{ textAlign: 'right' }}>{b.size}</td>
                  <td><span className="pill good">완료</span></td>
                  <td><button className="btn sm ghost" onClick={() => setMsg(`${b.at} 스냅샷 복구는 관리자 2인 승인이 필요해요. (목업)`)}>복구</button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      <div className="card">
        <div className="card-head"><h3>보관 기간 정책</h3></div>
        <div className="table-wrap">
          <table className="data">
            <tbody>
              {RETENTION.map((r) => <tr key={r.what}><td>{r.what}</td><td className="num" style={{ textAlign: 'right' }}>{r.keep}</td></tr>)}
            </tbody>
          </table>
        </div>
        <p className="small muted" style={{ marginTop: 12 }}>저장소: PostgreSQL + PostGIS, TimescaleDB, pgvector (Main PC)</p>
      </div>
    </div>
  );
}

export default function MainConsole() {
  const [tab, setTab] = useState('overview');
  return (
    <main className="page">
      <div className="card-head" style={{ marginBottom: 20 }}>
        <div>
          <p className="eyebrow">제주시 Main PC</p>
          <h1 style={{ fontSize: '2.1rem' }}>통합 데이터 관리 콘솔</h1>
        </div>
        <span className="pill">2026-11-10 · 시연용 합성 데이터</span>
      </div>
      <div className="console-shell">
        <nav className="console-side" aria-label="콘솔 메뉴">
          {TABS.map((t) => <button key={t.id} className={tab === t.id ? 'on' : ''} onClick={() => setTab(t.id)}>{t.label}</button>)}
        </nav>
        <div style={{ minWidth: 0 }}>
          {tab === 'overview' && <Overview />}
          {tab === 'data' && <DataManage />}
          {tab === 'security' && <Security />}
          {tab === 'backup' && <Backup />}
        </div>
      </div>
    </main>
  );
}
