import 'item_manager.dart';
import 'dirty_flag_system.dart';
import 'tick_aligned_system.dart';
import 'dynamic_snapshot.dart';
import 'combat_lock_system.dart';
import 'game_item.dart';
import 'combat_snapshot.dart';
import '../state/events.dart';
import '../../inventory/synergy_system.dart';
import '../../inventory/vector2_int.dart';

/// 기존 ItemManager를 확장한 틱 정렬 버전
class TickAlignedItemManager extends ItemManager {
  late final DirtyFlagSystem dirtyFlags;
  late final TickAlignedInventorySystem tickSystem;
  late final CombatLockSystem combatLock;
  
  TickAlignedItemManager(SynergySystem synergySystem, Function(GEvent) dispatch) 
      : super(synergySystem) {
    dirtyFlags = DirtyFlagSystem();
    combatLock = CombatLockSystem();
    tickSystem = TickAlignedInventorySystem(
      itemManager: this,
      dirtyFlags: dirtyFlags,
      dispatch: dispatch,
    );
  }
  
  /// 틱 시스템 시작
  void startTickSystem() {
    tickSystem.start();
  }
  
  /// 틱 시스템 정지
  void stopTickSystem() {
    tickSystem.stop();
  }
  
  /// 전투 시작 - 스냅샷 생성 및 인벤토리 잠금
  DynamicSnapshot startCombat(List<String> itemIds) {
    final snapshot = createDynamicSnapshot(itemIds);
    final combatId = 'combat_${DateTime.now().millisecondsSinceEpoch}';
    
    combatLock.startCombat(combatId);
    tickSystem.pause();
    
    return snapshot;
  }
  
  /// 전투 종료 - 인벤토리 잠금 해제
  void endCombat() {
    combatLock.endCombat();
    tickSystem.resume();
  }
  
  /// 동적 스냅샷 생성 (기존 createCombatSnapshots 대체)
  DynamicSnapshot createDynamicSnapshot(List<String> itemIds) {
    final baseSnapshots = <String, CombatSnapshot>{};
    final itemsMap = getItemsMap();
    final items = itemIds.map((id) => itemsMap[id]).whereType<GameItem>().toList();
    
    for (final item in items) {
      final calculator = getCalculator();
      final finalStats = calculator.calculateFinalStats(item, items);
      final activeSynergies = calculator.calculateActiveSynergies(items);
      
      final snapshot = CombatSnapshot(
        itemId: item.id,
        definitionId: item.definition.id,
        finalStats: finalStats,
        activeSynergyIds: activeSynergies.map((s) => s.name).toList(),
        frozenProperties: Map.from(item.properties),
        snapshotTime: DateTime.now(),
      );
      
      baseSnapshots[item.id] = snapshot;
    }
    
    final dynamicSnapshot = DynamicSnapshot(
      snapshotId: 'snapshot_${DateTime.now().millisecondsSinceEpoch}',
      baseSnapshots: baseSnapshots,
    );
    
    tickSystem.setCurrentSnapshot(dynamicSnapshot);
    return dynamicSnapshot;
  }
  
  /// 아이템 추가 (기존 메서드 오버라이드)
  @override
  GameItem createItem(String definitionId) {
    if (!combatLock.canPerformInventoryAction('add')) {
      throw InventoryLockedException(combatLock.getLockMessage('add'), 'add');
    }
    
    final gameItem = super.createItem(definitionId);
    
    // 더티 플래그 설정
    if (!combatLock.isInCombat) {
      tickSystem.requestInventoryChange(gameItem.id, 'created', {
        'definitionId': definitionId,
      });
    }
    
    return gameItem;
  }
  
  /// 아이템 이동 (잠금 체크 추가)
  void moveItem(String itemId, Vector2Int newPosition) {
    if (!combatLock.canPerformInventoryAction('move')) {
      throw InventoryLockedException(combatLock.getLockMessage('move'), 'move');
    }
    
    final item = getItem(itemId);
    if (item == null) return;
    
    // 실제 위치 변경은 즉시 적용
    item.instance.gridPosition = newPosition;
    
    // 더티 플래그 설정 (효과는 다음 틱에 적용)
    tickSystem.requestInventoryChange(itemId, 'moved', {
      'newPosition': {'x': newPosition.x, 'y': newPosition.y},
    });
  }
  
  /// 아이템 회전 (잠금 체크 추가)
  void rotateItem(String itemId) {
    if (!combatLock.canPerformInventoryAction('rotate')) {
      throw InventoryLockedException(combatLock.getLockMessage('rotate'), 'rotate');
    }
    
    final item = getItem(itemId);
    if (item == null) return;
    
    // 실제 회전은 즉시 적용
    item.rotate();
    
    // 더티 플래그 설정 (효과는 다음 틱에 적용)
    tickSystem.requestInventoryChange(itemId, 'rotated', {
      'isRotated': item.isRotated,
      // NOTE: GameItem은 아직 bool(isRotated) 기반이라 4방향 회전 값이 없음.
      // legacy(InventoryItem) 쪽은 rotationDegrees SSOT를 사용하므로, 추후 GameItem도 확장 필요.
      'rotationDegrees': item.isRotated ? 90 : 0,
    });
  }
  
  /// 아이템 강화 (잠금 체크 추가)
  void enhanceItem(String itemId, int level) {
    if (!combatLock.canPerformInventoryAction('enhance')) {
      throw InventoryLockedException(combatLock.getLockMessage('enhance'), 'enhance');
    }
    
    final item = getItem(itemId);
    if (item == null) return;
    
    // 실제 강화는 즉시 적용
    item.properties['enhancement'] = level;
    
    // 더티 플래그 설정 (효과는 다음 틱에 적용)
    tickSystem.requestInventoryChange(itemId, 'enhanced', {
      'enhancementLevel': level,
    });
  }
  
  /// 아이템 삭제 (잠금 체크 추가)
  bool removeItem(String itemId) {
    if (!combatLock.canPerformInventoryAction('delete')) {
      throw InventoryLockedException(combatLock.getLockMessage('delete'), 'delete');
    }
    
    final item = getItem(itemId);
    if (item == null) return false;
    
    final itemsMap = getItemsMap() as Map<String, GameItem>;
    itemsMap.remove(itemId);
    
    // 더티 플래그 설정
    if (!combatLock.isInCombat) {
      tickSystem.requestInventoryChange(itemId, 'removed', {
        'itemId': itemId,
      });
    }
    
    return true;
  }
}