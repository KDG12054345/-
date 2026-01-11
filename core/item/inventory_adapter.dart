import '../../inventory/inventory_item.dart';
import '../../inventory/vector2_int.dart';
import 'game_item.dart';
import 'item_definition.dart';
import 'item_instance.dart';

/// 기존 InventoryItem과 새로운 GameItem 간의 어댑터
class InventoryAdapter {
  /// GameItem을 기존 InventoryItem으로 변환 (기존 코드 호환용)
  static InventoryItem toInventoryItem(GameItem gameItem) {
    return InventoryItem(
      id: gameItem.id,
      name: gameItem.name,
      description: gameItem.description,
      baseWidth: gameItem.baseWidth,
      baseHeight: gameItem.baseHeight,
      iconPath: gameItem.iconPath,
      isRotated: gameItem.isRotated,
      position: gameItem.position,
      properties: Map.from(gameItem.properties),
    );
  }
  
  /// 기존 InventoryItem에서 GameItem으로 변환
  static GameItem fromInventoryItem(
    InventoryItem inventoryItem,
    ItemDefinition definition,
  ) {
    return GameItem(
      definition: definition,
      instance: ItemInstance(
        instanceId: inventoryItem.id,
        definitionId: definition.id,
        gridPosition: inventoryItem.position,
        isRotated: inventoryItem.isRotated,
        properties: Map.from(inventoryItem.properties),
      ),
    );
  }
}
