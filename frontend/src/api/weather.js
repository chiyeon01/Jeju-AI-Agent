// ─────────────────────────────────────────────
// 실시간 날씨. 화면은 getLiveWeather(lat, lon) 하나만 부릅니다.
//  1) VITE_KMA_SERVICE_KEY 가 있으면 기상청 초단기실황 (공공데이터포털)
//  2) 키가 없거나 실패하면 Open-Meteo (키 필요 없음)
//  3) 둘 다 실패하면 null → 화면은 목업 날씨를 씁니다
// 결과: { code: 'clear'|'rain', label, icon, temp, humidity, wind, rain1h, source, at }
// ─────────────────────────────────────────────
import { config } from '../config.js';

/** 위경도 → 기상청 격자(nx, ny). 기상청 동네예보 격자 변환 공식(LCC) */
export function toKmaGrid(lat, lon) {
  const RE = 6371.00877, GRID = 5.0, SLAT1 = 30.0, SLAT2 = 60.0, OLON = 126.0, OLAT = 38.0, XO = 43, YO = 136;
  const D = Math.PI / 180.0;
  const re = RE / GRID, slat1 = SLAT1 * D, slat2 = SLAT2 * D, olon = OLON * D, olat = OLAT * D;
  let sn = Math.tan(Math.PI * 0.25 + slat2 * 0.5) / Math.tan(Math.PI * 0.25 + slat1 * 0.5);
  sn = Math.log(Math.cos(slat1) / Math.cos(slat2)) / Math.log(sn);
  let sf = Math.tan(Math.PI * 0.25 + slat1 * 0.5);
  sf = (Math.pow(sf, sn) * Math.cos(slat1)) / sn;
  let ro = Math.tan(Math.PI * 0.25 + olat * 0.5);
  ro = (re * sf) / Math.pow(ro, sn);
  let ra = Math.tan(Math.PI * 0.25 + lat * D * 0.5);
  ra = (re * sf) / Math.pow(ra, sn);
  let theta = lon * D - olon;
  if (theta > Math.PI) theta -= 2.0 * Math.PI;
  if (theta < -Math.PI) theta += 2.0 * Math.PI;
  theta *= sn;
  return { nx: Math.floor(ra * Math.sin(theta) + XO + 0.5), ny: Math.floor(ro - ra * Math.cos(theta) + YO + 0.5) };
}

/** 초단기실황 발표 기준 시각 (매시 정각 자료가 약 40분 뒤 올라오므로 그 전이면 한 시간 전) */
export function kmaBaseTime(now = new Date()) {
  const kst = new Date(now.getTime() + 9 * 3600 * 1000 - 40 * 60 * 1000);
  const p = (n) => String(n).padStart(2, '0');
  return {
    base_date: `${kst.getUTCFullYear()}${p(kst.getUTCMonth() + 1)}${p(kst.getUTCDate())}`,
    base_time: `${p(kst.getUTCHours())}00`,
  };
}

// 이미 인코딩된 키(%2B 등 포함)를 넣어도, 디코딩 키를 넣어도 동작하게 합니다
const keyParam = (k) => (/%[0-9A-Fa-f]{2}/.test(k) ? k : encodeURIComponent(k));

const PTY = { 0: '없음', 1: '비', 2: '비/눈', 3: '눈', 5: '빗방울', 6: '빗방울눈날림', 7: '눈날림' };

async function fromKma(lat, lon) {
  const { nx, ny } = toKmaGrid(lat, lon);
  const { base_date, base_time } = kmaBaseTime();
  const url = `${config.kmaBaseUrl}/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst`
    + `?serviceKey=${keyParam(config.kmaServiceKey)}&pageNo=1&numOfRows=10&dataType=JSON`
    + `&base_date=${base_date}&base_time=${base_time}&nx=${nx}&ny=${ny}`;
  const res = await fetch(url);
  const text = await res.text();
  let body;
  try { body = JSON.parse(text); } catch { throw new Error(`기상청 응답이 JSON 이 아니에요 (키 확인 필요): ${text.slice(0, 120)}`); }
  const head = body?.response?.header;
  if (head?.resultCode !== '00') throw new Error(`기상청 오류 ${head?.resultCode}: ${head?.resultMsg}`);
  const v = Object.fromEntries((body.response.body.items.item ?? []).map((i) => [i.category, Number(i.obsrValue)]));
  const pty = v.PTY ?? 0;
  const snow = pty === 3 || pty === 7;
  return {
    code: pty > 0 ? 'rain' : 'clear',
    label: pty > 0 ? PTY[pty] ?? '비' : '맑음',
    icon: pty > 0 ? (snow ? '🌨️' : '🌧️') : '☀️',
    temp: v.T1H, humidity: v.REH, wind: v.WSD, rain1h: v.RN1 ?? 0,
    source: '기상청', at: `${base_time.slice(0, 2)}:00`,
  };
}

function wmo(code) {
  if (code === 0) return ['맑음', '☀️', 'clear'];
  if (code <= 3) return ['구름 조금', '⛅', 'clear'];
  if (code === 45 || code === 48) return ['안개', '🌫️', 'clear'];
  if (code >= 71 && code <= 77) return ['눈', '🌨️', 'rain'];
  if (code === 85 || code === 86) return ['눈', '🌨️', 'rain'];
  if (code >= 95) return ['뇌우', '⛈️', 'rain'];
  return ['비', '🌧️', 'rain'];
}

async function fromOpenMeteo(lat, lon) {
  const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}`
    + '&current=temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m'
    + '&wind_speed_unit=ms&timezone=Asia%2FSeoul';
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Open-Meteo ${res.status}`);
  const c = (await res.json()).current;
  const [label, icon, code] = wmo(c.weather_code);
  return {
    code, label, icon,
    temp: c.temperature_2m, humidity: c.relative_humidity_2m, wind: c.wind_speed_10m, rain1h: c.precipitation ?? 0,
    source: 'Open-Meteo', at: String(c.time ?? '').slice(11, 16),
  };
}

/** 지금 날씨. 실패하면 null */
export async function getLiveWeather(lat, lon) {
  if (lat == null || lon == null) return null;
  if (config.kmaServiceKey) {
    try { return await fromKma(lat, lon); } catch (e) { console.warn('[weather] 기상청 실패, Open-Meteo 로 대신합니다:', e.message); }
  }
  try { return await fromOpenMeteo(lat, lon); } catch (e) { console.warn('[weather] 실시간 날씨를 가져오지 못했어요:', e.message); }
  return null;
}

/** 화면 한 줄 요약 */
export function weatherLine(w) {
  const parts = [`${w.icon} ${w.label} ${Math.round(w.temp * 10) / 10}°C`];
  if (w.humidity != null) parts.push(`습도 ${w.humidity}%`);
  if (w.wind != null) parts.push(`풍속 ${w.wind}m/s`);
  if (w.rain1h > 0) parts.push(`1시간 강수 ${w.rain1h}mm`);
  return `${parts.join(' · ')} (실시간 ${w.source}${w.at ? `, ${w.at} 기준` : ''})`;
}
