import { useEffect, useRef, useState } from 'react';
import KakaoMap from '../../components/KakaoMap.jsx';
import {
  getAdminOverview, getAdminData, getAdminSecurity, updateUser, subscribeEvents,
  getRegionScores, getRegionReports, createRegionReport, getPlaceOverview,
} from '../../api/client.js';
import Markdown from '../../components/Markdown.jsx';
import Progress3D from '../../components/Progress3D.jsx';
import { ROLE_LABEL } from '../../mock/auth.js';
import { buildXlsx, downloadBlob } from '../../utils/xlsx.js';

// 백업 탭은 잠시 뺐습니다 (API 함수 getAdminBackups 등은 client.js 에 그대로 있음)
const TABS = ['현황', 'Agent 보고서', '데이터', '계정·보안'];
// 지역 점수 0~10 (관광객 별점·코스 선택·허브 혼잡도로 실시간 계산)
const scoreColor = (s) => (s >= 7 ? '#2e8b57' : s >= 5 ? '#87CEEB' : '#d0534a');
const fmtAt = (iso) => (iso ? iso.slice(5, 16).replace('T', ' ') : '');
const LEVEL = { ok: 'good', good: 'good', warn: 'warn', err: 'bad', bad: 'bad' };

function useLoad(fn) {
  const [data, setData] = useState(null);
  useEffect(() => { fn().then(setData); }, []); // eslint-disable-line react-hooks/exhaustive-deps
  return [data, setData];
}

function Overview({ events, tick }) {
  const [d] = useLoad(getAdminOverview);
  const [scores, setScores] = useState(null);
  const [places, setPlaces] = useState(null);
  const timer = useRef(null);
  // 지역 점수: 30초마다 다시 계산
  const load = () => {
    getRegionScores().then(setScores).catch(() => {});
    getPlaceOverview().then(setPlaces).catch(() => {});
  };
  useEffect(() => {
    load();
    const id = setInterval(load, 30000);
    return () => { clearInterval(id); clearTimeout(timer.current); };
  }, []); // eslint-disable-line react-hooks/exhaustive-deps
  // 코스 선택·평가 이벤트가 오면 (2초 모아서) 다시 계산
  useEffect(() => {
    if (!tick) return;
    clearTimeout(timer.current);
    timer.current = setTimeout(load, 2000);
  }, [tick]); // eslint-disable-line react-hooks/exhaustive-deps
  if (!d) return <div className="card"><div className="skeleton"><i /><i /><i /></div></div>;
  const o = d.overview;
  const pos = Object.fromEntries(d.health.map((h) => [h.regionId, h]));
  const rows = scores?.regions ?? [];
  return (
    <div className="stack">
      <div className="kpis">
        {[['오늘 방문 인증', o.visits], ['오늘 평가', o.reviews], ['오늘 만든 코스', o.courses], ['초당 이벤트', o.eventsPerSec]].map(([k, v]) => (
          <div key={k}><span className="k">{k}</span><span className="v">{v.toLocaleString()}</span></div>
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
              <thead><tr><th>지역</th><th className="r">점수</th><th className="bar-col">점수 막대</th><th className="r">만족도</th><th className="r">수요</th><th className="r">쾌적함</th><th className="r">평가</th><th className="r">7일 코스</th></tr></thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.regionId}>
                    <td>{r.name}</td><td className="r num"><b>{r.score}</b></td>
                    <td className="bar-col"><Progress3D value={r.score} max={10} color={scoreColor(r.score)} showValue={false} size="sm" /></td><td className="r num">{r.satisfaction}</td><td className="r num">{r.demand}</td>
                    <td className="r num">{r.comfort ?? '-'}</td><td className="r num">{r.reviews}{r.avgStars ? ` (★${r.avgStars})` : ''}</td><td className="r num">{r.courses7d}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
        <div className="card">
          <div className="head"><h3>실시간 이벤트</h3><span className="small muted"><span className="live" aria-hidden="true" /> 실시간</span></div>
          <ul className="feed" aria-live="polite">
            {events.length === 0 && <li><span /><span className="muted">이벤트를 기다리는 중…</span></li>}
            {events.map((e, i) => <li key={`${e.at}-${i}`}><span className="num muted">{e.at}</span><span><span className="type">{e.type}</span>{e.text}</span></li>)}
          </ul>
        </div>
      </div>
      <div className="card">
        <div className="head"><h3>장소별 평가 (고유 번호)</h3><span className="small muted">평가가 들어오면 사장님 화면에 바로 알리고 Agent가 분석해요</span></div>
        <div className="table-wrap">
          <table className="data">
            <thead><tr><th className="r">번호</th><th>장소</th><th className="r">평가</th><th className="r">평균</th><th>사장님</th><th>최근 Agent 분석</th></tr></thead>
            <tbody>
              {(places ?? []).filter((p) => p.reviews > 0 || p.owner).concat((places ?? []).filter((p) => !p.reviews && !p.owner)).slice(0, 30).map((p) => (
                <tr key={p.id}>
                  <td className="r num">#{p.no}</td><td>{p.name}</td><td className="r num">{p.reviews}</td>
                  <td className="r num">{p.avgStars ? `★${p.avgStars}` : '-'}</td>
                  <td>{p.owner ? <span className="pill good">연결</span> : <span className="muted small">-</span>}</td>
                  <td className="small muted">{p.lastAnalysis ? fmtAt(p.lastAnalysis.createdAt) : '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
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
        {open ? <><div className="head"><h3>{open.title}</h3>{open.createdAt && <span className="small muted">{fmtAt(open.createdAt)} · {open.source === 'gpt' ? 'GPT 작성' : '규칙 기반'}</span>}</div><Markdown text={open.body} /></> : <div className="empty"><p>보고서를 고르거나 새로 만들어 주세요.</p></div>}
      </div>
    </div>
  );
}

function DataTab() {
  const [d] = useLoad(getAdminData);
  if (!d) return <div className="card"><div className="skeleton"><i /><i /><i /></div></div>;
  return (
    <div className="stack">
      <div className="card stack">
        <h3>원천 데이터 (제주데이터허브)</h3>
        <Progress3D
          label="정상 적재된 원천 데이터"
          value={d.sources.filter((s) => s.status === 'ok').length}
          max={d.sources.length}
          valueText={`${d.sources.filter((s) => s.status === 'ok').length} / ${d.sources.length}`}
          color="#2e8b57"
        />
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
          <div>
            {d.derived.map((x) => (
              <div key={x.name} className="check-row"><span><b>{x.name}</b><br /><span className="muted small">{x.desc}</span></span><span className="pill">{x.lag}</span></div>
            ))}
          </div>
        </div>
        <div className="card stack">
          <h3>품질 점검</h3>
          <div>
            {d.quality.map((x) => (
              <div key={x.check + x.target} className="check-row"><span><b>{x.check}</b> <span className="muted">{x.target}</span><br /><span className="small">{x.result}</span></span><span className={`pill ${LEVEL[x.level]}`}>{x.level === 'good' ? '정상' : x.level === 'warn' ? '주의' : '조치'}</span></div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function Security() {
  const [d, setD] = useLoad(getAdminSecurity);
  if (!d) return <div className="card"><div className="skeleton"><i /><i /><i /></div></div>;
  const approve = async (u) => {
    await updateUser(u.id, { status: 'ACTIVE' });
    setD({ ...d, users: d.users.map((x) => (x.id === u.id ? { ...x, status: 'ACTIVE' } : x)) });
  };
  return (
    <div className="stack">
      <div className="card">
        <div className="head"><h3>계정</h3>{d.users.some((u) => u.status === 'PENDING') && <span className="pill warn">승인 대기 {d.users.filter((u) => u.status === 'PENDING').length}명</span>}</div>
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
          <div>{d.masking.map((m) => <div key={m.rule} className="check-row"><b>{m.rule}</b><span className="muted small r">{m.how}</span></div>)}</div>
        </div>
      </div>
    </div>
  );
}

// ── 엑셀 저장 ───────────────────────────────
const n = (v) => (v === null || v === undefined || v === '' || Number.isNaN(Number(v)) ? v ?? '' : Number(v));
const stamp = (d) => {
  const p = (x) => String(x).padStart(2, '0');
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}_${p(d.getHours())}${p(d.getMinutes())}`;
};
const LEVEL_KO = { good: '정상', ok: '정상', warn: '주의', bad: '조치', err: '오류' };
const STATUS_KO = { ACTIVE: '사용 중', PENDING: '승인 대기', SUSPENDED: '정지' };

/** 콘솔에 보이는 자료를 모두 새로 받아 시트로 만듭니다. onStep(완료 수, 전체, 이름) 으로 진행을 알립니다 */
async function collectSheets(events, onStep) {
  const steps = [
    ['현황', getAdminOverview],
    ['지역 점수', getRegionScores],
    ['장소별 평가', getPlaceOverview],
    ['Agent 보고서', getRegionReports],
    ['데이터', getAdminData],
    ['계정·보안', getAdminSecurity],
  ];
  const got = {};
  const failed = [];
  for (let i = 0; i < steps.length; i++) {
    const [name, fn] = steps[i];
    onStep(i, steps.length + 1, `${name} 불러오는 중`);
    try { got[name] = await fn(); } catch (e) { failed.push(`${name}: ${e.message}`); }
  }
  onStep(steps.length, steps.length + 1, '엑셀 파일 만드는 중');

  const now = new Date();
  const o = got['현황']?.overview;
  const sc = got['지역 점수'];
  const sheets = [{
    name: '요약',
    columns: [{ title: '항목', width: 24 }, { title: '값', width: 40 }],
    rows: [
      ['저장 시각', now.toLocaleString('ko-KR')],
      ['오늘 방문 인증', n(o?.visits)], ['오늘 평가', n(o?.reviews)], ['오늘 만든 코스', n(o?.courses)], ['초당 이벤트', n(o?.eventsPerSec)],
      ['지역 점수 계산 시각', sc?.updatedAt ? fmtAt(sc.updatedAt) : ''],
      ['지역 점수 가중치', '관광객 별점 만족도 50% · 최근 7일 코스 선택과 평가 30% · 데이터허브 혼잡도 20%'],
      ...failed.map((f) => ['불러오지 못한 자료', f]),
    ],
  }];
  if (sc) sheets.push({
    name: '지역 점수',
    columns: ['지역', '점수(0~10)', '만족도', '수요', '쾌적함', '평가 수', '평균 별점', '7일 코스', '7일 평가'].map((title) => ({ title })),
    rows: (sc.regions ?? []).map((r) => [r.name, n(r.score), n(r.satisfaction), n(r.demand), n(r.comfort), n(r.reviews), n(r.avgStars), n(r.courses7d), n(r.reviews7d)]),
  });
  if (got['장소별 평가']) sheets.push({
    name: '장소별 평가',
    columns: ['번호', '장소', '지역', '종류', '평가 수', '평균 별점', '사장님 연결', '최근 Agent 분석'].map((title) => ({ title })),
    rows: got['장소별 평가'].map((p) => [n(p.no), p.name, p.region ?? '', p.kind ?? '', n(p.reviews), n(p.avgStars), p.owner ? '연결' : '-', p.lastAnalysis ? fmtAt(p.lastAnalysis.createdAt) : '-']),
  });
  sheets.push({
    name: '실시간 이벤트',
    columns: [{ title: '시각' }, { title: '종류' }, { title: '내용', width: 60 }],
    rows: events.map((e) => [e.at, e.type, e.text]),
  });
  if (got['Agent 보고서']) sheets.push({
    name: 'Agent 보고서',
    columns: [{ title: '작성 시각' }, { title: '제목', width: 30 }, { title: '방식' }, { title: '본문', width: 90 }],
    rows: got['Agent 보고서'].map((r) => [fmtAt(r.createdAt), r.title, r.source === 'gpt' ? 'GPT' : '규칙', r.body ?? '']),
  });
  const dd = got['데이터'];
  if (dd) sheets.push(
    {
      name: '원천 데이터',
      columns: ['코드', '데이터', '주기', '기준', '마지막 적재', '행 수', '상태'].map((title) => ({ title })),
      rows: dd.sources.map((s) => [s.id, s.name, s.cycle, s.basis, s.last, n(String(s.rows ?? '').replace(/,/g, '')), s.status === 'ok' ? '정상' : s.note || LEVEL_KO[s.status] || s.status]),
    },
    {
      name: '파생 데이터',
      columns: ['이름', '설명', '저장소', '지연'].map((title) => ({ title })),
      rows: dd.derived.map((x) => [x.name, x.desc, x.store ?? '', x.lag]),
    },
    {
      name: '품질 점검',
      columns: ['점검', '대상', '결과', '판정'].map((title) => ({ title })),
      rows: dd.quality.map((x) => [x.check, x.target, x.result, LEVEL_KO[x.level] || x.level]),
    },
  );
  const sec = got['계정·보안'];
  if (sec) sheets.push(
    {
      name: '계정',
      columns: ['이름', '이메일', '역할', '최근 접속', '상태'].map((title) => ({ title })),
      rows: sec.users.map((u) => [u.name, u.email, ROLE_LABEL[u.role] ?? u.role, u.last ?? '', STATUS_KO[u.status] ?? u.status]),
    },
    {
      name: '접근 기록',
      columns: ['시각', '사용자', '행동', '대상', '결과'].map((title) => ({ title })),
      rows: sec.logs.map((l) => [l.at, l.who, l.action, l.target, l.ok ? '허용' : '차단']),
    },
    {
      name: '개인정보 보호 규칙',
      columns: [{ title: '규칙', width: 24 }, { title: '방법', width: 50 }],
      rows: sec.masking.map((m) => [m.rule, m.how]),
    },
  );
  // 한글 파일 이름은 일부 브라우저가 "download" 로 바꿔 버려서 영문으로 저장합니다
  return { sheets, failed, filename: `jeju-itda_console_${stamp(now)}.xlsx` };
}

function ExportButton({ events }) {
  const [prog, setProg] = useState(null); // { done, total, text }
  const [msg, setMsg] = useState(null);
  const run = async () => {
    setMsg(null);
    setProg({ done: 0, total: 1, text: '준비 중' });
    try {
      const { sheets, failed, filename } = await collectSheets(events, (done, total, text) => setProg({ done, total, text }));
      downloadBlob(buildXlsx(sheets), filename);
      setProg({ done: 1, total: 1, text: '저장 완료' });
      setMsg(failed.length
        ? { tone: 'warn', text: `${filename} 저장. 일부 자료는 불러오지 못했어요 (${failed.length}건, '요약' 시트 참고).` }
        : { tone: 'good', text: `${filename} 저장 완료 (${sheets.length}개 시트)` });
    } catch (e) {
      setMsg({ tone: 'bad', text: `저장하지 못했어요: ${e.message}` });
    } finally {
      setTimeout(() => setProg(null), 1200);
    }
  };
  return (
    <div className="export">
      <button className="btn outline export-btn" disabled={!!prog} onClick={run}>
        <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 3v10.17l3.59-3.58L17 11l-5 5-5-5 1.41-1.41L11 13.17V3h2zM5 19h14v2H5z" /></svg>
        {prog ? '저장 중…' : '엑셀로 저장'}
      </button>
      {prog && <Progress3D value={prog.done} max={prog.total} label={prog.text} active={prog.done < prog.total} size="md" />}
      {!prog && msg && <p className={`note ${msg.tone}`} role="status">{msg.text}</p>}
    </div>
  );
}

export default function MainConsole() {
  const [tab, setTab] = useState(0);
  // 실시간 이벤트는 탭을 옮겨도 이어지게 여기서 받습니다 (엑셀 저장에도 들어감)
  const [events, setEvents] = useState([]);
  const [tick, setTick] = useState(0);
  useEffect(() => subscribeEvents((e) => {
    setEvents((x) => [e, ...x].slice(0, 30));
    setTick((t) => t + 1);
  }), []);
  return (
    <main className="page console">
      <header className="console-head">
        <div>
          <span className="label">Main PC · 제주시</span>
          <h1>통합 관리</h1>
          <p className="small">지역 점수와 실시간 이벤트, 데이터허브 적재 상태를 봅니다.</p>
        </div>
        <ExportButton events={events} />
      </header>
      <div className="tabs" role="tablist">
        {TABS.map((t, i) => <button key={t} role="tab" aria-selected={tab === i} className={tab === i ? 'on' : ''} onClick={() => setTab(i)}>{t}</button>)}
      </div>
      {tab === 0 && <Overview events={events} tick={tick} />}
      {tab === 1 && <Reports />}
      {tab === 2 && <DataTab />}
      {tab === 3 && <Security />}
    </main>
  );
}
