import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jeju_ai_agent/api/weather.dart';

void main() {
  test('위경도를 기상청 격자로 바꾼다', () {
    expect(toKmaGrid(37.5665, 126.978), (nx: 60, ny: 127)); // 서울
    expect(toKmaGrid(33.4996, 126.5312), (nx: 53, ny: 38)); // 제주시
  });

  test('발표 기준 시각은 40분 전 정시', () {
    expect(kmaBaseTime(DateTime.utc(2026, 11, 17, 0, 30)), (date: '20261117', time: '0800'));
    expect(kmaBaseTime(DateTime.utc(2026, 11, 16, 15, 10)), (date: '20261116', time: '2300'));
  });

  final openMeteo = jsonEncode({'current': {'time': '2026-11-17T09:45', 'temperature_2m': 15.2, 'relative_humidity_2m': 60, 'precipitation': 0, 'weather_code': 2, 'wind_speed_10m': 3.4}});

  test('기상청 키가 있으면 기상청 초단기실황을 쓴다', () async {
    final urls = <Uri>[];
    final c = MockClient((r) async {
      urls.add(r.url);
      return http.Response.bytes(utf8.encode(jsonEncode({'response': {'header': {'resultCode': '00'}, 'body': {'items': {'item': [
        {'category': 'T1H', 'obsrValue': '11.8'}, {'category': 'PTY', 'obsrValue': '1'}, {'category': 'REH', 'obsrValue': '85'},
        {'category': 'WSD', 'obsrValue': '5.2'}, {'category': 'RN1', 'obsrValue': '1.5'}]}}}})), 200);
    });
    final w = (await getLiveWeather(33.46, 126.31, client: c, kmaKey: 'abc+/='))!;
    expect(w.source, '기상청');
    expect(w.code, 'rain');
    expect(w.line, startsWith('🌧️ 비 11.8°C · 습도 85% · 풍속 5.2m/s · 1시간 강수 1.5mm'));
    expect(urls.single.toString(), contains('serviceKey=abc%2B%2F%3D&'));
  });

  test('키가 틀리면 Open-Meteo 로 대신한다', () async {
    final c = MockClient((r) async => r.url.host == 'apis.data.go.kr'
        ? http.Response('<OpenAPI_ServiceResponse>SERVICE_KEY_IS_NOT_REGISTERED_ERROR</OpenAPI_ServiceResponse>', 200)
        : http.Response(openMeteo, 200));
    final w = (await getLiveWeather(33.46, 126.31, client: c, kmaKey: 'bad'))!;
    expect(w.source, 'Open-Meteo');
    expect(w.code, 'clear');
    expect(w.line, '⛅ 구름 조금 15.2°C · 습도 60% · 풍속 3.4m/s (실시간 Open-Meteo, 09:45 기준)');
  });

  test('키가 없으면 바로 Open-Meteo, 둘 다 실패하면 null', () async {
    final hosts = <String>[];
    final ok = MockClient((r) async { hosts.add(r.url.host); return http.Response(openMeteo, 200); });
    expect((await getLiveWeather(33.46, 126.31, client: ok, kmaKey: ''))!.source, 'Open-Meteo');
    expect(hosts, ['api.open-meteo.com']);
    final fail = MockClient((r) async => http.Response('down', 503));
    expect(await getLiveWeather(33.46, 126.31, client: fail, kmaKey: ''), isNull);
  });
}
