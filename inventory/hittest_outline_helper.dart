import 'vector2_int.dart';
import 'inventory_item.dart';
import 'footprint_rotation_cache.dart';

class HittestOutlineHelper {
  const HittestOutlineHelper();

  bool hitTestItem(InventoryItem item, Vector2Int localCell) {
    final cache = FootprintRotationCache.fromItem(item);
    final mask = cache.getMask(item.currentRotation);
    final x = localCell.x;
    final y = localCell.y;
    if (y < 0 || y >= mask.length) return false;
    if (x < 0 || x >= (mask.isEmpty ? 0 : mask[0].length)) return false;
    return mask[y][x] != 0;
  }

  List<Vector2Int> computeOutline(InventoryItem item, int rotation) {
    final cache = FootprintRotationCache.fromItem(item);
    final mask = cache.getMask(rotation);
    final h = mask.length;
    final w = h == 0 ? 0 : mask[0].length;
    final outline = <Vector2Int>{};

    bool isOne(int x, int y) {
      if (x < 0 || x >= w || y < 0 || y >= h) return false;
      return mask[y][x] != 0;
    }

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (mask[y][x] == 0) continue;
        // Add boundary cells (4-neighborhood edge detection)
        final neighbors = [
          Vector2Int(x - 1, y),
          Vector2Int(x + 1, y),
          Vector2Int(x, y - 1),
          Vector2Int(x, y + 1),
        ];
        for (final n in neighbors) {
          if (!isOne(n.x, n.y)) {
            outline.add(Vector2Int(x, y));
            break;
          }
        }
      }
    }

    return outline.toList(growable: false);
  }
}






































