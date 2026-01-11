import '../../combat/stats.dart';

/// 전투 시작 시점의 불변 스냅샷
class CombatSnapshot {
  final String itemId;
  final String definitionId;
  final CombatStats finalStats;
  final List<String> activeSynergyIds;
  final Map<String, dynamic> frozenProperties;
  final DateTime snapshotTime;
  
  const CombatSnapshot({
    required this.itemId,
    required this.definitionId,
    required this.finalStats,
    required this.activeSynergyIds,
    required this.frozenProperties,
    required this.snapshotTime,
  });
  
  /// 디버깅용 스냅샷 정보
  String getDebugInfo() {
    return '''
아이템: $itemId
최종 스탯: $finalStats
활성 시너지: ${activeSynergyIds.join(', ')}
스냅샷 시간: $snapshotTime
''';
  }
}
