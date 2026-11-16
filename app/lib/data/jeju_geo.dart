// 제주 읍면동 경계 (React 의 src/mock/jejuGeo.js 와 같은 데이터)
// 출처: 통계청 2013 행정구역 경계 (github.com/southkorea/southkorea-maps), 0.45px 허용오차로 단순화
// 투영: 등장방형 (위도 33.38° 보정), 좌표계 0 0 800 483. 추자면·마라도는 제외했습니다.
// 경로 데이터는 assets/data/jeju_geo.json 에 있고, 앱 시작 시 한 번 읽습니다.
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;

const double mapW = 800;
const double mapH = 483;
const double _lon0 = 126.145375, _lat1 = 33.563939, _k = 0.835040, _s = 1108.7038, _pad = 16;

/// 지도 좌표 1px 당 km
const double kmPerPx = 0.10012;

/// 위도·경도 → 지도 좌표
Offset project(double lat, double lon) => Offset((lon - _lon0) * _k * _s + _pad, (_lat1 - lat) * _s + _pad);

class Dong {
  Dong(this.name, this.path);
  final String name;
  final Path path;
}

class JejuGeo {
  JejuGeo._(this.dongs, this.regionPaths, this.allPath);

  /// 지역 id → 읍면동 경로 목록
  final Map<String, List<Dong>> dongs;

  /// 지역 id → 읍면동을 합친 경로 (지역 경계 강조용)
  final Map<String, Path> regionPaths;

  /// 섬 전체 경로 (해안선)
  final Path allPath;

  static JejuGeo? _instance;
  static JejuGeo get instance => _instance!;

  static Future<void> load() async {
    if (_instance != null) return;
    final raw = await rootBundle.loadString('assets/data/jeju_geo.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final dongs = <String, List<Dong>>{};
    final regionPaths = <String, Path>{};
    final all = Path();
    for (final e in json.entries) {
      final list = <Dong>[];
      final region = Path();
      for (final g in (e.value as List)) {
        final p = parseSvgPath(g['d'] as String);
        list.add(Dong(g['name'] as String, p));
        region.addPath(p, Offset.zero);
        all.addPath(p, Offset.zero);
      }
      dongs[e.key] = list;
      regionPaths[e.key] = region;
    }
    _instance = JejuGeo._(dongs, regionPaths, all);
  }
}

/// M/L/Z 만 쓰는 SVG 경로 문자열을 Path 로 바꿉니다.
Path parseSvgPath(String d) {
  final path = Path();
  final re = RegExp(r'([MLZ])([^MLZ]*)');
  for (final m in re.allMatches(d)) {
    final cmd = m.group(1)!;
    if (cmd == 'Z') {
      path.close();
      continue;
    }
    final nums = m.group(2)!.split(RegExp(r'[ ,]+')).where((s) => s.isNotEmpty).map(double.parse).toList();
    for (var i = 0; i + 1 < nums.length; i += 2) {
      if (cmd == 'M' && i == 0) {
        path.moveTo(nums[i], nums[i + 1]);
      } else {
        path.lineTo(nums[i], nums[i + 1]);
      }
    }
  }
  return path;
}
