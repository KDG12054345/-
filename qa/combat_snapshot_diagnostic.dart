/// 전투 스냅샷 진단 시스템
/// 
/// 전투 시작 시점에 고정되는 값들(E, Delta, Items)이
/// 올바르게 스냅샷되고 불변성이 유지되는지 검증합니다.
/// 
/// 기존 전투 로직을 수정하지 않고, 관찰/출력만 수행합니다.
library;

import '../inventory/inventory_system.dart';
import '../inventory/inventory_item.dart';
import 'inventory_diagnostic.dart';

/// 전투 스냅샷 데이터
class CombatSnapshotData {
  /// 스냅샷 시점 아이템 ID 목록
  final List<String> snappedItemIds;
  
  /// 스냅샷 시점 아이템 이름 목록 (디버그용)
  final List<String> snappedItemNames;
  
  /// 스냅샷 시점 쿨타임 계수 (E)
  final double snappedE;
  
  /// 스냅샷 시점 스태미나 델타 (Delta)
  final double snappedDelta;
  
  /// 스냅샷 시점 과적 단계
  final EncumbranceTier snappedTier;
  
  /// 스냅샷 시점 현재 무게
  final double snappedCurWeight;
  
  /// 스냅샷 시점 최대 무게
  final double snappedMaxWeight;
  
  /// 스냅샷 시점 활성 슬롯 수
  final int snappedActiveSlots;
  
  /// 스냅샷 시점 인벤토리 잠금 상태
  final bool wasLocked;
  
  /// 스냅샷 생성 시간
  final DateTime snapshotTime;
  
  const CombatSnapshotData({
    required this.snappedItemIds,
    required this.snappedItemNames,
    required this.snappedE,
    required this.snappedDelta,
    required this.snappedTier,
    required this.snappedCurWeight,
    required this.snappedMaxWeight,
    required this.snappedActiveSlots,
    required this.wasLocked,
    required this.snapshotTime,
  });
  
  /// 아이템 구성 해시 (빠른 비교용)
  String get itemsHash => snappedItemIds.join(',').hashCode.toString();
  
  /// 다른 스냅샷과 동일한지 확인
  bool equals(CombatSnapshotData other) {
    if (snappedE != other.snappedE) return false;
    if (snappedDelta != other.snappedDelta) return false;
    if (snappedTier != other.snappedTier) return false;
    if (snappedItemIds.length != other.snappedItemIds.length) return false;
    
    for (int i = 0; i < snappedItemIds.length; i++) {
      if (snappedItemIds[i] != other.snappedItemIds[i]) return false;
    }
    
    return true;
  }
  
  /// 차이점 목록 반환
  List<String> diff(CombatSnapshotData other) {
    final diffs = <String>[];
    
    if (snappedE != other.snappedE) {
      diffs.add('E: ${snappedE} -> ${other.snappedE}');
    }
    if (snappedDelta != other.snappedDelta) {
      diffs.add('Delta: ${snappedDelta} -> ${other.snappedDelta}');
    }
    if (snappedTier != other.snappedTier) {
      diffs.add('Tier: ${snappedTier.displayName} -> ${other.snappedTier.displayName}');
    }
    if (snappedItemIds.length != other.snappedItemIds.length) {
      diffs.add('ItemCount: ${snappedItemIds.length} -> ${other.snappedItemIds.length}');
    } else {
      for (int i = 0; i < snappedItemIds.length; i++) {
        if (snappedItemIds[i] != other.snappedItemIds[i]) {
          diffs.add('Item[$i]: ${snappedItemIds[i]} -> ${other.snappedItemIds[i]}');
        }
      }
    }
    
    return diffs;
  }
}

/// 전투 스냅샷 진단 클래스
/// 
/// 기존 InventorySystem의 public API만 사용하여 스냅샷 정보를 수집합니다.
/// 어떠한 상태 변경도 하지 않습니다.
class CombatSnapshotDiagnostic {
  final InventorySystem inventory;
  
  /// 마지막 캡처된 스냅샷 (전투 시작 시점)
  CombatSnapshotData? _lastCombatSnapshot;
  
  CombatSnapshotDiagnostic(this.inventory);
  
  /// 현재 상태에서 스냅샷 생성 (전투 시작 직전/직후 호출)
  CombatSnapshotData captureSnapshot() {
    final items = inventory.items;
    
    final snapshot = CombatSnapshotData(
      snappedItemIds: items.map((i) => i.id).toList(),
      snappedItemNames: items.map((i) => i.name).toList(),
      snappedE: inventory.cooldownTickRateMultiplier,
      snappedDelta: inventory.staminaRecoveryDelta,
      snappedTier: inventory.encumbranceTier,
      snappedCurWeight: inventory.currentWeight,
      snappedMaxWeight: inventory.maxWeight,
      snappedActiveSlots: inventory.totalItemSlots,
      wasLocked: inventory.lockSystem.isLocked,
      snapshotTime: DateTime.now(),
    );
    
    _lastCombatSnapshot = snapshot;
    return snapshot;
  }
  
  /// 마지막 캡처된 스냅샷 가져오기
  CombatSnapshotData? get lastSnapshot => _lastCombatSnapshot;
  
  /// 스냅샷 비교 (전투 중 불변성 검증)
  (bool matches, List<String> diffs) compareWithLast() {
    if (_lastCombatSnapshot == null) {
      return (false, ['No previous snapshot to compare']);
    }
    
    final current = captureSnapshot();
    final matches = _lastCombatSnapshot!.equals(current);
    final diffs = matches ? <String>[] : _lastCombatSnapshot!.diff(current);
    
    return (matches, diffs);
  }
  
  /// 스냅샷을 텍스트 로그로 출력
  String dumpToString([CombatSnapshotData? snapshot]) {
    final data = snapshot ?? _lastCombatSnapshot;
    
    if (data == null) {
      return '(No combat snapshot captured)';
    }
    
    final buffer = StringBuffer();
    
    buffer.writeln('╔══════════════════════════════════════════════════════════════╗');
    buffer.writeln('║          COMBAT SNAPSHOT DIAGNOSTIC                          ║');
    buffer.writeln('╚══════════════════════════════════════════════════════════════╝');
    buffer.writeln();
    
    buffer.writeln('Snapshot Time: ${data.snapshotTime.toIso8601String()}');
    buffer.writeln('Inventory Locked: ${data.wasLocked}');
    buffer.writeln();
    
    // 핵심 스냅샷 값
    buffer.writeln('★ Combat Snapshot Values:');
    buffer.writeln('  SnappedE (cooldown multiplier): ${data.snappedE.toStringAsFixed(2)}');
    buffer.writeln('  SnappedDelta (stamina delta):   ${data.snappedDelta.toStringAsFixed(2)}');
    buffer.writeln('  SnappedTier:                    ${data.snappedTier.index} (${data.snappedTier.displayName})');
    buffer.writeln();
    
    // 인벤토리 상태 요약
    buffer.writeln('Inventory State at Snapshot:');
    buffer.writeln('  ActiveSlots: ${data.snappedActiveSlots}');
    buffer.writeln('  MaxWeight:   ${data.snappedMaxWeight.toStringAsFixed(1)}');
    buffer.writeln('  CurWeight:   ${data.snappedCurWeight.toStringAsFixed(1)}');
    buffer.writeln();
    
    // 아이템 목록
    buffer.writeln('SnappedItems (${data.snappedItemIds.length}):');
    if (data.snappedItemIds.isEmpty) {
      buffer.writeln('  (none)');
    } else {
      for (int i = 0; i < data.snappedItemIds.length; i++) {
        buffer.writeln('  [$i] ${data.snappedItemNames[i]} (${data.snappedItemIds[i]})');
      }
    }
    buffer.writeln();
    
    buffer.writeln('ItemsHash: ${data.itemsHash}');
    buffer.writeln();
    buffer.writeln('════════════════════════════════════════════════════════════════');
    
    return buffer.toString();
  }
  
  /// 콘솔에 출력
  void dump([CombatSnapshotData? snapshot]) {
    print(dumpToString(snapshot));
  }
  
  /// E/Delta 값이 예상 Tier와 일치하는지 검증
  (bool valid, String message) verifyEDeltaMatchesTier(CombatSnapshotData snapshot) {
    final tier = snapshot.snappedTier;
    final expectedE = tier.cooldownMultiplier;
    final expectedDelta = tier.staminaDelta;
    
    final eMatches = (snapshot.snappedE - expectedE).abs() < 0.001;
    final deltaMatches = (snapshot.snappedDelta - expectedDelta).abs() < 0.001;
    
    if (eMatches && deltaMatches) {
      return (true, 'E=${snapshot.snappedE}, Delta=${snapshot.snappedDelta} matches Tier ${tier.displayName}');
    }
    
    final issues = <String>[];
    if (!eMatches) {
      issues.add('E mismatch: got ${snapshot.snappedE}, expected $expectedE');
    }
    if (!deltaMatches) {
      issues.add('Delta mismatch: got ${snapshot.snappedDelta}, expected $expectedDelta');
    }
    
    return (false, issues.join('; '));
  }
  
  /// 스냅샷 초기화
  void clearSnapshot() {
    _lastCombatSnapshot = null;
  }
}

/// 단축 함수: 전투 스냅샷 진단 출력
void dumpCombatSnapshotDiagnostic(InventorySystem inventory) {
  final diagnostic = CombatSnapshotDiagnostic(inventory);
  final snapshot = diagnostic.captureSnapshot();
  diagnostic.dump(snapshot);
}
