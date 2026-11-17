// ─────────────────────────────────────────────
// API 클라이언트 (React 의 src/api/client.js 와 같은 구조)
// 화면은 이 파일의 함수만 사용합니다.
// AppConfig.useMock=true 이면 목업 응답, false 이면 백엔드(AppConfig.apiBaseUrl)를 호출합니다.
// 엔드포인트·응답 형식은 「제주잇다 BE 연동 명세」 PDF 와 같습니다.
// ─────────────────────────────────────────────
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../data/auth_mock.dart';
import '../data/console_mock.dart' as cm;
import '../data/owner_mock.dart' as om;
import '../data/tourist_mock.dart';
import 'hub.dart';

const bool isMock = AppConfig.useMock;
Future<void> _wait(int ms) => Future.delayed(Duration(milliseconds: ms));
typedef Json = Map<String, dynamic>;

// ── 로그인 정보 ─────────────────────────────
/// 로그인한 사용자. role: USER | MERCHANT | ADMIN
class AppUser {
  const AppUser({required this.id, required this.email, required this.name, required this.role, this.status = 'ACTIVE', this.storeId});
  final String id, email, name, role, status;
  final String? storeId;

  factory AppUser.fromJson(Json j) => AppUser(
        id: '${j['id']}',
        email: j['email'] ?? '',
        name: j['name'] ?? '',
        role: j['role'] ?? 'USER',
        status: j['status'] ?? 'ACTIVE',
        storeId: j['storeId'],
      );
  Json toJson() => {'id': id, 'email': email, 'name': name, 'role': role, 'status': status, 'storeId': storeId};
}

class _Session {
  _Session(this.accessToken, this.refreshToken, this.user);
  String accessToken, refreshToken;
  AppUser user;
  Json toJson() => {'accessToken': accessToken, 'refreshToken': refreshToken, 'user': user.toJson()};
}

const _key = 'itda-auth';
_Session? _session;

/// 앱 시작 때 저장된 로그인 정보를 읽습니다.
Future<AppUser?> loadSession() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Json;
    _session = _Session(j['accessToken'], j['refreshToken'], AppUser.fromJson(j['user']));
    return _session!.user;
  } catch (_) {
    return null;
  }
}

Future<void> _save(_Session? s) async {
  _session = s;
  try {
    final prefs = await SharedPreferences.getInstance();
    s == null ? await prefs.remove(_key) : await prefs.setString(_key, jsonEncode(s.toJson()));
  } catch (_) {
    // 저장 불가 환경
  }
}

/// 토큰 갱신까지 실패했을 때 부를 함수 (AuthController 가 등록)
void Function() onUnauthorized = () {};

class ApiError implements Exception {
  ApiError(this.status, this.code, this.message);
  final int status;
  final String code, message;
  @override
  String toString() => message;
}

Future<dynamic> _request(String method, String path, [Object? body, bool retry = true]) async {
  final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
  final headers = {
    'Content-Type': 'application/json',
    if (_session != null) 'Authorization': 'Bearer ${_session!.accessToken}',
  };
  final req = http.Request(method, uri)..headers.addAll(headers);
  if (body != null) req.body = jsonEncode(body);
  final res = await http.Response.fromStream(await req.send());

  if (res.statusCode == 401 && retry && _session != null && !path.startsWith('/auth/')) {
    // 액세스 토큰 만료 → 리프레시 후 한 번 더 시도
    final r = await http.post(Uri.parse('${AppConfig.apiBaseUrl}/auth/refresh'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'refreshToken': _session!.refreshToken}));
    if (r.statusCode == 200) {
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Json;
      _session!.accessToken = j['accessToken'];
      if (j['refreshToken'] != null) _session!.refreshToken = j['refreshToken'];
      await _save(_session);
      return _request(method, path, body, false);
    }
    await _save(null);
    onUnauthorized();
    throw ApiError(401, 'UNAUTHORIZED', '로그인이 만료됐어요. 다시 로그인해 주세요.');
  }
  if (res.statusCode < 200 || res.statusCode >= 300) {
    Json err = {};
    try {
      err = (jsonDecode(utf8.decode(res.bodyBytes)) as Json)['error'] ?? {};
    } catch (_) {}
    throw ApiError(res.statusCode, err['code'] ?? 'HTTP_ERROR', err['message'] ?? '서버 응답 오류 (${res.statusCode})');
  }
  if (res.statusCode == 204 || res.bodyBytes.isEmpty) return null;
  return jsonDecode(utf8.decode(res.bodyBytes));
}

Future<dynamic> _get(String p) => _request('GET', p);
Future<dynamic> _post(String p, [Object? b]) => _request('POST', p, b ?? const {});
Future<dynamic> _patch(String p, [Object? b]) => _request('PATCH', p, b ?? const {});

// ── 인증 ───────────────────────────────────
/// POST /auth/login → { accessToken, refreshToken, user }
Future<AppUser> login(String email, String password) async {
  _Session s;
  if (!isMock) {
    final j = await _post('/auth/login', {'email': email, 'password': password}) as Json;
    s = _Session(j['accessToken'], j['refreshToken'], AppUser.fromJson(j['user']));
  } else {
    await _wait(400);
    final em = email.trim().toLowerCase();
    final local = _mockAccounts[em];
    final demo = demoAccounts.where((a) => a['email'] == em).firstOrNull;
    final Json? u = local != null && local.$1 == password ? local.$2 : demo != null && password == demoPassword ? demo : null;
    if (u == null) throw ApiError(401, 'INVALID_CREDENTIALS', '이메일 또는 비밀번호가 맞지 않아요.');
    if (u['status'] == 'PENDING') throw ApiError(403, 'ACCOUNT_PENDING', '관리자 승인 후 이용할 수 있어요.');
    s = _Session('mock-access', 'mock-refresh', AppUser.fromJson(u));
  }
  await _save(s);
  return s.user;
}

/// POST /auth/signup → { user } (상권 주인은 관리자 승인 전까지 status=PENDING)
Future<AppUser> signup(Json form) async {
  if (!isMock) return AppUser.fromJson((await _post('/auth/signup', form) as Json)['user']);
  await _wait(500);
  final email = '${form['email']}';
  if (demoAccounts.any((a) => a['email'] == email) || _mockAccounts.containsKey(email)) {
    throw ApiError(409, 'EMAIL_TAKEN', '이미 가입된 이메일이에요.');
  }
  final user = <String, dynamic>{...form, 'id': 'u-${DateTime.now().millisecondsSinceEpoch}', 'status': form['role'] == 'MERCHANT' ? 'PENDING' : 'ACTIVE'}
    ..remove('password');
  _mockAccounts[email] = ('${form['password']}', user);
  return AppUser.fromJson(user);
}

// 목업 모드에서 회원가입한 계정 (앱을 끄면 사라짐, 백엔드 모드에서는 쓰지 않음)
final _mockAccounts = <String, (String, Json)>{};

/// GET /auth/me (목업이면 저장된 로그인 정보)
Future<AppUser?> fetchMe() async {
  if (isMock) return _session?.user;
  return AppUser.fromJson(await _get('/auth/me') as Json);
}

/// POST /auth/logout
Future<void> logout() async {
  if (!isMock && _session != null) {
    try {
      await _post('/auth/logout', {'refreshToken': _session!.refreshToken});
    } catch (_) {}
  }
  await _save(null);
}

// ── 관광객 ─────────────────────────────────
double _km(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// GET /regions
Future<List<Region>> getRegions() async {
  if (!isMock) return [for (final r in await _get('/regions') as List) Region.fromJson(r)];
  return regions;
}

/// GET /regions/nearest?lat=&lon=
Future<Region> nearestRegion(double lat, double lon) async {
  if (!isMock) return Region.fromJson(await _get('/regions/nearest?lat=$lat&lon=$lon'));
  return ([...regions]..sort((a, b) => _km(a.lat, a.lon, lat, lon).compareTo(_km(b.lat, b.lon, lat, lon)))).first;
}

/// POST /tourist/profile
Future<Profile> analyzeProfile(Map<int, String> answers, TripExtra extra) async {
  if (!isMock) {
    return Profile.fromJson(await _post('/tourist/profile', {
      'answers': answers.map((k, v) => MapEntry('$k', v)),
      ...extra.toJson(),
    }));
  }
  await _wait(500);
  return scoreAnswers(answers, extra);
}

/// 코스의 한 장소 (도착 시각 at, 앞 장소에서 이동 시간 move 분)
class Stop {
  const Stop(this.place, this.at, this.move, {this.why});
  final Place place;
  final String at;
  final int move;

  /// GPT 가 이 장소를 고른 이유 (있으면 데이터 근거보다 먼저 보여 줍니다)
  final String? why;
}

class Course {
  const Course(this.weather, this.stops, {this.summary = '', this.source = 'rule'});
  final String weather;
  final List<Stop> stops;

  /// GPT 가 쓴 코스 소개 (없으면 빈 문자열)
  final String summary;

  /// 'gpt' | 'rule'
  final String source;
}

/// 코스 옵션 (대화로 바뀌는 값)
class CourseOpts {
  const CourseOpts({this.weather = 'clear', this.seafood = false, this.removeCount = 0});
  final String weather;
  final bool seafood;
  final int removeCount;

  CourseOpts copyWith({String? weather, bool? seafood, int? removeCount}) => CourseOpts(
        weather: weather ?? this.weather,
        seafood: seafood ?? this.seafood,
        removeCount: removeCount ?? this.removeCount,
      );
}

final _rand = math.Random();

/// POST /tourist/course
Future<Course> planCourse({required Profile profile, required Region origin, required CourseOpts opts}) async {
  if (!isMock) {
    final j = await _post('/tourist/course', {
      'profile': profile.toJson(),
      'regionId': origin.id,
      'startTime': profile.startTime,
      'hours': profile.extra.hours,
      'weather': opts.weather,
      'options': {'seafood': opts.seafood, 'removeCount': opts.removeCount},
    }) as Json;
    return Course(
      (j['weather'] as Json?)?['code'] ?? opts.weather,
      [for (final s in j['stops'] as List) Stop(Place.fromJson(s), s['at'] ?? '', (s['move'] as num?)?.toInt() ?? 0)],
    );
  }
  await _wait(600);
  final rain = opts.weather == 'rain';
  double d(Place p, double lat, double lon) => _km(p.lat, p.lon, lat, lon);
  final near = [...places]..sort((a, b) => d(a, origin.lat, origin.lon).compareTo(d(b, origin.lat, origin.lon)));
  // 가까운 두 곳 중 하나를 무작위로 골라, 같은 지역이어도 매번 같은 코스가 나오지 않게 합니다
  Place? pick(List<String> kinds, Set<String> used, [bool Function(Place)? pred]) {
    final top = near.where((p) => kinds.contains(p.kind) && !used.contains(p.id) && (pred == null || pred(p))).take(2).toList();
    return top.isEmpty ? null : top[_rand.nextInt(top.length)];
  }

  final order = rain ? [['cafe'], ['indoor'], ['indoor', 'cafe'], ['food']] : [['cafe'], ['spot'], ['sunset'], ['food']];
  final used = <String>{};
  final stops = <Place>[];
  for (final kinds in order) {
    final bool Function(Place) pred = kinds.contains('food') && opts.seafood
        ? (p) => p.seafood
        : rain
            ? (p) => p.indoor
            : (p) => true;
    final p = pick(kinds, used, pred) ?? pick(kinds, used);
    if (p != null) {
      used.add(p.id);
      stops.add(p);
    }
  }
  final trimmed = stops.sublist(0, math.min(stops.length, math.max(2, stops.length - opts.removeCount)));
  final hm = profile.startTime.split(':').map(int.parse).toList();
  var t = hm[0] * 60 + hm[1];
  String fmt(int x) => '${(x ~/ 60).toString().padLeft(2, '0')}:${(x % 60).toString().padLeft(2, '0')}';
  final out = <Stop>[];
  for (var i = 0; i < trimmed.length; i++) {
    final p = trimmed[i];
    // 직선거리(km) × 1.3(도로 보정) ÷ 평균 35km/h + 주차·도보 4분
    final km = i == 0 ? 0.0 : d(p, trimmed[i - 1].lat, trimmed[i - 1].lon) * 1.3;
    final move = i == 0 ? 0 : math.max(5, (km / 35 * 60 + 4).round());
    t += move;
    final at = fmt(t);
    t += p.stay;
    out.add(Stop(p, at, move));
  }
  return Course(opts.weather, out);
}

/// 코스 수정 대화 결과. patch 가 있으면 코스 옵션을 바꿉니다.
class ChatResult {
  const ChatResult(this.reply, this.patch);
  final String reply;
  final ({String? weather, bool? seafood, int removeCount})? patch;
}

/// POST /tourist/course/chat → { reply, patch }
Future<ChatResult> chatCourse(String message) async {
  if (!isMock) {
    final j = await _post('/tourist/course/chat', {'message': message}) as Json;
    final p = j['patch'] as Json?;
    return ChatResult(j['reply'] ?? '',
        p == null ? null : (weather: p['weather'] as String?, seafood: p['seafood'] as bool?, removeCount: (p['removeCount'] as num?)?.toInt() ?? 0));
  }
  await _wait(500);
  if (RegExp('해산물|회|바다 음식').hasMatch(message)) {
    return const ChatResult('저녁을 해산물 식당으로 바꿨어요.', (weather: null, seafood: true, removeCount: 0));
  }
  if (RegExp('줄여|빼|1곳').hasMatch(message)) {
    return const ChatResult('마지막 장소 하나를 뺐어요.', (weather: null, seafood: null, removeCount: 1));
  }
  if (RegExp('비|실내').hasMatch(message)) {
    return const ChatResult('실내 위주 코스로 바꿨어요.', (weather: 'rain', seafood: null, removeCount: 0));
  }
  return const ChatResult('시연 화면에서는 "해산물로 바꿔줘", "1곳 줄여줘", "실내로 바꿔줘"를 알아들어요.', null);
}

// ── 제주데이터허브 (백엔드 /datahub 경유, 키와 원본은 백엔드에만) ──
Future<HubData>? _hubCache;

/// GET /datahub/crowd + /datahub/sights. 실패한 쪽은 null
Future<HubData> getHubData() {
  if (isMock) return Future.value(const HubData());
  Future<Json?> safe(String p) async {
    try {
      return await _get(p) as Json;
    } catch (_) {
      return null;
    }
  }

  return _hubCache ??= Future.wait([safe('/datahub/crowd'), safe('/datahub/sights')]).then((r) {
    final h = HubData(crowd: r[0], sights: r[1]);
    if (h.isEmpty) _hubCache = null; // 실패면 다음에 다시 시도
    return h;
  });
}

/// GET /tourist/ai/status → 서버에 GPT 키와 GPT 중계 API 가 있는지 (없거나 실패하면 false)
Future<bool> aiStatus() async {
  if (isMock || !AppConfig.gptRelay) return false;
  try {
    return ((await _get('/tourist/ai/status')) as Json)['enabled'] == true;
  } catch (_) {
    return false;
  }
}

/// POST /tourist/ai/json — 앱이 만든 프롬프트를 서버의 GPT 키로 보내고 JSON 을 받습니다
Future<Map<String, dynamic>> aiJson(String purpose, String system, String user, double temperature) async =>
    ((await _post('/tourist/ai/json', {'purpose': purpose, 'system': system, 'user': user, 'temperature': temperature})) as Json)['data']
        as Map<String, dynamic>;

/// GET /weather/now — 서버가 대신 가져온 실시간 날씨
Future<Json> serverWeather(double lat, double lon) async =>
    await _get('/weather/now?lat=${lat.toStringAsFixed(4)}&lon=${lon.toStringAsFixed(4)}') as Json;

/// POST /tourist/reviews → { accepted }
Future<int> submitReviews(List<Json> reviews) async {
  if (!isMock) return ((await _post('/tourist/reviews', {'reviews': reviews}) as Json)['accepted'] as num).toInt();
  await _wait(500);
  return reviews.length;
}

// ── 상권 주인 ───────────────────────────────
/// GET /owner/store · score · score/trend · indicators · report/weekly · reviews/topics · reviews
Future<Json> getOwnerDashboard() async {
  if (!isMock) {
    final r = await Future.wait([
      _get('/owner/store'), _get('/owner/score'), _get('/owner/score/trend?weeks=12'), _get('/owner/indicators'),
      _get('/owner/report/weekly'), _get('/owner/reviews/topics'), _get('/owner/reviews?limit=4'),
    ]);
    return {'store': r[0], 'score': r[1], 'trend': r[2], 'indicators': r[3], 'report': r[4], 'topics': r[5], 'reviews': r[6]};
  }
  await _wait(400);
  final s = om.store;
  final n = om.scoreTrend.length;
  return {
    'store': {'id': s.id, 'name': s.name, 'category': s.category, 'dong': s.dong},
    'score': {'score': s.score, 'delta': s.scoreDelta, 'percentile': s.percentile, 'peers': s.peers, 'basis': s.basis},
    'trend': {'values': om.scoreTrend, 'labels': [for (var i = 0; i < n; i++) i == n - 1 ? '이번 주' : '${n - 1 - i}주 전']},
    'indicators': [
      for (final m in om.indicators)
        {'key': m.key, 'name': m.name, 'value': m.value, 'unit': m.unit, 'delta': m.delta, 'good': m.good, 'src': m.src, 'basis': m.basis}
    ],
    'report': {
      'week': om.weeklyWeek,
      'summary': om.weeklySummary,
      'actions': [for (final a in om.weeklyActions) {'title': a.title, 'why': a.why, 'impact': a.impact}],
    },
    'topics': [for (final t in om.reviewTopics) {'topic': t.$1, 'pos': t.$2, 'mentions': t.$3}],
    'reviews': [for (final r in om.recentReviews) {'stars': r.stars, 'text': r.text, 'type': r.type, 'at': r.at}],
  };
}

final ownerSuggestedQuestions = om.ownerQa.keys.toList();

/// POST /owner/ask → { answer }
Future<String> askOwnerAgent(String question) async {
  if (!isMock) return (await _post('/owner/ask', {'question': question}) as Json)['answer'] ?? '';
  await _wait(600);
  return om.ownerQa[question] ?? '시연 화면에서는 예시 질문에 답해요. 백엔드를 연결하면 상권 분석 Agent가 답합니다.';
}

/// POST /owner/actions
Future<void> registerAction(String kind, String title) async {
  if (!isMock) {
    await _post('/owner/actions', {'kind': kind, 'title': title});
    return;
  }
  await _wait(300);
}

// ── 내 가게 별점·리뷰 (관광객 평가 실데이터) ─────
const storeKinds = {'food': '식당', 'cafe': '카페', 'indoor': '실내 체험'};

/// 가게 연결용 장소 [{id, name, region, kind}]
Future<List<Json>> getMerchantPlaces() async {
  if (!isMock) return [for (final p in await _get('/owner/places') as List) p as Json];
  return [for (final p in places.where((p) => storeKinds.containsKey(p.kind))) {'id': p.id, 'name': p.name, 'region': p.region, 'kind': p.kind}];
}

String? _mockLinked;

/// PUT /owner/place {placeId}
Future<void> linkMyPlace(String placeId) async {
  if (!isMock) {
    await _request('PUT', '/owner/place', {'placeId': placeId});
    return;
  }
  _mockLinked = placeId;
}

/// GET /owner/my-reviews → {place, summary:{count, avg, dist, byType[]}, reviews[], regionScore, analysis}. 연결 전이면 null
Future<Json?> getMyReviews() async {
  if (!isMock) {
    try {
      return await _get('/owner/my-reviews') as Json;
    } on ApiError catch (e) {
      if (e.code == 'PLACE_NOT_LINKED') return null;
      rethrow;
    }
  }
  await _wait(300);
  if (_mockLinked == null) return null;
  final p = places.firstWhere((x) => x.id == _mockLinked);
  return {
    'place': {'id': p.id, 'name': p.name, 'region': p.region, 'kind': p.kind},
    'summary': {'count': 0, 'avg': 0, 'dist': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0}, 'byType': []},
    'reviews': [], 'regionScore': null, 'analysis': null,
  };
}

/// POST /owner/my-reviews/analysis → 저장된 분석 {id, title, body, source, createdAt}
Future<Json> analyzeMyReviews() async {
  if (!isMock) return await _post('/owner/my-reviews/analysis') as Json;
  await _wait(500);
  return {'id': 0, 'title': '리뷰 분석', 'body': '## 한 줄 요약\n- 시연 화면이라 실제 리뷰가 없어요.', 'source': 'rule', 'createdAt': DateTime.now().toIso8601String()};
}

// ── 관리자 ─────────────────────────────────
/// GET /admin/overview + GET /admin/regions/health
Future<Json> getAdminOverview() async {
  if (!isMock) {
    final r = await Future.wait([_get('/admin/overview'), _get('/admin/regions/health')]);
    return {'overview': r[0], 'health': r[1]};
  }
  await _wait(300);
  return {
    'overview': {'visits': 9770, 'reviews': 1129, 'courses': 3412, 'eventsPerSec': 42},
    'health': [
      for (final r in regions)
        {
          'regionId': r.id, 'name': r.name, 'lat': r.lat, 'lon': r.lon,
          'score': cm.regionHealth[r.id]!.score, 'visits': cm.regionHealth[r.id]!.visits, 'reviews': cm.regionHealth[r.id]!.reviews,
        }
    ],
  };
}

/// GET /admin/insights/regions → 지역 점수 0~10 (요청할 때마다 새로 계산)
Future<Json> getRegionScores() async {
  if (!isMock) return await _get('/admin/insights/regions') as Json;
  return {
    'updatedAt': DateTime.now().toIso8601String(), 'crowdDate': null,
    'regions': [for (final r in regions) {'regionId': r.id, 'name': r.name, 'score': 6.3, 'satisfaction': 6.3, 'demand': 0, 'comfort': null, 'reviews': 0, 'avgStars': null, 'courses7d': 0}],
  };
}

/// GET /admin/reports → Agent 가 저장한 지역 보고서
Future<List<Json>> getRegionReports() async {
  if (!isMock) return [for (final r in await _get('/admin/reports?limit=20') as List) r as Json];
  return [];
}

/// POST /admin/reports → 새 보고서 (GPT, 안 되면 규칙 기반)
Future<Json> createRegionReport() async {
  if (!isMock) return await _post('/admin/reports') as Json;
  await _wait(500);
  return {'id': DateTime.now().millisecondsSinceEpoch, 'title': '지역 점수 보고서 (시연)', 'body': '## 요약\n- 시연 화면이라 실제 데이터가 없어요.', 'source': 'rule', 'createdAt': DateTime.now().toIso8601String()};
}

/// GET /admin/sources · /admin/derived · /admin/quality
Future<Json> getAdminData() async {
  if (!isMock) {
    final r = await Future.wait([_get('/admin/sources'), _get('/admin/derived'), _get('/admin/quality')]);
    return {'sources': r[0], 'derived': r[1], 'quality': r[2]};
  }
  await _wait(300);
  return {
    'sources': [
      for (final s in cm.sources)
        {'id': s.id, 'name': s.name, 'cycle': s.cycle, 'basis': s.basis, 'last': s.last, 'rows': s.rows, 'status': s.status, 'note': s.note}
    ],
    'derived': [for (final d in cm.derived) {'name': d.$1, 'desc': d.$2, 'store': d.$3, 'lag': d.$4}],
    'quality': [for (final q in cm.quality) {'check': q.$1, 'target': q.$2, 'result': q.$3, 'level': q.$4}],
  };
}

/// GET /admin/users · /admin/access-logs · /admin/masking-rules
Future<Json> getAdminSecurity() async {
  if (!isMock) {
    final r = await Future.wait([_get('/admin/users'), _get('/admin/access-logs'), _get('/admin/masking-rules')]);
    return {'users': r[0], 'logs': r[1], 'masking': r[2]};
  }
  await _wait(300);
  return {
    'users': [for (final u in cm.accounts) {...u}],
    'logs': [for (final l in cm.accessLog) {'at': l.$1, 'who': l.$2, 'action': l.$3, 'target': l.$4, 'ok': l.$5}],
    'masking': [for (final m in cm.masking) {'rule': m.$1, 'how': m.$2}],
  };
}

/// PATCH /admin/users/{id} — 상권 주인 승인, 정지 등
Future<void> updateUser(String id, Json body) async {
  if (!isMock) {
    await _patch('/admin/users/$id', body);
    return;
  }
  await _wait(300);
}

/// GET /admin/backups · /admin/retention
Future<Json> getAdminBackups() async {
  if (!isMock) {
    final r = await Future.wait([_get('/admin/backups'), _get('/admin/retention')]);
    return {'backups': r[0], 'retention': r[1]};
  }
  await _wait(300);
  return {
    'backups': [for (final b in cm.backups) {'id': b.$1, 'at': b.$1, 'kind': b.$2, 'size': b.$3, 'ok': true}],
    'retention': [for (final r in cm.retention) {'what': r.$1, 'keep': r.$2}],
  };
}

/// POST /admin/backups
Future<String> requestBackup() async {
  if (!isMock) return (await _post('/admin/backups') as Json?)?['message'] ?? '백업을 요청했어요.';
  await _wait(300);
  return '수동 스냅샷 요청을 보냈어요. (목업)';
}

/// POST /admin/backups/{id}/restore
Future<String> restoreBackup(String id) async {
  if (!isMock) return (await _post('/admin/backups/${Uri.encodeComponent(id)}/restore') as Json?)?['message'] ?? '복구를 요청했어요.';
  await _wait(300);
  return '$id 스냅샷 복구는 관리자 2인 승인이 필요해요. (목업)';
}

/// 실시간 이벤트 구독. WS {EVENT_STREAM_URL}?token=... 로 { type, text, at } 를 받습니다.
/// 돌려준 함수를 부르면 구독을 끊습니다.
void Function() subscribeEvents(void Function(Json e) onEvent) {
  if (!isMock && AppConfig.eventStreamUrl.isNotEmpty) {
    final token = Uri.encodeComponent(_session?.accessToken ?? '');
    final ch = WebSocketChannel.connect(Uri.parse('${AppConfig.eventStreamUrl}?token=$token'));
    final sub = ch.stream.listen((m) {
      try {
        onEvent(jsonDecode(m as String) as Json);
      } catch (_) {}
    }, onError: (_) {});
    return () {
      sub.cancel();
      ch.sink.close();
    };
  }
  final rnd = math.Random();
  String pad(int n) => n.toString().padLeft(2, '0');
  final t = Timer.periodic(const Duration(milliseconds: 2600), (_) {
    final e = cm.eventSamples[rnd.nextInt(cm.eventSamples.length)];
    final d = DateTime.now();
    onEvent({'type': e.$1, 'text': e.$2, 'at': '${pad(d.hour)}:${pad(d.minute)}:${pad(d.second)}'});
  });
  return t.cancel;
}
