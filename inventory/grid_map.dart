import 'inventory_item.dart';
import 'vector2_int.dart';
import 'footprint_rotation_cache.dart';

/// 인벤토리 격자 맵
/// 
/// 아이템의 위치를 추적하고 충돌을 관리합니다.
class GridMap {
  final int width;
  final int height;
  
  // 격자: [y][x] = itemId (null이면 빈 칸)
  final List<List<String?>> _grid;
  
  GridMap(this.width, this.height) 
    : _grid = List.generate(height, (_) => List.filled(width, null));
  
  /// 특정 위치의 아이템 ID 반환
  String? getItemIdAt(int x, int y) {
    if (!isValidPosition(x, y)) return null;
    return _grid[y][x];
  }
  
  /// 아이템을 지정된 위치에 배치 (footprint 고려)
  void placeItem(InventoryItem item, int x, int y) {
    if (!isValidPosition(x, y)) {
      print('[GridMap] Invalid position: ($x, $y)');
      return;
    }
    
    // FootprintRotationCache를 사용하여 footprint 기반으로 셀 배치
    final cache = FootprintRotationCache.fromItem(item);
    final rotation = item.currentRotation;
    
    for (final localCell in cache.getLocalOccupiedCells(rotation)) {
      final cellX = x + localCell.x;
      final cellY = y + localCell.y;
      if (isValidPosition(cellX, cellY)) {
        _grid[cellY][cellX] = item.id;
      }
    }
    
    // 아이템의 위치 업데이트
    item.position = Vector2Int(x, y);
  }
  
  /// 아이템 제거 (footprint 고려)
  void clearItem(InventoryItem item) {
    if (item.position == null) return;
    
    final x = item.position!.x;
    final y = item.position!.y;
    
    // FootprintRotationCache를 사용하여 footprint 기반으로 셀 제거
    final cache = FootprintRotationCache.fromItem(item);
    final rotation = item.currentRotation;
    
    for (final localCell in cache.getLocalOccupiedCells(rotation)) {
      final cellX = x + localCell.x;
      final cellY = y + localCell.y;
      if (isValidPosition(cellX, cellY)) {
        _grid[cellY][cellX] = null;
      }
    }
    
    item.position = null;
  }
  
  /// 전체 격자 초기화
  void clear() {
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        _grid[y][x] = null;
      }
    }
  }
  
  /// 유효한 위치인지 확인
  bool isValidPosition(int x, int y) {
    return x >= 0 && x < width && y >= 0 && y < height;
  }
  
  /// 지정된 영역이 비어있는지 확인
  /// 
  /// [x, y] 위치에서 [width] x [height] 크기의 영역이 모두 비어있는지 확인합니다.
  bool isAreaClear(int x, int y, int width, int height) {
    // 범위 체크
    if (x < 0 || y < 0) return false;
    if (x + width > this.width || y + height > this.height) return false;
    
    // 영역 내 모든 셀이 비어있는지 확인
    for (int dy = 0; dy < height; dy++) {
      for (int dx = 0; dx < width; dx++) {
        if (_grid[y + dy][x + dx] != null) {
          return false; // 하나라도 차있으면 false
        }
      }
    }
    
    return true; // 모든 셀이 비어있음
  }
  
  /// 지정된 크기의 아이템을 배치할 수 있는 위치 찾기 (사각형만 고려, 하위 호환성)
  /// 왼쪽 위부터 스캔하여 첫 번째 사용 가능한 위치 반환
  Vector2Int? findAvailableSpot(int itemWidth, int itemHeight) {
    for (int y = 0; y <= height - itemHeight; y++) {
      for (int x = 0; x <= width - itemWidth; x++) {
        // 이 위치에 배치 가능한지 확인
        bool canPlace = true;
        for (int dy = 0; dy < itemHeight && canPlace; dy++) {
          for (int dx = 0; dx < itemWidth && canPlace; dx++) {
            if (_grid[y + dy][x + dx] != null) {
              canPlace = false;
            }
          }
        }
        
        if (canPlace) {
          return Vector2Int(x, y);
        }
      }
    }
    
    return null; // 배치할 수 있는 위치 없음
  }
  
  /// footprint를 고려하여 아이템을 배치할 수 있는 위치 찾기
  /// 왼쪽 위부터 스캔하여 첫 번째 사용 가능한 위치 반환
  Vector2Int? findAvailableSpotForItem(InventoryItem item) {
    final cache = FootprintRotationCache.fromItem(item);
    final rotation = item.currentRotation;
    final mask = cache.getMask(rotation);
    
    if (mask.isEmpty) return null;
    
    final maskHeight = mask.length;
    final maskWidth = mask[0].length;
    
    // 격자 전체를 스캔
    for (int y = 0; y <= height - maskHeight; y++) {
      for (int x = 0; x <= width - maskWidth; x++) {
        // 이 위치에 footprint가 맞는지 확인
        bool canPlace = true;
        for (int dy = 0; dy < maskHeight && canPlace; dy++) {
          for (int dx = 0; dx < maskWidth && canPlace; dx++) {
            // footprint에서 1인 셀만 확인
            if (mask[dy][dx] != 0) {
              if (_grid[y + dy][x + dx] != null) {
                canPlace = false;
              }
            }
          }
        }
        
        if (canPlace) {
          return Vector2Int(x, y);
        }
      }
    }
    
    return null; // 배치할 수 있는 위치 없음
  }
  
  /// 디버깅용 상태 출력
  String debugPrint() {
    final buffer = StringBuffer();
    buffer.writeln('GridMap ($width x $height):');
    
    for (int y = 0; y < height; y++) {
      final row = StringBuffer();
      for (int x = 0; x < width; x++) {
        final itemId = _grid[y][x];
        if (itemId == null) {
          row.write('.');
        } else {
          // 아이템 ID의 첫 글자만 표시
          row.write(itemId.isNotEmpty ? itemId[0].toUpperCase() : '?');
        }
      }
      buffer.writeln(row.toString());
    }
    
    return buffer.toString();
  }
}
