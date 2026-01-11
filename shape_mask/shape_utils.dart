import '../inventory/vector2_int.dart';

int _normalizeDeg(int deg) {
  final d = ((deg % 360) + 360) % 360;
  if (d == 0 || d == 90 || d == 180 || d == 270) return d;
  if (d < 45) return 0;
  if (d < 135) return 90;
  if (d < 225) return 180;
  return 270;
}

List<List<int>> rotateMask(List<List<int>> mask, int deg) {
  final d = _normalizeDeg(deg);
  final h = mask.length;
  final w = h == 0 ? 0 : mask.fold<int>(0, (acc, row) => row.length > acc ? row.length : acc);

  if (h == 0 || w == 0 || d == 0) {
    return List.generate(h, (y) => List<int>.from(mask[y]), growable: false);
  }

  List<List<int>> build(int Function(int, int) mapX, int Function(int, int) mapY, int newW, int newH) {
    final out = List.generate(newH, (_) => List.filled(newW, 0), growable: false);
    for (int y = 0; y < h; y++) {
      final row = y < mask.length ? mask[y] : const <int>[];
      for (int x = 0; x < w; x++) {
        final v = (x < row.length) ? row[x] : 0;
        if (v == 0) continue;
        final nx = mapX(x, y);
        final ny = mapY(x, y);
        out[ny][nx] = v;
      }
    }
    return out;
  }

  switch (d) {
    case 90:
      return build((x, y) => h - 1 - y, (x, y) => x, h, w);
    case 180:
      return build((x, y) => w - 1 - x, (x, y) => h - 1 - y, w, h);
    case 270:
      return build((x, y) => y, (x, y) => w - 1 - x, h, w);
    default:
      return List.generate(h, (y) => List<int>.from(mask[y]), growable: false);
  }
}

List<Vector2Int> occupiedCells(List<List<int>> mask, int rotation) {
  final rotated = rotateMask(mask, rotation);
  final cells = <Vector2Int>[];
  for (int y = 0; y < rotated.length; y++) {
    final row = rotated[y];
    for (int x = 0; x < row.length; x++) {
      if (row[x] != 0) {
        cells.add(Vector2Int(x, y));
      }
    }
  }
  return cells;
}

Map<String, int> boundingBox(List<Vector2Int> cells) {
  if (cells.isEmpty) return {'width': 0, 'height': 0};
  int minX = cells.first.x, maxX = cells.first.x;
  int minY = cells.first.y, maxY = cells.first.y;
  for (final c in cells) {
    if (c.x < minX) minX = c.x;
    if (c.x > maxX) maxX = c.x;
    if (c.y < minY) minY = c.y;
    if (c.y > maxY) maxY = c.y;
  }
  return {'width': (maxX - minX + 1), 'height': (maxY - minY + 1)};
}
