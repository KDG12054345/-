/// 인벤토리/가방 시스템 QA 진단 출력
/// 
/// 기존 인벤토리 로직을 절대 수정하지 않고, 
/// 읽기 전용으로 상태를 진단/출력합니다.
library;

import '../inventory/inventory_system.dart';
import '../inventory/bag.dart';
import '../inventory/inventory_item.dart';

/// 초과 아이템 처리 정책
enum OverflowPolicy {
  /// 초과 아이템은 오버플로우 영역으로 이동 (현재 시스템: 아이템 파괴)
  destroyOverflow,
  
  /// 가방 해제 자체를 차단
  blockUnequip,
  
  /// 자동으로 앞 슬롯으로 재배치 시도
  autoRepack,
}

/// 인벤토리 진단 결과
class InventoryDiagnosticResult {
  /// 가방 슬롯 사용량 (used / max)
  final int usedBagSlots;
  final int maxBagSlots;
  
  /// 아이템 슬롯 활성량 (used / total)
  final int usedItemSlots;
  final int totalItemSlots;
  
  /// 무게
  final double curWeight;
  final double maxWeight;
  final double overweightPercent;
  final EncumbranceTier tier;
  
  /// 장착된 가방 목록
  final List<BagDiagnosticInfo> bags;
  
  /// 아이템 슬롯 덤프
  final List<String> slotDump;
  
  /// 현재 적용 중인 정책
  final OverflowPolicy overflowPolicy;
  
  /// 검증용: Dump에서 직접 센 점유 개수
  final int usedCountByDump;
  
  /// 검증용: 시스템 API에서 가져온 점유 개수
  final int usedCountBySystem;
  
  /// 검증 결과: 두 값이 일치하는지
  bool get isUsedCountValid => usedCountByDump == usedCountBySystem;
  
  /// 파괴된 오버플로우 아이템 수 (DestroyOverflow 정책 시)
  final int destroyedOverflowCount;
  
  /// 파괴된 오버플로우 아이템 목록 (DestroyOverflow 정책 시)
  final List<String> destroyedOverflowList;
  
  const InventoryDiagnosticResult({
    required this.usedBagSlots,
    required this.maxBagSlots,
    required this.usedItemSlots,
    required this.totalItemSlots,
    required this.curWeight,
    required this.maxWeight,
    required this.overweightPercent,
    required this.tier,
    required this.bags,
    required this.slotDump,
    required this.overflowPolicy,
    required this.usedCountByDump,
    required this.usedCountBySystem,
    this.destroyedOverflowCount = 0,
    this.destroyedOverflowList = const [],
  });
}

/// 가방별 진단 정보
class BagDiagnosticInfo {
  final String id;
  final String displayName;
  final int bagSlotCost;
  final int itemSlots;
  final int weightBonus;
  final int usedSlots;
  final List<String> itemIds;
  
  const BagDiagnosticInfo({
    required this.id,
    required this.displayName,
    required this.bagSlotCost,
    required this.itemSlots,
    required this.weightBonus,
    required this.usedSlots,
    required this.itemIds,
  });
}

/// 인벤토리 진단 유틸리티 클래스
/// 
/// 기존 InventorySystem의 public API만 사용하여 진단 정보를 수집합니다.
/// 어떠한 상태 변경도 하지 않습니다.
class InventoryDiagnostic {
  final InventorySystem inventory;
  
  /// 현재 시스템에서 사용 중인 오버플로우 정책
  /// 기존 코드 분석 결과: removeBag 시 초과 아이템은 파괴됨
  static const OverflowPolicy currentPolicy = OverflowPolicy.destroyOverflow;
  
  /// 파괴된 오버플로우 아이템 추적 (외부에서 설정)
  int destroyedOverflowCount = 0;
  List<String> destroyedOverflowList = [];
  
  InventoryDiagnostic(this.inventory);
  
  /// 파괴된 아이템 기록 추가
  void recordDestroyedItems(List<InventoryItem> items) {
    destroyedOverflowCount = items.length;
    destroyedOverflowList = items.map((i) => i.name).toList();
  }
  
  /// 파괴 기록 초기화
  void clearDestroyedRecord() {
    destroyedOverflowCount = 0;
    destroyedOverflowList = [];
  }
  
  /// 전체 진단 결과 수집
  InventoryDiagnosticResult diagnose() {
    // 1. 가방 슬롯 정보 (기존 API 호출)
    final usedBagSlots = inventory.usedBagSlots;
    final maxBagSlots = InventorySystem.maxBagSlots;
    
    // 2. 아이템 슬롯 정보 (기존 API 호출)
    final usedItemSlots = inventory.usedItemSlots;
    final totalItemSlots = inventory.totalItemSlots;
    
    // 3. 무게 정보 (기존 API 호출)
    final curWeight = inventory.currentWeight;
    final maxWeight = inventory.maxWeight;
    final overweightPercent = inventory.overweightPercent;
    final tier = inventory.encumbranceTier;
    
    // 4. 가방별 상세 정보
    final bags = <BagDiagnosticInfo>[];
    for (final bag in inventory.bags) {
      bags.add(BagDiagnosticInfo(
        id: bag.id,
        displayName: bag.name,
        bagSlotCost: bag.bagSlotCost,
        itemSlots: bag.itemSlotCount,
        weightBonus: bag.weightBonus,
        usedSlots: bag.usedSlotCount,
        itemIds: bag.items.map((item) => item.id).toList(),
      ));
    }
    
    // 5. 슬롯 덤프 생성
    final slotDump = _generateSlotDump();
    
    // 6. 검증용: Dump에서 직접 점유 개수 세기
    final usedCountByDump = _countOccupiedInDump(slotDump);
    final usedCountBySystem = usedItemSlots;
    
    return InventoryDiagnosticResult(
      usedBagSlots: usedBagSlots,
      maxBagSlots: maxBagSlots,
      usedItemSlots: usedItemSlots,
      totalItemSlots: totalItemSlots,
      curWeight: curWeight,
      maxWeight: maxWeight,
      overweightPercent: overweightPercent,
      tier: tier,
      bags: bags,
      slotDump: slotDump,
      overflowPolicy: currentPolicy,
      usedCountByDump: usedCountByDump,
      usedCountBySystem: usedCountBySystem,
      destroyedOverflowCount: destroyedOverflowCount,
      destroyedOverflowList: destroyedOverflowList,
    );
  }
  
  /// Dump에서 점유된 슬롯 개수 세기 (A-Z만 카운트)
  int _countOccupiedInDump(List<String> slotDump) {
    int count = 0;
    for (final slot in slotDump) {
      // A-Z 또는 AA, AB 등 알파벳으로 시작하면 점유됨
      if (slot != '.' && slot != 'X') {
        count++;
      }
    }
    return count;
  }
  
  /// 슬롯 덤프 생성
  /// 
  /// 표기 규칙:
  /// - 활성+빈칸: .
  /// - 활성+점유: 아이템 ID 약어 (A, B, C...)
  /// - 비활성(totalItemSlots 이후): X
  List<String> _generateSlotDump() {
    final result = <String>[];
    final totalSlots = inventory.totalItemSlots;
    
    // 아이템 슬롯 순서대로 수집
    int slotIndex = 0;
    final itemLabels = <String, String>{}; // itemId -> label
    int labelCounter = 0;
    
    for (final bag in inventory.bags) {
      for (int i = 0; i < bag.itemSlotCount; i++) {
        final item = bag.getItemAt(i);
        if (item != null) {
          // 아이템에 레이블 할당 (이미 있으면 재사용)
          if (!itemLabels.containsKey(item.id)) {
            itemLabels[item.id] = _getItemLabel(labelCounter++);
          }
          result.add(itemLabels[item.id]!);
        } else {
          result.add('.'); // 활성+빈칸
        }
        slotIndex++;
      }
    }
    
    // 비활성 슬롯 표시 (20칸 기준으로 표시, 또는 totalSlots보다 크면 생략)
    const displaySlots = 20;
    while (result.length < displaySlots) {
      result.add('X'); // 비활성 슬롯
    }
    
    return result;
  }
  
  /// 아이템 레이블 생성 (A, B, C, ..., Z, AA, AB, ...)
  String _getItemLabel(int index) {
    if (index < 26) {
      return String.fromCharCode('A'.codeUnitAt(0) + index);
    }
    // 26 이상인 경우 AA, AB, ... 형식
    final first = index ~/ 26 - 1;
    final second = index % 26;
    return '${String.fromCharCode('A'.codeUnitAt(0) + first)}${String.fromCharCode('A'.codeUnitAt(0) + second)}';
  }
  
  /// 진단 결과를 텍스트 로그로 출력
  String dumpToString() {
    final result = diagnose();
    final buffer = StringBuffer();
    
    buffer.writeln('╔══════════════════════════════════════════════════════════════╗');
    buffer.writeln('║            INVENTORY DIAGNOSTIC DUMP                         ║');
    buffer.writeln('╚══════════════════════════════════════════════════════════════╝');
    buffer.writeln();
    
    // 정책 명시
    buffer.writeln('Policy: ${_policyToString(result.overflowPolicy)}');
    buffer.writeln();
    
    // 가방 목록 (변경된 포맷: bagSlotCost(consumes X))
    buffer.writeln('Bags Equipped:');
    if (result.bags.isEmpty) {
      buffer.writeln('  (none)');
    } else {
      for (final bag in result.bags) {
        buffer.writeln('  - ${bag.displayName} (consumes ${bag.bagSlotCost} bagSlot, provides ${bag.itemSlots} itemSlots, w+${bag.weightBonus})');
      }
    }
    buffer.writeln();
    
    // 가방 슬롯 사용량
    buffer.writeln('BagSlots: ${result.usedBagSlots}/${result.maxBagSlots}');
    if (result.bags.isNotEmpty) {
      final costDetails = result.bags.map((b) => '${b.bagSlotCost}').join('+');
      buffer.writeln('  (breakdown: $costDetails = ${result.usedBagSlots})');
    }
    buffer.writeln();
    
    // 아이템 슬롯 활성량
    buffer.writeln('ItemSlots: ${result.totalItemSlots} active');
    if (result.bags.isNotEmpty) {
      final slotDetails = result.bags.map((b) => '${b.itemSlots}').join('+');
      buffer.writeln('  (from bags: $slotDetails = ${result.totalItemSlots})');
    }
    buffer.writeln();
    
    // 무게 정보
    buffer.writeln('MaxWeight: +${result.maxWeight.toStringAsFixed(1)}');
    if (result.bags.isNotEmpty) {
      final weightDetails = result.bags.map((b) => '${b.weightBonus}').join('+');
      buffer.writeln('  (from bags: $weightDetails = ${result.maxWeight.toInt()})');
    }
    buffer.writeln('CurWeight: ${result.curWeight.toStringAsFixed(1)}');
    buffer.writeln('Overweight: ${result.overweightPercent.toStringAsFixed(1)}%');
    buffer.writeln('Tier: ${result.tier.index} (${result.tier.displayName})');
    buffer.writeln();
    
    // 슬롯 덤프
    buffer.writeln('ItemSlotDump:');
    buffer.writeln('  ${result.slotDump.join(' ')}');
    buffer.writeln('  (. = empty active, X = inactive, A-Z = item)');
    buffer.writeln();
    
    // ★ 검증용: UsedCount 비교
    buffer.writeln('UsedCount Verification:');
    buffer.writeln('  UsedCountByDump:   ${result.usedCountByDump}');
    buffer.writeln('  UsedCountBySystem: ${result.usedCountBySystem}');
    if (!result.isUsedCountValid) {
      buffer.writeln('  *** ERROR: Used mismatch! ***');
    } else {
      buffer.writeln('  ✓ Counts match');
    }
    buffer.writeln();
    
    // ★ DestroyOverflow 정책 시 파괴 정보 출력
    if (result.overflowPolicy == OverflowPolicy.destroyOverflow) {
      buffer.writeln('DestroyOverflow Info:');
      buffer.writeln('  DestroyedOverflowCount: ${result.destroyedOverflowCount}');
      if (result.destroyedOverflowList.isNotEmpty) {
        buffer.writeln('  DestroyedOverflowList: ${result.destroyedOverflowList.join(', ')}');
      } else {
        buffer.writeln('  DestroyedOverflowList: (none)');
      }
      buffer.writeln();
    }
    
    // 아이템 목록
    if (result.bags.any((b) => b.itemIds.isNotEmpty)) {
      buffer.writeln('Items in inventory:');
      int labelIndex = 0;
      for (final bag in result.bags) {
        for (final itemId in bag.itemIds) {
          final label = _getItemLabel(labelIndex++);
          final item = inventory.getItemById(itemId);
          final weight = item != null ? _getItemWeight(item) : 0.0;
          buffer.writeln('  [$label] $itemId (w=${weight.toStringAsFixed(1)})');
        }
      }
      buffer.writeln();
    }
    
    buffer.writeln('════════════════════════════════════════════════════════════════');
    
    return buffer.toString();
  }
  
  /// 검증 결과만 반환 (테스트에서 사용)
  bool verifyUsedCount() {
    final result = diagnose();
    return result.isUsedCountValid;
  }
  
  /// 아이템 무게 조회 (기존 시스템 호출)
  double _getItemWeight(InventoryItem item) {
    // 기존 weightUnitsForInventoryItemId 함수 사용
    // InventorySystem._itemTotalWeightUnits 로직 재현 (읽기 전용)
    final qty = item.properties['quantity'];
    final quantity = (qty is int && qty > 0) ? qty : ((qty is num && qty > 0) ? qty.toInt() : 1);
    
    // weight_units.dart의 함수 사용 (import 없이 직접 참조 불가하므로 
    // InventorySystem.currentWeightUnits를 역산하거나, 
    // 여기서는 properties에서 weight를 직접 읽는 방식 사용)
    final weightProp = item.properties['weight'];
    if (weightProp is num) {
      return weightProp.toDouble() * quantity;
    }
    
    // 기본값 (0.5 단위 2 = 1.0)
    return 1.0 * quantity;
  }
  
  String _policyToString(OverflowPolicy policy) {
    switch (policy) {
      case OverflowPolicy.destroyOverflow:
        return 'DestroyOverflow (초과 아이템 파괴)';
      case OverflowPolicy.blockUnequip:
        return 'BlockUnequip (가방 해제 차단)';
      case OverflowPolicy.autoRepack:
        return 'AutoRepack (자동 재배치)';
    }
  }
  
  /// 콘솔에 진단 결과 출력
  void dump() {
    print(dumpToString());
  }
}

/// 단축 함수: InventorySystem에서 바로 진단 출력
void dumpInventoryDiagnostic(InventorySystem inventory) {
  final diagnostic = InventoryDiagnostic(inventory);
  diagnostic.dump();
}
