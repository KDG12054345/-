/// 인벤토리/가방 시스템 QA 명령어 세트
/// 
/// 기존 인벤토리 로직을 수정하지 않고,
/// 테스트/검증을 위한 명령어만 제공합니다.
library;

import '../inventory/inventory_system.dart';
import '../inventory/bag.dart';
import '../inventory/inventory_item.dart';
import '../data/inventory_item_weight_units.dart';
import 'inventory_diagnostic.dart';

/// QA용 테스트 아이템 정의
/// 
/// 기존 아이템 시스템과 동일한 구조를 사용하되,
/// QA 전용 ID 접두사(qa_)를 사용합니다.
class QaTestItems {
  /// 테스트 아이템 A (무게 5)
  static InventoryItem createItemA({String? id}) {
    return InventoryItem(
      id: id ?? 'qa_item_a_${DateTime.now().millisecondsSinceEpoch}',
      name: 'QA_Item_A',
      description: 'QA 테스트용 아이템 A (무게 5)',
      baseWidth: 1,
      baseHeight: 1,
      iconPath: 'assets/ui/UI/RectangleBox_96x96.png',
      properties: {
        'weight': 5.0,
        'qa_test': true,
      },
    );
  }
  
  /// 테스트 아이템 B (무게 7)
  static InventoryItem createItemB({String? id}) {
    return InventoryItem(
      id: id ?? 'qa_item_b_${DateTime.now().millisecondsSinceEpoch}',
      name: 'QA_Item_B',
      description: 'QA 테스트용 아이템 B (무게 7)',
      baseWidth: 1,
      baseHeight: 1,
      iconPath: 'assets/ui/UI/RectangleBox_96x96.png',
      properties: {
        'weight': 7.0,
        'qa_test': true,
      },
    );
  }
  
  /// 테스트 아이템 C (무게 9)
  static InventoryItem createItemC({String? id}) {
    return InventoryItem(
      id: id ?? 'qa_item_c_${DateTime.now().millisecondsSinceEpoch}',
      name: 'QA_Item_C',
      description: 'QA 테스트용 아이템 C (무게 9)',
      baseWidth: 1,
      baseHeight: 1,
      iconPath: 'assets/ui/UI/RectangleBox_96x96.png',
      properties: {
        'weight': 9.0,
        'qa_test': true,
      },
    );
  }
  
  /// 지정 무게의 테스트 아이템 생성
  static InventoryItem createWithWeight(double weight, {String? id, String? name}) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return InventoryItem(
      id: id ?? 'qa_item_w${weight.toInt()}_$ts',
      name: name ?? 'QA_Item_W${weight.toInt()}',
      description: 'QA 테스트용 아이템 (무게 $weight)',
      baseWidth: 1,
      baseHeight: 1,
      iconPath: 'assets/ui/UI/RectangleBox_96x96.png',
      properties: {
        'weight': weight,
        'qa_test': true,
      },
    );
  }
}

/// 인벤토리 QA 명령어 클래스
/// 
/// 기존 InventorySystem의 public API만 사용합니다.
/// 어떠한 내부 로직도 수정하지 않습니다.
class InventoryQaCommands {
  final InventorySystem inventory;
  
  /// 진단 인스턴스 (파괴 기록 추적용)
  late final InventoryDiagnostic _diagnostic;
  
  /// 마지막으로 파괴된 아이템 목록 (검증용)
  List<InventoryItem> lastDestroyedItems = [];
  
  InventoryQaCommands(this.inventory) {
    _diagnostic = InventoryDiagnostic(inventory);
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // 초기화 명령
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// QA_ResetInventory: 인벤토리 완전 초기화 (아이템/가방 모두 제거)
  void qaResetInventory() {
    _log('QA_ResetInventory: 인벤토리 초기화 시작');
    
    inventory.clear();
    
    _log('QA_ResetInventory: 완료 (가방 0개, 아이템 0개)');
  }
  
  /// QA_ResetToStarter: 시작 구성으로 초기화 (기본 가방 ×3)
  void qaResetToStarter() {
    _log('QA_ResetToStarter: 시작 구성으로 초기화');
    
    inventory.resetForNewRun();
    
    _log('QA_ResetToStarter: 완료');
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // 가방 조작 명령
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// QA_EquipBag: 지정한 가방 타입을 장착
  /// 
  /// [bagType]: 가방 종류 (basic, damaged, large, damagedLarge, pouch)
  /// [customId]: 선택적 커스텀 ID (null이면 자동 생성)
  /// 반환: 성공 여부
  bool qaEquipBag(BagType bagType, {String? customId}) {
    _log('QA_EquipBag: ${bagType.displayName} 장착 시도');
    
    final bag = BagFactory.create(bagType, id: customId);
    final success = inventory.addBag(bag);
    
    if (success) {
      _log('QA_EquipBag: 성공 - ${bag.name} (cost${bag.bagSlotCost}, slots${bag.itemSlotCount}, w+${bag.weightBonus})');
    } else {
      _log('QA_EquipBag: 실패 - 가방 슬롯 부족 또는 잠금 상태');
    }
    
    return success;
  }
  
  /// QA_UnequipBag: 가방 해제
  /// 
  /// [bagId]: 해제할 가방 ID (null이면 마지막 가방)
  /// 반환: (성공 여부, 파괴된 아이템 목록)
  (bool success, List<InventoryItem> destroyedItems) qaUnequipBag({String? bagId}) {
    Bag? targetBag;
    
    if (bagId != null) {
      targetBag = inventory.getBagById(bagId);
    } else if (inventory.bags.isNotEmpty) {
      targetBag = inventory.bags.last;
    }
    
    if (targetBag == null) {
      _log('QA_UnequipBag: 실패 - 대상 가방 없음');
      return (false, []);
    }
    
    _log('QA_UnequipBag: ${targetBag.name} (${targetBag.id}) 해제 시도');
    
    final (success, destroyedItems) = inventory.removeBag(targetBag);
    
    if (success) {
      _log('QA_UnequipBag: 성공');
      if (destroyedItems.isNotEmpty) {
        _log('  ⚠️ 파괴된 아이템: ${destroyedItems.map((i) => i.name).join(', ')}');
      }
      // 파괴된 아이템을 진단에 기록
      lastDestroyedItems = destroyedItems;
      _diagnostic.recordDestroyedItems(destroyedItems);
    } else {
      _log('QA_UnequipBag: 실패 - 잠금 상태 또는 가방 없음');
      lastDestroyedItems = [];
    }
    
    return (success, destroyedItems);
  }
  
  /// QA_UnequipAllBags: 모든 가방 해제
  void qaUnequipAllBags() {
    _log('QA_UnequipAllBags: 모든 가방 해제 시작');
    
    final allDestroyedItems = <InventoryItem>[];
    
    // 뒤에서부터 제거 (인덱스 안정성)
    while (inventory.bags.isNotEmpty) {
      final (_, destroyed) = qaUnequipBag();
      allDestroyedItems.addAll(destroyed);
    }
    
    _log('QA_UnequipAllBags: 완료 (파괴된 아이템: ${allDestroyedItems.length}개)');
  }
  
  /// QA_SwapBag: 가방 교체 (해제 후 새 가방 장착)
  /// 
  /// [oldBagId]: 교체할 기존 가방 ID
  /// [newBagType]: 새 가방 타입
  /// 반환: (성공 여부, 파괴된 아이템 목록)
  (bool success, List<InventoryItem> destroyedItems) qaSwapBag(String oldBagId, BagType newBagType) {
    _log('QA_SwapBag: $oldBagId → ${newBagType.displayName} 교체 시도');
    
    final oldBag = inventory.getBagById(oldBagId);
    if (oldBag == null) {
      _log('QA_SwapBag: 실패 - 기존 가방 없음');
      return (false, []);
    }
    
    // 1. 기존 가방 해제
    final (removeSuccess, destroyedItems) = inventory.removeBag(oldBag);
    if (!removeSuccess) {
      _log('QA_SwapBag: 실패 - 가방 해제 불가');
      return (false, []);
    }
    
    // 2. 새 가방 장착
    final newBag = BagFactory.create(newBagType);
    final addSuccess = inventory.addBag(newBag);
    
    if (!addSuccess) {
      _log('QA_SwapBag: 경고 - 새 가방 장착 실패 (슬롯 부족)');
      return (true, destroyedItems); // 해제는 성공, 장착은 실패
    }
    
    _log('QA_SwapBag: 성공');
    if (destroyedItems.isNotEmpty) {
      _log('  ⚠️ 파괴된 아이템: ${destroyedItems.map((i) => i.name).join(', ')}');
    }
    
    return (true, destroyedItems);
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // 아이템 조작 명령
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// QA_AddTestItem: 테스트 아이템 추가
  /// 
  /// [itemType]: 'A', 'B', 'C' 또는 null (커스텀)
  /// [weight]: itemType이 null일 때 사용할 무게
  /// 반환: 성공 여부
  bool qaAddTestItem({String? itemType, double? weight}) {
    InventoryItem item;
    
    switch (itemType?.toUpperCase()) {
      case 'A':
        item = QaTestItems.createItemA();
        break;
      case 'B':
        item = QaTestItems.createItemB();
        break;
      case 'C':
        item = QaTestItems.createItemC();
        break;
      default:
        if (weight != null) {
          item = QaTestItems.createWithWeight(weight);
        } else {
          item = QaTestItems.createWithWeight(5.0); // 기본 무게 5
        }
    }
    
    _log('QA_AddTestItem: ${item.name} (w=${item.properties['weight']}) 추가 시도');
    
    final success = inventory.tryAddItem(item, location: 'qa_test', condition: 'qa_command');
    
    if (success) {
      _log('QA_AddTestItem: 성공');
    } else {
      _log('QA_AddTestItem: 실패 - 슬롯 부족 또는 잠금 상태');
    }
    
    return success;
  }
  
  /// QA_AddMultipleItems: 여러 테스트 아이템 추가
  /// 
  /// [types]: 아이템 타입 리스트 (예: ['A', 'B', 'C'])
  /// 반환: (성공 개수, 실패 개수)
  (int successCount, int failCount) qaAddMultipleItems(List<String> types) {
    _log('QA_AddMultipleItems: ${types.length}개 아이템 추가 시도');
    
    int successCount = 0;
    int failCount = 0;
    
    for (final type in types) {
      if (qaAddTestItem(itemType: type)) {
        successCount++;
      } else {
        failCount++;
      }
    }
    
    _log('QA_AddMultipleItems: 완료 (성공: $successCount, 실패: $failCount)');
    return (successCount, failCount);
  }
  
  /// QA_RemoveAllItems: 모든 아이템 제거
  void qaRemoveAllItems() {
    _log('QA_RemoveAllItems: 모든 아이템 제거 시작');
    
    final items = List<InventoryItem>.from(inventory.items);
    int removed = 0;
    
    for (final item in items) {
      if (inventory.removeItem(item)) {
        removed++;
      }
    }
    
    _log('QA_RemoveAllItems: 완료 ($removed개 제거)');
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // 진단 명령
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// QA_Dump: 인벤토리 진단 출력
  String qaDump() {
    final output = _diagnostic.dumpToString();
    print(output);
    return output;
  }
  
  /// QA_Dump 후 파괴 기록 초기화
  String qaDumpAndClearDestroyed() {
    final output = _diagnostic.dumpToString();
    print(output);
    _diagnostic.clearDestroyedRecord();
    lastDestroyedItems = [];
    return output;
  }
  
  /// 진단 결과 가져오기 (테스트에서 사용)
  InventoryDiagnosticResult getDiagnosticResult() {
    return _diagnostic.diagnose();
  }
  
  /// UsedCount 검증 (테스트에서 사용)
  bool verifyUsedCount() {
    return _diagnostic.verifyUsedCount();
  }
  
  /// 파괴 기록 초기화
  void clearDestroyedRecord() {
    _diagnostic.clearDestroyedRecord();
    lastDestroyedItems = [];
  }
  
  /// QA_QuickStatus: 간단한 상태 출력 (한 줄)
  String qaQuickStatus() {
    final status = 'BagSlots: ${inventory.usedBagSlots}/${InventorySystem.maxBagSlots} | '
        'ItemSlots: ${inventory.usedItemSlots}/${inventory.totalItemSlots} | '
        'Weight: ${inventory.currentWeight.toStringAsFixed(1)}/${inventory.maxWeight.toStringAsFixed(1)} | '
        'Tier: ${inventory.encumbranceTier.displayName}';
    
    _log('QA_QuickStatus: $status');
    return status;
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // 복합 명령 (테스트 시나리오용)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// 테스트용 가방 구성 설정
  /// 
  /// 인벤토리를 초기화하고 지정된 가방들을 장착합니다.
  void qaSetupBags(List<BagType> bagTypes) {
    _log('QA_SetupBags: ${bagTypes.length}개 가방으로 구성');
    
    qaResetInventory();
    
    for (final type in bagTypes) {
      qaEquipBag(type);
    }
  }
  
  /// 로그 출력
  void _log(String message) {
    print('[InventoryQA] $message');
  }
}

/// InventorySystem 확장 메서드 (편의용)
extension InventorySystemQaExtension on InventorySystem {
  /// QA 명령어 인스턴스 생성
  InventoryQaCommands get qa => InventoryQaCommands(this);
}
