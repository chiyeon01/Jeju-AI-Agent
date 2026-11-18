// 화면 폭이 작은지(모바일·앱뷰) 알려 주는 훅. CSS 의 @media (max-width: 720px) 와 같은 기준입니다.
import { useEffect, useState } from 'react';

const QUERY = '(max-width: 720px)';

export default function useIsMobile() {
  const [m, setM] = useState(() => typeof window !== 'undefined' && window.matchMedia(QUERY).matches);
  useEffect(() => {
    const mq = window.matchMedia(QUERY);
    const on = () => setM(mq.matches);
    mq.addEventListener('change', on);
    return () => mq.removeEventListener('change', on);
  }, []);
  return m;
}
