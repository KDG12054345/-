import '../../inventory/inventory_system.dart';
import '../../inventory/inventory_item.dart';
import 'item_manager_extended.dart';
import 'inventory_adapter.dart';
import 'item_definition.dart';
import '../../combat/item.dart';
import '../../combat/stats.dart';

/// 기존 InventorySystem과 새로운 TickAlignedItemManager를 연결
class LegacyInventoryBridge {
  final TickAlignedItemManager newManager;
  final InventorySystem legacySystem;
  
  LegacyInventoryBridge({
    required this.newManager,
    required this.legacySystem,
  });
  
  /// 기존 시스템의 변경사항을 새 시스템에 동기화
  void syncFromLegacy() {
    try {
      // 기존 인벤토리의 모든 아이템을 새 시스템으로 이동
      for (final legacyItem in legacySystem.items) {
        final definition = _findOrCreateDefinition(legacyItem);
        
        // 정의가 이미 등록되어 있는지 확인
        if (newManager.getItem(legacyItem.id) == null) {
          // 정의 등록
          try {
            newManager.registerDefinition(definition);
          } catch (e) {
            // 이미 등록된 정의인 경우 무시
          }
          
          // 아이템 생성 대신 직접 추가
          final gameItem = InventoryAdapter.fromInventoryItem(legacyItem, definition);
          final itemsMap = newManager.getItemsMap() as Map<String, dynamic>;
          itemsMap[gameItem.id] = gameItem;
        }
      }
    } catch (e) {
      print('Legacy sync error: $e');
    }
  }
  
  /// 새 시스템의 변경사항을 기존 시스템에 동기화
  void syncToLegacy() {
    try {
      // 필요한 경우에만 사용 (주로 디버깅용)
      for (final gameItem in newManager.getAllItems()) {
        final legacyItem = InventoryAdapter.toInventoryItem(gameItem);
        
        // 기존 시스템에서 해당 아이템 업데이트
        final existingItem = legacySystem.getItemById(gameItem.id);
        if (existingItem != null) {
          existingItem.position = legacyItem.position;
          existingItem.isRotated = legacyItem.isRotated;
          existingItem.properties.clear();
          existingItem.properties.addAll(legacyItem.properties);
        } else {
          // 새 아이템 추가
          legacySystem.tryAddItem(legacyItem);
        }
      }
    } catch (e) {
      print('Legacy sync to error: $e');
    }
  }
  
  /// 정의 찾기 또는 생성 (임시)
  ItemDefinition _findOrCreateDefinition(InventoryItem legacyItem) {
    return ItemDefinition(
      id: legacyItem.id, // name 대신 id 사용
      name: legacyItem.name,
      description: legacyItem.description,
      iconPath: legacyItem.iconPath,
      baseWidth: legacyItem.baseWidth,
      baseHeight: legacyItem.baseHeight,
      type: ItemType.weapon, // 기본값
      baseStats: CombatStats(), // 기본값
    );
  }
  
  /// 양방향 동기화 (전체)
  void fullSync() {
    syncFromLegacy();
    syncToLegacy();
  }
  
  /// 상태 정보 반환
  Map<String, dynamic> getStatus() {
    return {
      'legacyItemCount': legacySystem.items.length,
      'newManagerItemCount': newManager.getAllItems().length,
      'isInSync': legacySystem.items.length == newManager.getAllItems().length,
    };
  }
}
