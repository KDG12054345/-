import 'combat_snapshot.dart';
import '../../combat/stats.dart';

/// 동적으로 패치 가능한 스냅샷
class DynamicSnapshot {
  final String snapshotId;
  final DateTime createdAt;
  final Map<String, CombatSnapshot> _baseSnapshots;
  final List<SnapshotPatch> _patches;
  
  DynamicSnapshot({
    required this.snapshotId,
    required Map<String, CombatSnapshot> baseSnapshots,
    DateTime? createdAt,
  }) : _baseSnapshots = Map.from(baseSnapshots),
       _patches = [],
       createdAt = createdAt ?? DateTime.now();
  
  /// 패치 적용
  void applyPatch(SnapshotPatch patch) {
    _patches.add(patch);
  }
  
  /// 특정 아이템의 최종 스냅샷 반환 (패치 적용됨)
  CombatSnapshot? getFinalSnapshot(String itemId) {
    final baseSnapshot = _baseSnapshots[itemId];
    if (baseSnapshot == null) return null;
    
    // 이 아이템에 적용되는 패치들을 시간순으로 적용
    final itemPatches = _patches
        .where((patch) => patch.affectedItemIds.contains(itemId))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    var finalStats = baseSnapshot.finalStats;
    var finalSynergies = List<String>.from(baseSnapshot.activeSynergyIds);
    var finalProperties = Map<String, dynamic>.from(baseSnapshot.frozenProperties);
    
    for (final patch in itemPatches) {
      // 스탯 패치 적용
      if (patch.statChanges.isNotEmpty) {
        finalStats = _applyStatPatch(finalStats, patch.statChanges);
      }
      
      // 시너지 패치 적용
      if (patch.synergyChanges.isNotEmpty) {
        finalSynergies = _applySynergyPatch(finalSynergies, patch.synergyChanges);
      }
      
      // 속성 패치 적용
      if (patch.propertyChanges.isNotEmpty) {
        finalProperties.addAll(patch.propertyChanges);
      }
    }
    
    return CombatSnapshot(
      itemId: baseSnapshot.itemId,
      definitionId: baseSnapshot.definitionId,
      finalStats: finalStats,
      activeSynergyIds: finalSynergies,
      frozenProperties: finalProperties,
      snapshotTime: DateTime.now(),
    );
  }
  
  /// 모든 아이템의 최종 스냅샷 반환
  Map<String, CombatSnapshot> getAllFinalSnapshots() {
    final result = <String, CombatSnapshot>{};
    for (final itemId in _baseSnapshots.keys) {
      final snapshot = getFinalSnapshot(itemId);
      if (snapshot != null) {
        result[itemId] = snapshot;
      }
    }
    return result;
  }
  
  /// 패치 개수 반환
  int get patchCount => _patches.length;
  
  /// 최근 패치 시간 반환
  DateTime? get lastPatchTime => 
      _patches.isEmpty ? null : _patches.last.timestamp;
  
  // 내부 헬퍼 메서드들
  CombatStats _applyStatPatch(CombatStats baseStats, Map<String, dynamic> changes) {
    return baseStats.copyWith(
      attackPower: changes['attackPower'] as int? ?? baseStats.attackPower,
      maxHealth: changes['maxHealth'] as int? ?? baseStats.maxHealth,
      accuracy: changes['accuracy'] as int? ?? baseStats.accuracy,
    );
  }
  
  List<String> _applySynergyPatch(List<String> baseSynergies, Map<String, dynamic> changes) {
    final result = List<String>.from(baseSynergies);
    
    final toAdd = changes['add'] as List<String>? ?? [];
    final toRemove = changes['remove'] as List<String>? ?? [];
    
    result.addAll(toAdd);
    result.removeWhere((synergy) => toRemove.contains(synergy));
    
    return result;
  }
}

/// 스냅샷 패치 정보
class SnapshotPatch {
  final String patchId;
  final Set<String> affectedItemIds;
  final Map<String, dynamic> statChanges;
  final Map<String, dynamic> synergyChanges;
  final Map<String, dynamic> propertyChanges;
  final DateTime timestamp;
  final String reason;
  
  SnapshotPatch({
    required this.patchId,
    required this.affectedItemIds,
    this.statChanges = const {},
    this.synergyChanges = const {},
    this.propertyChanges = const {},
    DateTime? timestamp,
    required this.reason,
  }) : timestamp = timestamp ?? DateTime.now();
}
