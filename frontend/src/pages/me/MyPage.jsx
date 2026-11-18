// 내 정보 · 설정 (상단 이름을 누르면 열림)
import { useEffect, useState } from 'react';
import { useAuth } from '../../auth/AuthContext.jsx';
import { fetchMe, isMock } from '../../api/client.js';
import { clearHistory, loadHistory } from '../../api/history.js';
import { ROLE_LABEL } from '../../mock/auth.js';
import { useSettings, BRIGHTNESS_MIN } from '../../settings.js';

const STATUS_LABEL = { ACTIVE: '사용 중', PENDING: '승인 대기', SUSPENDED: '이용 정지' };

export default function MyPage() {
  const { user, logout } = useAuth();
  const [me, setMe] = useState(user);
  const [err, setErr] = useState('');
  const [settings, save] = useSettings();
  const [count, setCount] = useState(() => {
    const h = loadHistory(user.id);
    return h.profiles.length + h.courses.length + h.reviews.length;
  });

  useEffect(() => {
    let alive = true;
    fetchMe().then((u) => { if (alive && u) setMe(u); }).catch((e) => alive && setErr(e.message));
    return () => { alive = false; };
  }, []);

  const clear = () => {
    if (!count) return;
    clearHistory(user.id);
    setCount(0);
  };

  return (
    <main className="page narrow">
      <div className="stack">
        <header className="page-head" style={{ paddingBottom: 0 }}>
          <div className="row" style={{ gap: 14 }}>
            <span className="avatar" aria-hidden="true" style={{ width: 52, height: 52, fontSize: '1.2rem' }}>{(me.name || '?').slice(0, 1)}</span>
            <div>
              <h1 style={{ fontSize: '1.4rem' }}>{me.name}</h1>
              <p className="small">{me.email} · {ROLE_LABEL[me.role] ?? me.role}</p>
            </div>
          </div>
        </header>
        <section className="section" style={{ borderTop: 0, paddingTop: 0 }}>
          <div className="section-head"><h2>계정 정보</h2></div>
          <dl className="info">
            <dt>이름</dt><dd>{me.name}</dd>
            <dt>이메일</dt><dd>{me.email}</dd>
            <dt>계정 종류</dt><dd>{ROLE_LABEL[me.role] ?? me.role}</dd>
            <dt>상태</dt><dd>{STATUS_LABEL[me.status] ?? me.status ?? '-'}</dd>
            {me.storeId && <><dt>가게 ID</dt><dd>{me.storeId}</dd></>}
            <dt>회원 번호</dt><dd className="num">{me.id}</dd>
          </dl>
          {err && <p className="small" style={{ color: 'var(--bad)' }}>최신 정보를 불러오지 못했어요: {err}</p>}
          {isMock && <p className="small muted">목업 모드라 이 기기에 저장된 정보예요.</p>}
        </section>

        <section className="section">
          <div className="section-head"><h2>화면 설정</h2></div>
          <label className="field">
            <span className="row between"><span>화면 밝기</span><span className="num muted">{settings.brightness}%</span></span>
            <input className="range" type="range" min={BRIGHTNESS_MIN} max={100} step={5} value={settings.brightness}
                   onChange={(e) => save({ brightness: Number(e.target.value) })} aria-label="화면 밝기" />
          </label>
          <div className="row between">
            <span className="small muted">밤에 보기 편하게 화면을 어둡게 할 수 있어요. 이 기기에 저장돼요.</span>
            <button className="btn sm" disabled={settings.brightness === 100} onClick={() => save({ brightness: 100 })}>원래 밝기</button>
          </div>
        </section>

        <section className="section">
          <div className="row between">
            <div>
              <h2 style={{ fontSize: '1.15rem' }}>내 여행 기록</h2>
              <p className="small muted">성향 테스트·코스·평가 기록 {count}건이 이 기기에 저장돼 있어요.</p>
            </div>
            <button className="btn sm" disabled={!count} onClick={clear}>기록 지우기</button>
          </div>
        </section>

        <button className="btn ghost" style={{ alignSelf: 'flex-start' }} onClick={logout}>로그아웃</button>
      </div>
    </main>
  );
}
