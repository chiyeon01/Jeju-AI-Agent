// 출발 지역을 고를 때 보여 주는 지역별 특색 (색·그림·해시태그·설명). React 의 src/regionInfo.js 와 같은 내용입니다.
import 'package:material_ui/material_ui.dart';

class RegionInfo {
  const RegionInfo({required this.emoji, required this.from, required this.to, required this.accent,
      required this.art, required this.fit, required this.tags, required this.desc, this.photo = ''});
  final String emoji, art, desc;

  /// 대표 사진 검색어 (서버가 네이버 이미지 검색으로 실제 사진을 가져옴)
  final String photo;
  final Color from, to, accent;
  final List<String> fit, tags;
}

const regionInfo = <String, RegionInfo>{
  'jeju-city': RegionInfo(emoji: '🏙️', from: Color(0xFFFFD9A8), to: Color(0xFFF59E62), accent: Color(0xFFC2551C), art: 'city', fit: ['C', 'F'],
      tags: ['#동문시장', '#원도심골목', '#탑동바다', '#야시장'],
      photo: '제주시 용두암',
      desc: '공항과 가까운 제주의 도심이에요. 동문시장 먹거리와 원도심 골목, 탑동 바닷가를 걸어서 이어 돌기 좋아요.'),
  'aewol': RegionInfo(emoji: '🌅', from: Color(0xFFFFC3A0), to: Color(0xFF7FB8E6), accent: Color(0xFFD9534F), art: 'sunset', fit: ['N', 'P'],
      tags: ['#해안도로', '#바다카페', '#한담산책로', '#노을명소'],
      photo: '애월 한담해안산책로',
      desc: '바다를 끼고 달리는 해안도로와 카페가 이어지는 곳이에요. 해 질 무렵 곽지·한담 쪽 노을이 특히 아름다워요.'),
  'hallim': RegionInfo(emoji: '🏝️', from: Color(0xFFB8F0E6), to: Color(0xFF3FB6C6), accent: Color(0xFF0E8A8F), art: 'island', fit: ['N', 'P'],
      tags: ['#협재해변', '#에메랄드바다', '#비양도', '#수월봉'],
      photo: '협재해수욕장 비양도',
      desc: '맑은 에메랄드빛 바다 너머로 비양도가 보이는 서쪽 해변이에요. 한림항 고등어와 수월봉 노을도 함께 즐겨요.'),
  'daejeong': RegionInfo(emoji: '⛰️', from: Color(0xFFD7EBC4), to: Color(0xFF7EA86A), accent: Color(0xFF4F7A3A), art: 'hills', fit: ['N', 'F'],
      tags: ['#송악산', '#산방산', '#모슬포', '#방어회'],
      photo: '산방산 송악산',
      desc: '송악산 둘레길과 산방산이 있는 남서쪽 끝이에요. 겨울이면 모슬포 방어가 제철이라 바다 먹거리가 풍성해요.'),
  'jungmun': RegionInfo(emoji: '🏖️', from: Color(0xFFC5E4FF), to: Color(0xFF4C8FD6), accent: Color(0xFF2563A8), art: 'cliff', fit: ['N', 'P'],
      tags: ['#중문관광단지', '#주상절리', '#색달해변', '#실내체험'],
      photo: '중문 대포 주상절리대',
      desc: '리조트와 체험 시설이 모인 관광단지예요. 주상절리와 색달해변이 가깝고, 비 오는 날 갈 실내 체험도 많아요.'),
  'seogwipo': RegionInfo(emoji: '🍊', from: Color(0xFFFFE3A3), to: Color(0xFFF2A33A), accent: Color(0xFFC46A00), art: 'tangerine', fit: ['C', 'F'],
      tags: ['#이중섭거리', '#올레시장', '#쇠소깍', '#감귤'],
      photo: '서귀포 정방폭포',
      desc: '예술가의 거리와 올레시장이 있는 남쪽 도시예요. 쇠소깍과 폭포가 가깝고, 골목마다 감귤 향이 나요.'),
  'namwon': RegionInfo(emoji: '🌊', from: Color(0xFFE4F5C8), to: Color(0xFF8CC7A6), accent: Color(0xFF3E8A62), art: 'waves', fit: ['N', 'P'],
      tags: ['#큰엉해안', '#표선해변', '#감귤밭', '#한적한바다'],
      photo: '남원 큰엉해안경승지',
      desc: '사람이 적고 한적한 남동쪽 바다예요. 큰엉 해안 절벽길을 걷고 넓은 표선 해변에서 쉬어 가기 좋아요.'),
  'seongsan': RegionInfo(emoji: '🌄', from: Color(0xFFFFD6B0), to: Color(0xFF6FA47C), accent: Color(0xFF2F6B45), art: 'peak', fit: ['N', 'P'],
      tags: ['#성산일출봉', '#일출', '#광치기해변', '#갈치조림'],
      photo: '성산일출봉',
      desc: '유네스코 세계자연유산 성산일출봉이 있는 동쪽 끝이에요. 광치기 해변에서 보는 일출봉 풍경이 대표 장면이에요.'),
  'gujwa': RegionInfo(emoji: '🌿', from: Color(0xFFCFF3E3), to: Color(0xFF5DBB9A), accent: Color(0xFF1F7D5C), art: 'forest', fit: ['N', 'P'],
      tags: ['#월정리', '#세화해변', '#비자림', '#오름'],
      photo: '월정리해변',
      desc: '하얀 모래의 월정리·세화 바다와 비자림 숲, 오름이 함께 있는 동북쪽이에요. 바다와 숲을 하루에 즐길 수 있어요.'),
  'jocheon': RegionInfo(emoji: '🐚', from: Color(0xFFC9F1F4), to: Color(0xFF45B3C9), accent: Color(0xFF147D92), art: 'beach', fit: ['N', 'F'],
      tags: ['#함덕해변', '#서우봉', '#해녀밥상', '#에메랄드'],
      photo: '함덕해수욕장 서우봉',
      desc: '얕고 맑은 함덕 해변과 서우봉이 있는 동네예요. 해녀가 차리는 바다 밥상을 맛볼 수 있어요.'),
};

const _fitWord = {'N': '자연·바다', 'C': '도심·골목', 'F': '미식', 'P': '풍경·사진'};

/// 내 성향(코드 2·3번째 글자)과 지역 특색이 겹치는 부분 → ["자연·바다", "풍경·사진"]
List<String> fitWith(String regionId, String profileCode) {
  final mine = [if (profileCode.length > 2) profileCode[1], if (profileCode.length > 2) profileCode[2]];
  return [for (final f in regionInfo[regionId]?.fit ?? const <String>[]) if (mine.contains(f)) _fitWord[f]!];
}
