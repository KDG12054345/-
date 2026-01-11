import 'inventory_item.dart';
import 'grid_map.dart';
import 'vector2_int.dart';
import 'placement_simulator.dart';

/// 충돌 감지기
/// 
/// 아이템 배치 시 충돌을 검사합니다.
class CollisionDetector {
  final GridMap gridMap;
  final PlacementSimulator _placementSimulator = const PlacementSimulator();
  
  CollisionDetector(this.gridMap);
  
  /// 아이템을 지정된 위치에 배치할 수 있는지 확인 (footprint 고려)
  bool isValidPlacement(InventoryItem item, int x, int y) {
    final origin = Vector2Int(x, y);
    final rotation = item.currentRotation;
    
    // PlacementSimulator를 사용하여 footprint 기반 충돌 검사
    // canPlace는 격자 범위와 다른 아이템과의 충돌을 모두 확인함
    // 단, 현재 아이템이 이미 이 위치에 있는 경우는 허용해야 함 (이동/회전 시)
    final occupiedCells = _placementSimulator.occupiedCells(item, origin, rotation);
    
    // 모든 footprint 셀이 유효한 위치인지 확인
    for (final cell in occupiedCells) {
      if (!gridMap.isValidPosition(cell.x, cell.y)) {
        return false;
      }
      
      // 다른 아이템과의 충돌 확인 (현재 아이템 자신은 허용)
      final existingItemId = gridMap.getItemIdAt(cell.x, cell.y);
      if (existingItemId != null && existingItemId != item.id) {
        return false; // 다른 아이템이 이미 있음
      }
    }
    
    return true;
  }
}
