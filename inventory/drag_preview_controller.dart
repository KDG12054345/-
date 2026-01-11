import 'vector2_int.dart';
import 'inventory_item.dart';
import 'grid_map.dart';
import 'placement_simulator.dart';

class DragPreviewController {
  final GridMap grid;
  final PlacementSimulator _sim = PlacementSimulator();

  DragPreviewController(this.grid);

  ({bool canPlace, Iterable<Vector2Int> cells}) onDragMove(
    InventoryItem item,
    Vector2Int origin,
    int rotation,
  ) {
    final cells = _sim.occupiedCells(item, origin, rotation);
    final can = _sim.canPlace(item, origin, rotation, grid);
    return (canPlace: can, cells: cells);
  }

  ({int rotation, bool canPlace, Iterable<Vector2Int> cells}) onRotate(
    InventoryItem item,
    int deltaDegrees,
    Vector2Int origin,
    int currentRotation,
  ) {
    final next = _normalizeRotation(currentRotation + deltaDegrees);
    final cells = _sim.occupiedCells(item, origin, next);
    final can = _sim.canPlace(item, origin, next, grid);
    return (rotation: next, canPlace: can, cells: cells);
  }

  int _normalizeRotation(int deg) {
    final r = ((deg % 360) + 360) % 360;
    if (r == 0 || r == 90 || r == 180 || r == 270) return r;
    if (r < 45) return 0;
    if (r < 135) return 90;
    if (r < 225) return 180;
    return 270;
  }
}






































