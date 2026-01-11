import '../../combat/item.dart';
import '../../combat/stats.dart';
import 'game_item.dart';
import 'combat_snapshot.dart';

/// GameItem을 기존 전투 시스템과 연결하는 어댑터
class CombatAdapter {
  /// GameItem에서 CombatSnapshot 생성
  static CombatSnapshot createSnapshot(
    GameItem gameItem,
    CombatStats finalStats,
    List<String> activeSynergyIds,
  ) {
    return CombatSnapshot(
      itemId: gameItem.id,
      definitionId: gameItem.definition.id,
      finalStats: finalStats,
      activeSynergyIds: activeSynergyIds,
      frozenProperties: Map.from(gameItem.properties),
      snapshotTime: DateTime.now(),
    );
  }
  
  /// CombatSnapshot에서 기존 Item 클래스 생성 (전투용)
  static MockCombatItem createCombatItem(CombatSnapshot snapshot) {
    return MockCombatItem(
      id: snapshot.itemId,
      stats: snapshot.finalStats,
      remainingCooldown: snapshot.frozenProperties['cooldown'] as double? ?? 0.0,
    );
  }
}

// 기존 Item 클래스와의 호환성을 위한 임시 클래스
class MockCombatItem {
  final String id;
  final CombatStats stats;
  double remainingCooldown;
  
  MockCombatItem({
    required this.id,
    required this.stats,
    this.remainingCooldown = 0.0,
  });
}



















