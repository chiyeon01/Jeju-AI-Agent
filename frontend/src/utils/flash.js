// 화면을 옮긴 뒤 한 번 보여 줄 짧은 안내 (예: "평가를 보냈어요"). 이 탭에만 잠깐 저장합니다.
const KEY = 'jeju-flash';
export function setFlash(text) { try { sessionStorage.setItem(KEY, text); } catch { /* 저장 불가 */ } }
export function takeFlash() {
  try { const t = sessionStorage.getItem(KEY); sessionStorage.removeItem(KEY); return t; } catch { return null; }
}
