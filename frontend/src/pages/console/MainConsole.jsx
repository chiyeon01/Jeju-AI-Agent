import { useEffect, useRef, useState } from 'react';
import KakaoMap from '../../components/KakaoMap.jsx';
import {
  getAdminOverview, getAdminData, getAdminSecurity, updateUser, getAdminBackups, requestBackup, restoreBackup, subscribeEvents,
  getRegionScores, getRegionReports, createRegionReport,
} from '../../api/client.js';
import Markdown from '../../components/Markdown.jsx';
import { ROLE_LABEL } from '../../mock/auth.js';

const TABS = ['현황', 'Agent 보고서', '데이터', '계정·보안', '백업'];
// 지역 점수 0~10 (관광객 별점·코스 선택·허브 혼잡도로 실시간 계산)
const scoreColor = (s) => (s >= 7 ? '#2e8b57' : s >= 5 ? '#87CEEB' : '#d0534a');
const fmtAt = (iso) => (iso ? iso.slice(5, 16).replace('T', ' ') : '');
const LEVEL = { ok: 'good', good: 'good', warn: 'warn', err: 'bad', bad: 'bad' };

function useLoad(fn) {
  const [data, setData] = useState(null);
  useEffect(() => { fn().then(setData); }, []); // eslint-disable-line react-hooks/exhaustive-deps
  return [data, setData];
}

function Overview() {
  const [d] = useLoad(getAdminOverview);
  const [scores, setScores] = useState(null);
  const [events, setEvents] = useState([]);
  const timer = useRef(null);
  // 지역 점수: 30초마다, 그리고 코스 선택·평가 이벤트가 오면 (2초 모아서) 다시 계산
  useEffect(() => {
    const load = () => getRegionScores().then(setScores).catch(() => {});
    load();
    const id = setInterval(load, 30000);
    const off = subscribeEvents((e) => {
      setEvents((x) => [e, ...x].slice(0, 30));
      clearTimeout(timer.current);
      timer.current = setTimeout(load, 2000);
    });
    return () => { clearInterval(id); clearTimeout(timer.current); off?.(); };
  }, []);
  if (!d) return <p className="muted">불러오는 중…</p>;
  const o = d.overview;
  const pos = Object.fromEntries(d.health.map((h) => [h.regionId, h]));
  const rows = scores?.regions ?? [];
  return (
    <div className="stack">
      <div className="grid g4">
        {[['오늘 방문 인증', o.visits], ['오늘 평가', o.reviews], ['오늘 만든 코스', o.courses], ['초당 이벤트', o.eventsPerSec]].map(([k, v]) => (
          <div key={k} className="card metric"><span className="label">{k}</span><div className="v num">{v.toLocaleString()}</div></div>
        ))}
      </div>
      <div className="grid g2" style={{ alignItems: 'start' }}>
        <div className="card stack">
          <div className="head" style={{ marginBottom: 0 }}>
            <h3>지역 점수 (0~10)</h3>
            <span className="small muted">{scores ? `${fmtAt(scores.updatedAt)} 계산` : '계산 중…'}</span>
          </div>
          <p className="small muted" style={{ margin: 0 }}>관광객 별점 만족도 50% · 최근 7일 코스 선택과 평가 30% · 데이터허브 혼잡도 20%{scores?.crowdDate ? ` (${scores.crowdDate})` : ''}</p>
          <KakaoMap circles={rows.filter((r) => pos[r.regionId]).map((r) => ({ lat: pos[r.regionId].lat, lon: pos[r.regionId].lon, radius: 4000, color: scoreColor(r.score), text: `${r.name} ${r.score}` }))} />
          <div className="table-wrap">
            <table className="data">
              <thead><tr><th>지역</th><th className="r">점수</th><th className="r">만족도</th><th className="r">수요</th><th className="r">쾌적함</th><th className="r">평가</th><th className="r">7일 코스</th></tr></thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.regionId}>
                    <td>{r.name}</td><td className="r num"><b>{r.score}</b></td><td className="r num">{r.satisfaction}</td><td className="r num">{r.demand}</td>
                    <td className="r num">{r.comfort ?? '-'}</td><td className="r num">{r.reviews}{r.avgStars ? ` (★${r.avgStars})` : ''}</td><td className="r num">{r.courses7d}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
        <div className="card">
          <div className="head"><h3>실시간 이벤트</h3><span className="live" aria-hidden="true" /></div>
          <ul className="feed" aria-live="polite">
            {events.length === 0 && <li><span /><span className="muted">이벤트를 기다리는 중…</span></li>}
            {events.map((e, i) => <li key={`${e.at}-${i}`}><span className="num muted">{e.at}</span><span><b>{e.type}</b> {e.text}</span></li>)}
          </ul>
        </div>
      </div>
    </div>
  );
}

function Reports() {
  const [list, setList] = useState(null);
  const [open, setOpen] = useState(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');
  useEffect(() => { getRegionReports().then((l) => { setList(l); setOpen(l[0] ?? null); }).catch((e) => setErr(e.message)); }, []);
  const make = async () => {
    setBusy(true); setErr('');
    try {
      const r = await createRegionReport();
      setList((l) => [r, ...(l ?? [])]);
      setOpen(r);
    } catch (e) { setErr(e.message); } finally { setBusy(false); }
  };
  return (
    <div className="grid g2" style={{ alignItems: 'start', gridTemplateColumns: 'minmax(0, 1fr) minmax(0, 2fr)' }}>
      <div className="card stack">
        <div className="head" style={{ marginBottom: 0 }}>
          <h3>저장된 보고서</h3>
          <button className="btn sm primary" disabled={busy} onClick={make}>{busy ? '작성 중…' : '지금 보고서 만들기'}</button>
        </div>
        <p className="small muted" style={{ margin: 0 }}>Agent가 관광객 평가·코스 선택·지역 점수를 읽고 문서를 써서 Main PC에 저장해요. 허브 수치는 등급으로만 넘겨요.</p>
        {err && <p className="note bad">{err}</p>}
        {!list ? <p className="muted">불러오는 중…</p> : list.length === 0 ? <p className="muted">아직 보고서가 없어요.</p> : (
          <ul className="list">
            {list.map((r) => (
              <li key={r.id}>
                <button className={`btn ghost sm${open?.id === r.id ? ' on' : ''}`} style={{ width: '100%', justifyContent: 'space-between' }} onClick={() => setOpen(r)}>
                  <span>{r.title}</span><span className="pill">{r.source === 'gpt' ? 'GPT' : '규칙'}</span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
      <div className="card">
        {open ? <><h3 style={{ marginBottom: 8 }}>{open.title}</h3><Markdown text={open.body} /></> : <p className="muted">보고서를 고르거나 새로 만들어 주세요.</p>}
      </div>
    </div>
  );
}

function DataTab() {
  const [d] = useLoad(getAdminData);
  if (!d) return <p className="muted">불러오는 중…</p>;
  return (
    <div className="stack">
      <div className="card">
        <h3 style={{ marginBottom: 10 }}>원천 데이터 (제주데이터허브)</h3>
        <div className="table-wrap">
          <table className="data">
            <thead><tr><th>코드</th><th>데이터</th><th>주기</th><th>기준</th><th>마지막 적재</th><th className="r">행 수</th><th>상태</th></tr></thead>
            <tbody>
              {d.sources.map((s) => (
                <tr key={s.id}>
                  <td className="num">{s.id}</td><td>{s.name}</td><td>{s.cycle}</td><td className="num">{s.basis}</td><td className="num">{s.last}</td><td className="r num">{s.rows}</td>
                  <td><span className={`pill ${LEVEL[s.status]}`}>{s.status === 'ok' ? '정상' : s.note}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      <div className="grid g2" style={{ alignItems: 'start' }}>
        <div className="card stack">
          <h3>파생 데이터</h3>
          {d.derived.map((x) => (
            <div key={x.name} className="row between small"><span><b>{x.name}</b> <span className="muted">{x.desc}</span></span><span className="pill">{x.lag}</span></div>
          ))}
        </div>
        <div className="card stack">
          <h3>품질 점검</h3>
          {d.quality.map((x) => (
            <div key={x.check + x.target} className="row between small"><span><b>{x.check}</b> {x.target} <span className="muted">· {x.result}</span></span><span className={`pill ${LEVEL[x.level]}`}>{x.level === 'good' ? '정상' : x.level === 'warn' ? '주의' : '조치'}</span></div>
          ))}
        </div>
      </div>
    </div>
  );
}

function Security() {
  const [d, setD] = useLoad(getAdminSecurity);
  if (!d) return <p className="muted">불러오는 중…</p>;
  const approve = async (u) => {
    await updateUser(u.id, { status: 'ACTIVE' });
    setD({ ...d, users: d.users.map((x) => (x.id === u.id ? { ...x, status: 'ACTIVE' } : x)) });
  };
  return (
    <div className="stack">
      <div className="card">
        <h3 style={{ marginBottom: 10 }}>계정</h3>
        <div className="table-wrap">
          <table className="data">
            <thead><tr><th>이름</th><th>이메일</th><th>역할</th><th>최근 접속</th><th /></tr></thead>
            <tbody>
              {d.users.map((u) => (
                <tr key={u.id ?? u.name}>
                  <td>{u.name}</td><td className="muted">{u.email}</td><td>{ROLE_LABEL[u.role]}</td><td className="num">{u.last}</td>
                  <td className="r">{u.status === 'PENDING' ? <button className="btn sm primary" onClick={() => approve(u)}>가입 승인</button> : <span className={`pill ${u.status === 'ACTIVE' ? 'good' : 'bad'}`}>{u.status === 'ACTIVE' ? '사용 중' : '정지'}</span>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      <div className="grid g2" style={{ alignItems: 'start' }}>
        <div className="card">
          <h3 style={{ marginBottom: 10 }}>접근 기록</h3>
          <div className="table-wrap">
            <table className="data">
              <tbody>
                {d.logs.map((l) => (
                  <tr key={l.at + l.who}><td className="num">{l.at}</td><td>{l.who}<div className="small muted">{l.action} · {l.target}</div></td><td className="r"><span className={`pill ${l.ok ? 'good' : 'bad'}`}>{l.ok ? '허용' : '차단'}</span></td></tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
        <div className="card stack">
          <h3>개인정보 보호 규칙</h3>
          {d.masking.map((m) => <div key={m.rule} className="small"><b>{m.rule}</b> <span className="muted">{m.how}</span></div>)}
        </div>
      </div>
    </div>
  );
}

function Backups() {
  const [d] = useLoad(getAdminBackups);
  const [msg, setMsg] = useState('');
  if (!d) return <p className="muted">불러오는 중…</p>;
  return (
    <div className="grid g2" style={{ alignItems: 'start' }}>
      <div className="card stack">
        <div className="head" style={{ marginBottom: 0 }}>
          <h3>백업</h3>
          <button className="btn sm primary" onClick={async () => setMsg((await requestBackup()).message)}>지금 백업</button>
        </div>
        {msg && <p className="note">{msg}</p>}
        <div className="table-wrap">
          <table className="data">
            <tbody>
              {d.backups.map((b) => (
                <tr key={b.at}><td className="num">{b.at}</td><td>{b.kind}</td><td className="r num">{b.size}</td>
                  <td className="r"><button className="btn sm" onClick={async () => setMsg((await restoreBackup(b.at)).message)}>복구</button></td></tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      <div className="card stack">
        <h3>보관 기간</h3>
        {d.retention.map((r) => <div key={r.what} className="row between small"><span>{r.what}</span><b>{r.keep}</b></div>)}
      </div>
    </div>
  );
}

export default function MainConsole() {
  const [tab, setTab] = useState(0);
  return (
    <main className="page">
      <h1 style={{ marginBottom: 12 }}>통합 관리</h1>
      <div className="tabs" role="tablist">
        {TABS.map((t, i) => <button key={t} role="tab" aria-selected={tab === i} className={tab === i ? 'on' : ''} onClick={() => setTab(i)}>{t}</button>)}
      </div>
      {tab === 0 && <Overview />}
      {tab === 1 && <Reports />}
      {tab === 2 && <DataTab />}
      {tab === 3 && <Security />}
      {tab === 4 && <Backups />}
    </main>
  );
}
