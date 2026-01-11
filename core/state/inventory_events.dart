import 'events.dart';
import '../../inventory/vector2_int.dart';

/// 인벤토리 관련 이벤트들
abstract class InventoryEvent extends GEvent {
  const InventoryEvent();
}

/// 아이템 이동 이벤트
class ItemMoved extends InventoryEvent {
  final String itemId;
  final Vector2Int newPosition;
  final DateTime timestamp;
  
  ItemMoved({
    required this.itemId,
    required this.newPosition,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 아이템 회전 이벤트
class ItemRotated extends InventoryEvent {
  final String itemId;
  final DateTime timestamp;
  
  ItemRotated({
    required this.itemId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 아이템 강화 이벤트
class ItemEnhanced extends InventoryEvent {
  final String itemId;
  final int enhancementLevel;
  final DateTime timestamp;
  
  ItemEnhanced({
    required this.itemId,
    required this.enhancementLevel,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 인벤토리 더티 플래그 이벤트
class InventoryDirty extends InventoryEvent {
  final Set<String> affectedItemIds;
  final String reason;
  
  const InventoryDirty({
    required this.affectedItemIds,
    required this.reason,
  });
}

/// 인벤토리 재계산 완료 이벤트
class InventoryRecomputed extends InventoryEvent {
  final Map<String, dynamic> recomputedStats;
  final List<String> activeSynergyIds;
  final DateTime computedAt;
  
  InventoryRecomputed({
    required this.recomputedStats,
    required this.activeSynergyIds,
    DateTime? computedAt,
  }) : computedAt = computedAt ?? DateTime.now();
}

/// 전투 아이템 상태 변경 이벤트
class CombatItemStateChanged extends InventoryEvent {
  final String itemId;
  final Map<String, dynamic> stateChanges;
  final DateTime timestamp;
  
  CombatItemStateChanged({
    required this.itemId,
    required this.stateChanges,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 스냅샷 생성 이벤트
class SnapshotCreated extends InventoryEvent {
  final String snapshotId;
  final List<String> itemIds;
  final DateTime createdAt;
  
  SnapshotCreated({
    required this.snapshotId,
    required this.itemIds,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// 스냅샷 패치 이벤트
class SnapshotPatched extends InventoryEvent {
  final String snapshotId;
  final Map<String, dynamic> patches;
  final DateTime patchedAt;
  
  SnapshotPatched({
    required this.snapshotId,
    required this.patches,
    DateTime? patchedAt,
  }) : patchedAt = patchedAt ?? DateTime.now();
}
