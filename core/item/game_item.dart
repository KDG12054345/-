import '../../inventory/vector2_int.dart';
import 'item_definition.dart';
import 'item_instance.dart';

/// SSOT: 아이템의 정의와 상태를 통합한 단일 진실 원천
class GameItem {
  final ItemDefinition definition;
  final ItemInstance instance;
  
  GameItem({
    required this.definition,
    required this.instance,
  });
  
  // 기존 InventoryItem 호환성을 위한 게터들
  String get id => instance.instanceId;
  String get name => definition.name;
  String get description => definition.description;
  String get iconPath => definition.iconPath;
  int get baseWidth => definition.baseWidth;
  int get baseHeight => definition.baseHeight;
  bool get isRotated => instance.isRotated;
  Vector2Int? get position => instance.gridPosition;
  Map<String, dynamic> get properties => instance.properties;
  
  // 회전 상태를 고려한 실제 크기
  int get currentWidth => isRotated ? baseHeight : baseWidth;
  int get currentHeight => isRotated ? baseWidth : baseHeight;
  
  // 기존 InventoryItem 메서드 호환
  void rotate() {
    instance.isRotated = !instance.isRotated;
  }
  
  List<Vector2Int> getOccupiedCells() {
    if (position == null) return [];
    
    final cells = <Vector2Int>[];
    for (int x = 0; x < currentWidth; x++) {
      for (int y = 0; y < currentHeight; y++) {
        cells.add(Vector2Int(position!.x + x, position!.y + y));
      }
    }
    return cells;
  }
}
