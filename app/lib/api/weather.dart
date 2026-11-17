// ─────────────────────────────────────────────
// 실시간 날씨. 화면은 getLiveWeather(lat, lon) 하나만 부릅니다. (React 의 src/api/weather.js 와 같은 구조)
//  1) 백엔드 GET /weather/now (서버가 기상청 → Open-Meteo 순으로 가져옴)
//  2) 백엔드가 안 되면 앱에서 직접: KMA_SERVICE_KEY 가 있으면 기상청, 아니면 Open-Meteo
//  3) 모두 실패하면 null → 화면은 "다시 불러오기"를 보여 줍니다
// ─────────────────────────────────────────────
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'client.dart' show isMock, serverWeather;

class LiveWeather {
  const LiveWeather({required this.code, required this.label, required this.icon, required this.temp,
      this.humidity, this.wind, this.rain1h = 0, required this.source, this.at = ''});

  /// 'clear' | 'rain' (코스 옵션과 같은 코드)
  final String code, label, icon, source, at;
  final double temp;
  final double? humidity, wind;
  final double rain1h;

  String get line {
    final parts = ['$icon $label ${_n(temp)}°C'];
    if (humidity != null) parts.add('습도 ${_n(humidity!)}%');
    if (wind != null) parts.add('풍속 ${_n(wind!)}m/s');
    if (rain1h > 0) parts.add('1시간 강수 ${_n(rain1h)}mm');
    return '${parts.join(' · ')} (실시간 $source${at.isEmpty ? '' : ', $at 기준'})';
  }

  static String _n(double v) => fmtNum(v);
}

/// 12.0 → "12", 12.34 → "12.3"
String fmtNum(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// 위경도 → 기상청 격자(nx, ny). 기상청 동네예보 격자 변환 공식(LCC)
({int nx, int ny}) toKmaGrid(double lat, double lon) {
  const re0 = 6371.00877, grid = 5.0, slat1d = 30.0, slat2d = 60.0, olond = 126.0, olatd = 38.0, xo = 43, yo = 136;
  const d = math.pi / 180.0;
  final re = re0 / grid, slat1 = slat1d * d, slat2 = slat2d * d, olon = olond * d, olat = olatd * d;
  var sn = math.tan(math.pi * 0.25 + slat2 * 0.5) / math.tan(math.pi * 0.25 + slat1 * 0.5);
  sn = math.log(math.cos(slat1) / math.cos(slat2)) / math.log(sn);
  var sf = math.tan(math.pi * 0.25 + slat1 * 0.5);
  sf = math.pow(sf, sn) * math.cos(slat1) / sn;
  var ro = math.tan(math.pi * 0.25 + olat * 0.5);
  ro = re * sf / math.pow(ro, sn);
  var ra = math.tan(math.pi * 0.25 + lat * d * 0.5);
  ra = re * sf / math.pow(ra, sn);
  var theta = lon * d - olon;
  if (theta > math.pi) theta -= 2.0 * math.pi;
  if (theta < -math.pi) theta += 2.0 * math.pi;
  theta *= sn;
  return (nx: (ra * math.sin(theta) + xo + 0.5).floor(), ny: (ro - ra * math.cos(theta) + yo + 0.5).floor());
}

/// 초단기실황 발표 기준 시각 (매시 정각 자료가 약 40분 뒤 올라오므로 그 전이면 한 시간 전)
({String date, String time}) kmaBaseTime([DateTime? now]) {
  final k = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 9, minutes: -40));
  String p(int n) => n.toString().padLeft(2, '0');
  return (date: '${k.year}${p(k.month)}${p(k.day)}', time: '${p(k.hour)}00');
}

const _pty = {1: '비', 2: '비/눈', 3: '눈', 5: '빗방울', 6: '빗방울눈날림', 7: '눈날림'};

Future<LiveWeather> _fromKma(http.Client c, String key, double lat, double lon) async {
  final g = toKmaGrid(lat, lon);
  final b = kmaBaseTime();
  // 이미 인코딩된 키(%2B 등)를 넣어도, 디코딩 키를 넣어도 동작하게 합니다
  final k = RegExp(r'%[0-9A-Fa-f]{2}').hasMatch(key) ? key : Uri.encodeQueryComponent(key);
  final url = Uri.parse('https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst'
      '?serviceKey=$k&pageNo=1&numOfRows=10&dataType=JSON&base_date=${b.date}&base_time=${b.time}&nx=${g.nx}&ny=${g.ny}');
  final res = await c.get(url).timeout(const Duration(seconds: 8));
  final Map<String, dynamic> body;
  try {
    body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  } on FormatException {
    throw Exception('기상청 응답이 JSON 이 아니에요 (키 확인 필요): ${res.body.substring(0, math.min(120, res.body.length))}');
  }
  final head = body['response']?['header'];
  if (head?['resultCode'] != '00') throw Exception('기상청 오류 ${head?['resultCode']}: ${head?['resultMsg']}');
  final items = (body['response']['body']['items']['item'] as List).cast<Map<String, dynamic>>();
  final v = {for (final i in items) i['category'] as String: double.tryParse('${i['obsrValue']}') ?? 0};
  final pty = (v['PTY'] ?? 0).toInt();
  final snow = pty == 3 || pty == 7;
  return LiveWeather(
    code: pty > 0 ? 'rain' : 'clear',
    label: pty > 0 ? _pty[pty] ?? '비' : '맑음',
    icon: pty > 0 ? (snow ? '🌨️' : '🌧️') : '☀️',
    temp: v['T1H'] ?? 0, humidity: v['REH'], wind: v['WSD'], rain1h: v['RN1'] ?? 0,
    source: '기상청', at: '${b.time.substring(0, 2)}:00',
  );
}

(String, String, String) _wmo(int c) {
  if (c == 0) return ('맑음', '☀️', 'clear');
  if (c <= 3) return ('구름 조금', '⛅', 'clear');
  if (c == 45 || c == 48) return ('안개', '🌫️', 'clear');
  if ((c >= 71 && c <= 77) || c == 85 || c == 86) return ('눈', '🌨️', 'rain');
  if (c >= 95) return ('뇌우', '⛈️', 'rain');
  return ('비', '🌧️', 'rain');
}

Future<LiveWeather> _fromOpenMeteo(http.Client c, double lat, double lon) async {
  final url = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m'
      '&wind_speed_unit=ms&timezone=Asia%2FSeoul');
  final res = await c.get(url).timeout(const Duration(seconds: 8));
  if (res.statusCode != 200) throw Exception('Open-Meteo ${res.statusCode}');
  final cur = (jsonDecode(res.body) as Map<String, dynamic>)['current'] as Map<String, dynamic>;
  final (label, icon, code) = _wmo((cur['weather_code'] as num).toInt());
  final time = '${cur['time'] ?? ''}';
  return LiveWeather(
    code: code, label: label, icon: icon,
    temp: (cur['temperature_2m'] as num).toDouble(),
    humidity: (cur['relative_humidity_2m'] as num?)?.toDouble(),
    wind: (cur['wind_speed_10m'] as num?)?.toDouble(),
    rain1h: (cur['precipitation'] as num?)?.toDouble() ?? 0,
    source: 'Open-Meteo', at: time.length >= 16 ? time.substring(11, 16) : '',
  );
}

LiveWeather liveWeatherFromJson(Map<String, dynamic> j) => LiveWeather(
      code: j['code'] ?? 'clear', label: j['label'] ?? '', icon: j['icon'] ?? '',
      temp: (j['temp'] as num?)?.toDouble() ?? 0,
      humidity: (j['humidity'] as num?)?.toDouble(), wind: (j['wind'] as num?)?.toDouble(),
      rain1h: (j['rain1h'] as num?)?.toDouble() ?? 0, source: j['source'] ?? '', at: j['at'] ?? '');

/// 지금 날씨. 실패하면 null. 테스트에서는 client 와 kmaKey 를 넘길 수 있습니다 (그때는 백엔드를 건너뜀)
Future<LiveWeather?> getLiveWeather(double lat, double lon, {http.Client? client, String? kmaKey}) async {
  if (!isMock && client == null) {
    try {
      return liveWeatherFromJson(await serverWeather(lat, lon));
    } catch (e) {
      debugPrint('[weather] 서버 날씨 실패, 앱에서 직접 가져옵니다: $e');
    }
  }
  final c = client ?? http.Client();
  final key = (kmaKey ?? AppConfig.kmaServiceKey).trim();
  try {
    if (key.isNotEmpty) {
      try {
        return await _fromKma(c, key, lat, lon);
      } catch (e) {
        debugPrint('[weather] 기상청 실패, Open-Meteo 로 대신합니다: $e');
      }
    }
    try {
      return await _fromOpenMeteo(c, lat, lon);
    } catch (e) {
      debugPrint('[weather] 실시간 날씨를 가져오지 못했어요: $e');
    }
    return null;
  } finally {
    if (client == null) c.close();
  }
}
