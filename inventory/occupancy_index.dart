import 'inventory_system.dart';
import 'grid_map.dart';
import 'vector2_int.dart';

class OccupancyIndex {
  final GridMap _grid;
  final Map<int, Map<int, String?>> _overlay = {};

  OccupancyIndex._(this._grid);

  static OccupancyIndex buildFrom(InventorySystem inventory) {
    return OccupancyIndex._(inventory.gridMap);
  }

  String? getItemIdAt(int x, int y) {
    final row = _overlay[y];
    if (row != null && row.containsKey(x)) {
      return row[x];
    }
    return _grid.getItemIdAt(x, y);
  }

  bool isFree(int x, int y) => getItemIdAt(x, y) == null;

  void markOccupied(Iterable<Vector2Int> cells, String id) {
    for (final c in cells) {
      _overlay.putIfAbsent(c.y, () => <int, String?>{});
      _overlay[c.y]![c.x] = id;
    }
  }

  void clear(Iterable<Vector2Int> cells) {
    for (final c in cells) {
      final row = _overlay[c.y];
      if (row == null) continue;
      row.remove(c.x);
      if (row.isEmpty) {
        _overlay.remove(c.y);
      }
    }
  }
}






































