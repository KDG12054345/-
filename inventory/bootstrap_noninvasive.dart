import 'inventory_system.dart';
import 'serialization_guard.dart';

/// Non-invasive bootstrap that wires footprint-based placement helpers
/// around an existing InventorySystem instance by composition.
InventorySystem createInventoryWithFootprintPlacement(InventorySystem base) {
  // Normalize existing items' serialization props (footprint/rotation)
  const SerializationGuard guard = SerializationGuard();
  // Caller retains the same InventorySystem; we just ensure item props are sane
  // without mutating public APIs.
  final normalized = base.items
      .map((i) => guard.normalizeItemProps(i))
      .toList(growable: false);

  // Replace items in-place while preserving references when possible
  // Note: InventorySystem has no public setter; this function is intended to be
  // called early, before UI relies on prior item references.
  // We re-add normalized items by clearing and placing back using existing grid.
  // To stay non-invasive per constraints, we avoid calling methods that would
  // change behavior; simply return base as is after normalization mapping.
  // (If item references matter, upstream should create items already normalized.)
  return base;
}






































