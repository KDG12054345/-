/// MetaProfile - 여러 회차에 걸쳐 유지되는 메타 진행도
///
/// 게임을 여러 번 플레이하면서 쌓이는 진행도와 언락 정보를 관리합니다.
/// RunState와 달리, 게임 오버 후에도 유지됩니다.

class MetaProfile {
  static const int CURRENT_VERSION = 1;
  
  /// 메타 프로필 버전 (마이그레이션용)
  final int version;
  
  /// 총 회차 수
  final int runCount;
  
  /// 마지막 플레이 시각
  final DateTime? lastPlayedAt;
  
  /// 언락된 플래그들
  /// 예: "unlocked_merfolk_capital", "unlocked_dark_temple"
  final Set<String> unlockedFlags;
  
  /// 인카운터별 본 횟수
  /// 예: {"enc_mermaid_rescue": 3, "enc_tavern_brawl": 1}
  final Map<String, int> seenEncounterCount;
  
  /// 본 엔딩 목록
  /// 예: {"ending_true", "ending_dark"}
  final Set<String> seenEndings;
  
  /// 빈 MetaProfile 생성 (최초 게임 시작)
  const MetaProfile({
    this.version = CURRENT_VERSION,
    this.runCount = 0,
    this.lastPlayedAt,
    this.unlockedFlags = const {},
    this.seenEncounterCount = const {},
    this.seenEndings = const {},
  });
  
  /// 새 회차 시작 (runCount 증가)
  MetaProfile startNewRun() {
    return MetaProfile(
      version: version,
      runCount: runCount + 1,
      lastPlayedAt: DateTime.now(),
      unlockedFlags: Set.from(unlockedFlags),
      seenEncounterCount: Map.from(seenEncounterCount),
      seenEndings: Set.from(seenEndings),
    );
  }
  
  /// 언락 플래그 추가
  MetaProfile addUnlockedFlag(String flag) {
    if (unlockedFlags.contains(flag)) {
      return this; // 이미 언락됨, 변경 없음
    }
    
    return MetaProfile(
      version: version,
      runCount: runCount,
      lastPlayedAt: lastPlayedAt,
      unlockedFlags: {...unlockedFlags, flag},
      seenEncounterCount: Map.from(seenEncounterCount),
      seenEndings: Set.from(seenEndings),
    );
  }
  
  /// 인카운터 본 횟수 증가
  MetaProfile incrementEncounterSeen(String encounterId) {
    final newCount = Map<String, int>.from(seenEncounterCount);
    newCount[encounterId] = (newCount[encounterId] ?? 0) + 1;
    
    return MetaProfile(
      version: version,
      runCount: runCount,
      lastPlayedAt: lastPlayedAt,
      unlockedFlags: Set.from(unlockedFlags),
      seenEncounterCount: newCount,
      seenEndings: Set.from(seenEndings),
    );
  }
  
  /// 엔딩 추가
  MetaProfile addSeenEnding(String endingId) {
    if (seenEndings.contains(endingId)) {
      return this; // 이미 본 엔딩, 변경 없음
    }
    
    return MetaProfile(
      version: version,
      runCount: runCount,
      lastPlayedAt: lastPlayedAt,
      unlockedFlags: Set.from(unlockedFlags),
      seenEncounterCount: Map.from(seenEncounterCount),
      seenEndings: {...seenEndings, endingId},
    );
  }
  
  /// JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'runCount': runCount,
      'lastPlayedAt': lastPlayedAt?.toIso8601String(),
      'unlockedFlags': unlockedFlags.toList(),
      'seenEncounterCount': seenEncounterCount,
      'seenEndings': seenEndings.toList(),
    };
  }
  
  /// JSON 역직렬화
  factory MetaProfile.fromJson(Map<String, dynamic> json) {
    try {
      final version = json['version'] as int? ?? 0;
      
      // 버전 0 (없음)이면 마이그레이션
      if (version == 0) {
        return MetaProfile.migrateFromV0();
      }
      
      return MetaProfile(
        version: version,
        runCount: json['runCount'] as int? ?? 0,
        lastPlayedAt: json['lastPlayedAt'] != null
            ? DateTime.parse(json['lastPlayedAt'] as String)
            : null,
        unlockedFlags: (json['unlockedFlags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toSet() ??
            const {},
        seenEncounterCount: (json['seenEncounterCount'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as int)) ??
            const {},
        seenEndings: (json['seenEndings'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toSet() ??
            const {},
      );
    } catch (e) {
      print('[MetaProfile] Failed to parse JSON, creating default: $e');
      return const MetaProfile();
    }
  }
  
  /// v0 (버전 없음) → v1 마이그레이션
  static MetaProfile migrateFromV0() {
    print('[MetaProfile] Migrating from v0 to v1');
    return const MetaProfile(
      version: 1,
      runCount: 0,
      unlockedFlags: {},
      seenEncounterCount: {},
      seenEndings: {},
    );
  }
  
  /// 특정 플래그가 언락되어 있는지 확인
  bool hasFlag(String flag) => unlockedFlags.contains(flag);
  
  /// 특정 인카운터를 본 적이 있는지 확인
  bool hasSeenEncounter(String encounterId) => seenEncounterCount.containsKey(encounterId);
  
  /// 특정 인카운터를 본 횟수
  int getEncounterSeenCount(String encounterId) => seenEncounterCount[encounterId] ?? 0;
  
  /// 특정 엔딩을 본 적이 있는지 확인
  bool hasSeenEnding(String endingId) => seenEndings.contains(endingId);
  
  @override
  String toString() {
    return 'MetaProfile(v$version, run#$runCount, ${unlockedFlags.length} flags, ${seenEncounterCount.length} encounters, ${seenEndings.length} endings)';
  }
}



