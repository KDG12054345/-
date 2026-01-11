import 'dart:async';
import '../state/events.dart';
import '../state/inventory_events.dart';
import 'dirty_flag_system.dart';
import 'item_manager.dart';
import 'dynamic_snapshot.dart';
import '../../inventory/vector2_int.dart';

/// 틱과 정렬된 인벤토리 업데이트 시스템
class TickAlignedInventorySystem {
  final ItemManager itemManager;
  final DirtyFlagSystem dirtyFlags;
  final Function(GEvent) dispatch;
  
  Timer? _tickTimer;
  DynamicSnapshot? _currentSnapshot;
  int _tickCount = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  
  // 레이트 리밋 설정
  static const int maxPatchesPerTick = 1;
  static const int maxRecomputesPerSecond = 10;
  static const Duration tickInterval = Duration(milliseconds: 100); // 10 TPS
  
  TickAlignedInventorySystem({
    required this.itemManager,
    required this.dirtyFlags,
    required this.dispatch,
  });
  
  /// 현재 상태 정보
  Map<String, dynamic> get status => {
    'isRunning': _isRunning,
    'isPaused': _isPaused,
    'tickCount': _tickCount,
    'hasDirtyItems': dirtyFlags.hasAnyDirty,
    'dirtyItemCount': dirtyFlags.dirtyItemIds.length,
    'currentSnapshotId': _currentSnapshot?.snapshotId,
  };
  
  /// 틱 시스템 시작
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _isPaused = false;
    _tickCount = 0;
    
    _tickTimer = Timer.periodic(tickInterval, _processTick);
  }
  
  /// 틱 시스템 정지
  void stop() {
    _isRunning = false;
    _isPaused = false;
    _tickTimer?.cancel();
    _tickTimer = null;
  }
  
  /// 틱 시스템 일시정지
  void pause() {
    _isPaused = true;
  }
  
  /// 틱 시스템 재개
  void resume() {
    _isPaused = false;
  }
  
  /// 현재 스냅샷 설정
  void setCurrentSnapshot(DynamicSnapshot snapshot) {
    _currentSnapshot = snapshot;
  }
  
  /// 인벤토리 변경 요청 (더티 플래그만 설정)
  void requestInventoryChange(String itemId, String changeType, Map<String, dynamic> data) {
    if (!_isRunning || _isPaused) return;
    
    dirtyFlags.markDirty(itemId, changeType);
    
    // 네이버후드도 더티로 표시 (시너지 영향)
    final neighborIds = _getNeighborItemIds(itemId);
    if (neighborIds.isNotEmpty) {
      dirtyFlags.markMultipleDirty(neighborIds.toSet(), 'neighbor_of_$itemId');
    }
    
    // 더티 이벤트 발생
    dispatch(InventoryDirty(
      affectedItemIds: {itemId, ...neighborIds},
      reason: changeType,
    ));
  }
  
  /// 틱 처리 (핵심 로직)
  void _processTick(Timer timer) {
    if (!_isRunning || _isPaused) return;
    
    _tickCount++;
    
    // 1. 더티 플래그 확인
    if (!dirtyFlags.hasAnyDirty) return;
    
    // 2. 레이트 리밋 체크
    if (_currentSnapshot != null && 
        _currentSnapshot!.patchCount >= maxPatchesPerTick) {
      return; // 이번 틱은 스킵
    }
    
    // 3. 더티 아이템들 재계산
    final dirtyItems = dirtyFlags.dirtyItemIds;
    final recomputeResult = _recomputeItems(dirtyItems);
    
    // 4. 스냅샷 패치 생성 및 적용
    if (_currentSnapshot != null && recomputeResult.hasChanges) {
      final patch = _createPatch(recomputeResult);
      _currentSnapshot!.applyPatch(patch);
      
      // 패치 이벤트 발생
      dispatch(SnapshotPatched(
        snapshotId: _currentSnapshot!.snapshotId,
        patches: {
          'statChanges': patch.statChanges,
          'synergyChanges': patch.synergyChanges,
          'affectedItems': patch.affectedItemIds.toList(),
        },
      ));
    }
    
    // 5. 재계산 완료 이벤트 발생
    dispatch(InventoryRecomputed(
      recomputedStats: recomputeResult.finalStats,
      activeSynergyIds: recomputeResult.activeSynergies,
    ));
    
    // 6. 더티 플래그 초기화
    dirtyFlags.clearAllDirty();
  }
  
  /// 아이템들 재계산 (부분 재계산)
  _RecomputeResult _recomputeItems(Set<String> dirtyItemIds) {
    final affectedItems = <String, dynamic>{};
    final finalStats = <String, dynamic>{};
    final activeSynergies = <String>[];
    
    // 더티 아이템들과 그 이웃들만 재계산
    for (final itemId in dirtyItemIds) {
      final item = itemManager.getItem(itemId);
      if (item == null) continue;
      
      // 개별 아이템 스탯 계산
      final allItems = itemManager.getAllItems();
      final calculator = itemManager.getCalculator();
      final itemStats = calculator.calculateFinalStats(item, allItems);
      
      finalStats[itemId] = {
        'attackPower': itemStats.attackPower,
        'maxHealth': itemStats.maxHealth,
        'accuracy': itemStats.accuracy,
      };
      
      affectedItems[itemId] = item;
    }
    
    // 시너지 재계산 (전체 - 부분 최적화는 다음 버전에서)
    final allItems = itemManager.getAllItems();
    final calculator = itemManager.getCalculator();
    final synergies = calculator.calculateActiveSynergies(allItems);
    activeSynergies.addAll(synergies.map((s) => s.name));
    
    return _RecomputeResult(
      affectedItems: affectedItems,
      finalStats: finalStats,
      activeSynergies: activeSynergies,
      hasChanges: affectedItems.isNotEmpty,
    );
  }
  
  /// 패치 생성
  SnapshotPatch _createPatch(_RecomputeResult recomputeResult) {
    final patchId = 'patch_${_tickCount}_${DateTime.now().millisecondsSinceEpoch}';
    
    return SnapshotPatch(
      patchId: patchId,
      affectedItemIds: recomputeResult.affectedItems.keys.toSet(),
      statChanges: recomputeResult.finalStats,
      synergyChanges: {
        'active': recomputeResult.activeSynergies,
      },
      reason: 'tick_recompute_$_tickCount',
    );
  }
  
  /// 네이버 아이템 ID들 반환 (시너지 영향 범위)
  List<String> _getNeighborItemIds(String itemId) {
    final item = itemManager.getItem(itemId);
    if (item?.position == null) return [];
    
    final neighbors = <String>[];
    final allItems = itemManager.getAllItems();
    
    for (final otherItem in allItems) {
      if (otherItem.id == itemId || otherItem.position == null) continue;
      
      // 3x3 범위 내의 아이템들을 이웃으로 간주
      final distance = _calculateGridDistance(item!.position!, otherItem.position!);
      if (distance <= 2) {
        neighbors.add(otherItem.id);
      }
    }
    
    return neighbors;
  }
  
  /// 그리드 거리 계산
  int _calculateGridDistance(Vector2Int pos1, Vector2Int pos2) {
    return (pos1.x - pos2.x).abs() + (pos1.y - pos2.y).abs();
  }
  
  /// 강제 재계산 (디버깅용)
  void forceRecompute() {
    if (!_isRunning) return;
    
    final allItems = itemManager.getAllItems();
    final allItemIds = allItems.map((item) => item.id).toSet();
    
    dirtyFlags.markMultipleDirty(allItemIds, 'force_recompute');
  }
}

/// 재계산 결과
class _RecomputeResult {
  final Map<String, dynamic> affectedItems;
  final Map<String, dynamic> finalStats;
  final List<String> activeSynergies;
  final bool hasChanges;
  
  const _RecomputeResult({
    required this.affectedItems,
    required this.finalStats,
    required this.activeSynergies,
    required this.hasChanges,
  });
}
