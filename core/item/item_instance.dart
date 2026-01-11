import '../../inventory/vector2_int.dart';

/// 플레이어가 소유한 아이템의 가변 상태
class ItemInstance {
  final String instanceId;
  final String definitionId;
  
  // 인벤토리 상태 (기존 InventoryItem에서 이동)
  Vector2Int? gridPosition;
  bool isRotated;
  
  // 아이템 상태 (기존 Item에서 이동)
  Map<String, dynamic> properties; // 강화, 내구도, 옵션 등
  double remainingCooldown;
  
  ItemInstance({
    required this.instanceId,
    required this.definitionId,
    this.gridPosition,
    this.isRotated = false,
    Map<String, dynamic>? properties,
    this.remainingCooldown = 0.0,
  }) : properties = properties ?? <String, dynamic>{};
  
  ItemInstance copyWith({
    Vector2Int? gridPosition,
    bool? isRotated,
    Map<String, dynamic>? properties,
    double? remainingCooldown,
  }) {
    return ItemInstance(
      instanceId: instanceId,
      definitionId: definitionId,
      gridPosition: gridPosition ?? this.gridPosition,
      isRotated: isRotated ?? this.isRotated,
      properties: properties ?? Map.from(this.properties),
      remainingCooldown: remainingCooldown ?? this.remainingCooldown,
    );
  }
}
