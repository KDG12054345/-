import 'inventory_item.dart';

class SynergyInfo {
  final String name;
  final String description;
  final List<String> requiredItemIds;
  final Map<String, dynamic> effects;
  
  const SynergyInfo({
    required this.name,
    required this.description,
    required this.requiredItemIds,
    required this.effects,
  });
}

class SynergySystem {
  final List<SynergyInfo> _availableSynergies;
  
  SynergySystem(this._availableSynergies);
  
  /// 현재 활성화된 시너지 목록 반환
  List<SynergyInfo> getActiveSynergies(List<InventoryItem> items) {
    final itemIds = items.map((item) => item.id).toSet();
    final activeSynergies = <SynergyInfo>[];
    
    for (final synergy in _availableSynergies) {
      if (synergy.requiredItemIds.every((requiredId) => itemIds.contains(requiredId))) {
        activeSynergies.add(synergy);
      }
    }
    
    return activeSynergies;
  }
  
  /// 특정 아이템과 관련된 시너지 목록 반환 (잠재적 시너지 포함)
  List<SynergyInfo> getRelatedSynergies(String itemId, List<InventoryItem> currentItems) {
    final relatedSynergies = <SynergyInfo>[];
    final currentItemIds = currentItems.map((item) => item.id).toSet();
    
    for (final synergy in _availableSynergies) {
      if (synergy.requiredItemIds.contains(itemId)) {
        relatedSynergies.add(synergy);
      }
    }
    
    return relatedSynergies;
  }
  
  /// 아이템 제거 시 비활성화되는 시너지 목록
  List<SynergyInfo> getSynergiesLostByRemoving(String itemId, List<InventoryItem> currentItems) {
    final lostSynergies = <SynergyInfo>[];
    final activeSynergies = getActiveSynergies(currentItems);
    
    // 해당 아이템을 제거한 상태로 시뮬레이션
    final itemsWithoutTarget = currentItems.where((item) => item.id != itemId).toList();
    final synergiesAfterRemoval = getActiveSynergies(itemsWithoutTarget);
    
    for (final synergy in activeSynergies) {
      if (!synergiesAfterRemoval.contains(synergy)) {
        lostSynergies.add(synergy);
      }
    }
    
    return lostSynergies;
  }
  
  /// 시너지 조건 충족도 반환 (0.0 ~ 1.0)
  double getSynergyCompletionRate(SynergyInfo synergy, List<InventoryItem> currentItems) {
    final currentItemIds = currentItems.map((item) => item.id).toSet();
    final matchingItems = synergy.requiredItemIds
        .where((requiredId) => currentItemIds.contains(requiredId))
        .length;
    
    return matchingItems / synergy.requiredItemIds.length;
  }
  
  /// 시너지 툴팁 정보 생성
  String generateSynergyTooltip(SynergyInfo synergy, List<InventoryItem> currentItems) {
    final buffer = StringBuffer();
    buffer.writeln('🔗 ${synergy.name}');
    buffer.writeln(synergy.description);
    buffer.writeln();
    
    final currentItemIds = currentItems.map((item) => item.id).toSet();
    buffer.writeln('필요 아이템:');
    
    for (final requiredId in synergy.requiredItemIds) {
      final hasItem = currentItemIds.contains(requiredId);
      buffer.writeln('${hasItem ? '✅' : '❌'} $requiredId');
    }
    
    if (synergy.effects.isNotEmpty) {
      buffer.writeln('\n효과:');
      synergy.effects.forEach((key, value) {
        buffer.writeln('• $key: $value');
      });
    }
    
    return buffer.toString();
  }
} 