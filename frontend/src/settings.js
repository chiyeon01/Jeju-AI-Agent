// ─────────────────────────────────────────────
// 화면 설정 (이 기기에 저장). 지금은 화면 밝기만 있습니다.
// 밝기는 화면 전체에 어두운 막을 씌워 낮춥니다 (100% = 원래 밝기).
// ─────────────────────────────────────────────
import { useEffect, useState } from 'react';

const KEY = 'jeju-settings';
export const BRIGHTNESS_MIN = 40;
const DEFAULTS = { brightness: 100 };
const listeners = new Set();

export function loadSettings() {
  try { return { ...DEFAULTS, ...JSON.parse(localStorage.getItem(KEY) || '{}') }; } catch { return { ...DEFAULTS }; }
}

export function applySettings(s = loadSettings()) {
  if (typeof document === 'undefined') return;
  const b = Math.min(100, Math.max(BRIGHTNESS_MIN, Number(s.brightness) || 100));
  document.documentElement.style.setProperty('--dim', String((100 - b) / 100));
}

export function saveSettings(patch) {
  const next = { ...loadSettings(), ...patch };
  try { localStorage.setItem(KEY, JSON.stringify(next)); } catch { /* 저장 불가 */ }
  applySettings(next);
  listeners.forEach((fn) => fn(next));
  return next;
}

export function useSettings() {
  const [s, setS] = useState(loadSettings);
  useEffect(() => { listeners.add(setS); return () => listeners.delete(setS); }, []);
  return [s, saveSettings];
}
