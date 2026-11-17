// ─────────────────────────────────────────────
// 왼쪽 위 뒤로가기 버튼
//  1) 화면이 useBackHandler(fn) 로 단계 뒤로가기를 등록했으면 그걸 부릅니다 (예: 여행 코스 3단계 → 2단계)
//  2) 아니면 브라우저 기록에서 한 칸 뒤로 갑니다
//  3) 돌아갈 곳이 없으면 fallback 경로로 갑니다 (없으면 버튼을 흐리게)
// ─────────────────────────────────────────────
import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';

const BackContext = createContext(null);

export function BackProvider({ children }) {
  // 등록된 단계 뒤로가기들. 가장 나중에 등록된 것을 씁니다
  const [stack, setStack] = useState([]);
  const value = useMemo(() => ({
    handler: stack.length ? stack[stack.length - 1].fn : null,
    add: (entry) => setStack((s) => [...s, entry]),
    remove: (entry) => setStack((s) => s.filter((e) => e !== entry)),
  }), [stack]);
  return <BackContext.Provider value={value}>{children}</BackContext.Provider>;
}

/** 화면 안 단계 뒤로가기를 등록합니다. fn 이 null 이면 등록하지 않습니다. fn 은 useCallback 으로 고정해 주세요 */
export function useBackHandler(fn) {
  const ctx = useContext(BackContext);
  const add = ctx?.add, remove = ctx?.remove;
  useEffect(() => {
    if (!add || !fn) return undefined;
    const entry = { fn };
    add(entry);
    return () => remove(entry);
    // add/remove 는 목록이 바뀔 때마다 새로 만들어지지만 하는 일은 같으므로 fn 만 봅니다
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fn]);
}

const canGoBack = () => (window.history.state?.idx ?? 0) > 0;

export default function BackButton({ fallback }) {
  const ctx = useContext(BackContext);
  const navigate = useNavigate();
  const handler = ctx?.handler;
  const enabled = Boolean(handler) || canGoBack() || Boolean(fallback);
  const onClick = () => {
    if (handler) return handler();
    if (canGoBack()) return navigate(-1);
    if (fallback) return navigate(fallback);
    return undefined;
  };
  return (
    <button type="button" className="back-btn" onClick={onClick} disabled={!enabled} aria-label="뒤로가기" title="뒤로가기">
      <svg width="22" height="22" viewBox="0 0 24 24" aria-hidden="true"><path d="M15 5l-7 7 7 7" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" /></svg>
    </button>
  );
}
