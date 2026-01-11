import 'vector2_int.dart';
import 'inventory_item.dart';
import 'grid_map.dart';
import 'footprint_rotation_cache.dart';

class PlacementSimulator {
  const PlacementSimulator();

  bool canPlace(InventoryItem item, Vector2Int origin, int rotation, GridMap grid) {
    final cache = FootprintRotationCache.fromItem(item);
    for (final cell in _occupiedCells(cache, origin, rotation)) {
      if (!grid.isValidPosition(cell.x, cell.y)) return false;
      if (grid.getItemIdAt(cell.x, cell.y) != null) return false;
    }
    return true;
  }

  Iterable<Vector2Int> occupiedCells(InventoryItem item, Vector2Int origin, int rotation) {
    final cache = FootprintRotationCache.fromItem(item);
    return _occupiedCells(cache, origin, rotation);
  }

  Iterable<Vector2Int> _occupiedCells(FootprintRotationCache cache, Vector2Int origin, int rotation) sync* {
    for (final local in cache.getLocalOccupiedCells(rotation)) {
      yield Vector2Int(origin.x + local.x, origin.y + local.y);
    }
  }
}






































