// TODO(GridRefactor): Footprint 좌표계가 그리드 좌표계와 일치하는지 검증 필요
// - getLocalOccupiedCells(): line 41-50
// - _canonicalize(): line 120-160
import 'inventory_item.dart';
import 'vector2_int.dart';

/// Caches rotated, canonicalized masks for an item footprint.
/// - Rotation: 0, 90, 180, 270 (clockwise)
/// - Canonicalization: removes top rows/left columns of zeros so that (0,0) is a 1 cell
/// - Source: item.properties['footprint'] and item.properties['rotation']
/// - Fallback: all-ones by (baseWidth x baseHeight), else 1x1
/// - Guard: rejects all-zero masks
class FootprintRotationCache {
  final Map<int, List<List<int>>> _cacheByRotation;

  FootprintRotationCache._(this._cacheByRotation);

  /// Build cache from item properties.
  factory FootprintRotationCache.fromItem(InventoryItem item) {
    final baseMask = _parseFootprintOrFallback(item);
    _validateNonZero(baseMask);

    final normalized0 = _canonicalize(baseMask);
    final normalized90 = _canonicalize(_rotate90(normalized0));
    final normalized180 = _canonicalize(_rotate90(normalized90));
    final normalized270 = _canonicalize(_rotate90(normalized180));

    return FootprintRotationCache._({
      0: normalized0,
      90: normalized90,
      180: normalized180,
      270: normalized270,
    });
  }

  /// Returns a defensive copy of the mask for the given rotation.
  List<List<int>> getMask(int rotationDegrees) {
    final r = _normalizeRotation(rotationDegrees);
    final mask = _cacheByRotation[r] ?? _cacheByRotation[0]!;
    return mask.map((row) => List<int>.from(row, growable: false)).toList(growable: false);
  }

  /// Returns occupied local cells (bit==1) for the given rotation.
  Iterable<Vector2Int> getLocalOccupiedCells(int rotationDegrees) sync* {
    final m = getMask(rotationDegrees);
    for (int y = 0; y < m.length; y++) {
      for (int x = 0; x < (m.isEmpty ? 0 : m[0].length); x++) {
        if (m[y][x] != 0) {
          yield Vector2Int(x, y);
        }
      }
    }
  }

  static int _normalizeRotation(int rotationDegrees) {
    final r = ((rotationDegrees % 360) + 360) % 360;
    if (r == 0 || r == 90 || r == 180 || r == 270) return r;
    // Snap to nearest right angle
    if (r < 45) return 0;
    if (r < 135) return 90;
    if (r < 225) return 180;
    return 270;
  }

  static List<List<int>> _parseFootprintOrFallback(InventoryItem item) {
    final dynamic rawMask = item.properties['footprint'];

    List<List<int>> rectMask(int w, int h) =>
        List<List<int>>.generate(h > 0 ? h : 1, (_) => List<int>.filled(w > 0 ? w : 1, 1, growable: false), growable: false);

    if (rawMask is List) {
      final rows = <List<int>>[];
      int maxLen = 0;
      for (final row in rawMask) {
        if (row is List) {
          final r = row.map<int>((v) => (v is num && v != 0) ? 1 : 0).toList(growable: true);
          rows.add(r);
          if (r.length > maxLen) maxLen = r.length;
        }
      }
      if (rows.isEmpty) {
        return rectMask(item.baseWidth, item.baseHeight);
      }
      // Rectangularize by padding zeros to max row length
      for (final r in rows) {
        if (r.length < maxLen) {
          r.addAll(List<int>.filled(maxLen - r.length, 0));
        }
      }
      return List<List<int>>.unmodifiable(rows.map((r) => List<int>.unmodifiable(r)));
    }

    // Fallback to rectangular all-ones
    return rectMask(item.baseWidth, item.baseHeight);
  }

  static void _validateNonZero(List<List<int>> mask) {
    int ones = 0;
    for (final row in mask) {
      for (final v in row) {
        if (v != 0) ones++;
      }
    }
    if (ones == 0) {
      throw ArgumentError('Footprint mask cannot be all zeros.');
    }
  }

  static List<List<int>> _rotate90(List<List<int>> src) {
    if (src.isEmpty) return src;
    final h = src.length;
    final w = src[0].length;
    final dst = List.generate(w, (_) => List<int>.filled(h, 0), growable: false);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        dst[x][h - 1 - y] = src[y][x];
      }
    }
    return dst;
  }

  /// Remove top zero-rows and left zero-columns to make (0,0) occupied.
  static List<List<int>> _canonicalize(List<List<int>> src) {
    if (src.isEmpty) return src;
    // Clone to mutable
    List<List<int>> m = src.map((row) => List<int>.from(row)).toList();
    // Trim top rows of all zeros
    while (m.isNotEmpty && m.first.every((v) => v == 0)) {
      m.removeAt(0);
    }
    if (m.isEmpty) return src; // keep original; validation will catch all-zero earlier

    // Trim left columns of all zeros
    while (m.isNotEmpty) {
      bool leftAllZero = true;
      for (int y = 0; y < m.length; y++) {
        if (m[y].isNotEmpty && m[y][0] != 0) {
          leftAllZero = false;
          break;
        }
      }
      if (leftAllZero) {
        for (int y = 0; y < m.length; y++) {
          if (m[y].isNotEmpty) m[y].removeAt(0);
        }
      } else {
        break;
      }
    }

    // Ensure rectangular
    int maxLen = 0;
    for (final r in m) {
      if (r.length > maxLen) maxLen = r.length;
    }
    for (final r in m) {
      if (r.length < maxLen) {
        r.addAll(List<int>.filled(maxLen - r.length, 0));
      }
    }

    return List<List<int>>.unmodifiable(m.map((r) => List<int>.unmodifiable(r)));
  }
}






































