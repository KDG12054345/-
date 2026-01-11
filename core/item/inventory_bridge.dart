import '../../inventory/inventory_system.dart';
import '../../inventory/inventory_item.dart';
import 'item_manager.dart';
import 'inventory_adapter.dart';

/// 기존 InventorySystem과 새로운 ItemManager를 연결
class InventoryBridge {
  final ItemManager itemManager;
  final InventorySystem legacyInventorySystem;
  
  InventoryBridge({
    required this.itemManager,
    required this.legacyInventorySystem,
  });
  
  /// 새 아이템을 기존 인벤토리 시스템에 추가
  bool addItem(String definitionId) {
    final gameItem = itemManager.createItem(definitionId);
    final inventoryItem = InventoryAdapter.toInventoryItem(gameItem);
    
    return legacyInventorySystem.tryAddItem(inventoryItem);
  }
  
  /// 기존 인벤토리 시스템의 변경사항을 GameItem에 동기화
  void syncFromInventory(InventoryItem inventoryItem) {
    final gameItem = itemManager.getItem(inventoryItem.id);
    if (gameItem != null) {
      // 위치와 회전 상태 동기화
      gameItem.instance.gridPosition = inventoryItem.position;
      gameItem.instance.isRotated = inventoryItem.isRotated;
      gameItem.instance.properties.addAll(inventoryItem.properties);
    }
  }
}
