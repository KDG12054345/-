import 'inventory_item.dart';

class SerializationGuard {
  const SerializationGuard();

  InventoryItem normalizeItemProps(InventoryItem item) {
    final props = Map<String, dynamic>.from(item.properties);
    final w = item.baseWidth;
    final h = item.baseHeight;

    // Normalize footprint
    final dynamic rawMask = props['footprint'];
    List<List<int>> mask;
    if (rawMask is List) {
      mask = rawMask
          .map<List<int>>((row) => row is List
              ? row.map<int>((v) => (v is num && v != 0) ? 1 : 0).toList()
              : <int>[])
          .toList();
      if (mask.isEmpty || mask.every((r) => r.every((v) => v == 0))) {
        mask = _rectOnes(w, h);
      } else {
        final maxLen = mask.fold<int>(0, (m, r) => r.length > m ? r.length : m);
        for (final r in mask) {
          if (r.length < maxLen) r.addAll(List<int>.filled(maxLen - r.length, 0));
        }
      }
    } else {
      mask = _rectOnes(w, h);
    }
    if (mask.isEmpty) mask = _rectOnes(1, 1);

    // Normalize rotation
    final dynamic rawRot = props['rotation'];
    int rot;
    if (rawRot is int) {
      final r = ((rawRot % 360) + 360) % 360;
      rot = (r == 0 || r == 90 || r == 180 || r == 270) ? r : 0;
    } else {
      rot = 0;
    }

    props['footprint'] = mask;
    props['rotation'] = rot;

    return item.copyWith(properties: props);
  }

  void normalizeAll(Iterable<InventoryItem> items) {
    // In-place replacement within caller collections is responsibility of caller.
    for (final _ in items) {
      // no-op: provide helper for external iteration
    }
  }

  List<List<int>> _rectOnes(int w, int h) {
    final W = w > 0 ? w : 1;
    final H = h > 0 ? h : 1;
    return List<List<int>>.generate(H, (_) => List<int>.filled(W, 1));
  }
}






































