import '../../combat/stats.dart';
import '../../inventory/synergy_system.dart';
import '../../inventory/inventory_item.dart';
import 'game_item.dart';

/// 아이템의 파생값들을 계산하는 유틸리티
class DerivedCalculator {
  final SynergySystem synergySystem;
  
  DerivedCalculator(this.synergySystem);
  
  /// 최종 전투 스탯 계산 (기본 + 강화 + 시너지)
  CombatStats calculateFinalStats(GameItem item, List<GameItem> allItems) {
    var stats = item.definition.baseStats;
    
    // 1. 강화/옵션 적용
    final enhancement = item.properties['enhancement'] as int? ?? 0;
    stats = stats.copyWith(
      attackPower: stats.attackPower + enhancement,
    );
    
    // 2. 시너지 보너스 적용
    final activeSynergies = synergySystem.getActiveSynergies(
      allItems.map(_gameItemToLegacyItem).toList()
    );
    
    for (final synergy in activeSynergies) {
      final bonus = synergy.effects['attackBonus'] as double? ?? 0.0;
      stats = stats.copyWith(
        attackPower: (stats.attackPower * (1 + bonus)).round(),
      );
    }
    
    return stats;
  }
  
  /// 활성 시너지 목록 반환
  List<SynergyInfo> calculateActiveSynergies(List<GameItem> items) {
    return synergySystem.getActiveSynergies(
      items.map(_gameItemToLegacyItem).toList()
    );
  }
  
  // 기존 시너지 시스템과의 호환성을 위한 변환
  InventoryItem _gameItemToLegacyItem(GameItem item) {
    return InventoryItem(
      id: item.id,
      name: item.name,
      description: item.description,
      baseWidth: item.baseWidth,
      baseHeight: item.baseHeight,
      iconPath: item.iconPath,
      isRotated: item.isRotated,
      position: item.position,
      properties: Map.from(item.properties),
    );
  }
}
