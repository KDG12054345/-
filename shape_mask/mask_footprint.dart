import '../inventory/inventory_item.dart';

class MaskFootprint {
  final List<List<int>> mask; // 0/1 matrix
  final int rotation; // 0/90/180/270 clockwise

  MaskFootprint({
    required this.mask,
    required this.rotation,
  });

  factory MaskFootprint.fromItemProperties(InventoryItem item) {
    final props = item.properties;
    final dynamic rawMask = props['footprint'];
    final dynamic rawRot = props['rotation'];

    List<List<int>> rectMask(int w, int h) =>
        List.generate(h, (_) => List.filled(w, 1, growable: false), growable: false);

    List<List<int>> parsedMask;
    if (rawMask is List) {
      parsedMask = rawMask
          .map<List<int>>((row) => row is List
              ? row.map<int>((v) => (v is num && v != 0) ? 1 : 0).toList(growable: false)
              : <int>[])
          .toList(growable: false);
      if (parsedMask.isEmpty) {
        parsedMask = rectMask(item.baseWidth, item.baseHeight);
      }
    } else {
      parsedMask = rectMask(item.baseWidth, item.baseHeight);
    }

    int rotationDeg;
    if (rawRot is int) {
      final r = ((rawRot % 360) + 360) % 360;
      rotationDeg = (r == 0 || r == 90 || r == 180 || r == 270)
          ? r
          : (r < 45 ? 0 : (r < 135 ? 90 : (r < 225 ? 180 : 270)));
    } else if (rawRot is bool) {
      rotationDeg = rawRot ? 90 : 0;
    } else {
      rotationDeg = item.currentRotation;
    }

    return MaskFootprint(mask: parsedMask, rotation: rotationDeg);
  }

  Map<String, dynamic> toItemProperties() {
    return <String, dynamic>{
      'footprint': mask.map((row) => row.toList(growable: false)).toList(growable: false),
      'rotation': rotation,
    };
  }
}
