import 'dart:async';
import '../data/inventory_item_weight_units.dart';
import 'combat_lock_system.dart';
import 'inventory_item.dart';
import 'item_acquisition_history.dart';
import 'grid_map.dart';
import 'synergy_system.dart';
import 'bag.dart';

/// 인컴버런스(Encumbrance) 단계 (v6.2 설계안)
/// 
/// 과적%에 따라 4단계로 구분됩니다.
/// - 정상(Normal): overweight = 0%
/// - 불편(Uncomfortable): 0% < overweight ≤ 20%
/// - 위험(Danger): 20% < overweight ≤ 50%
/// - 붕괴(Collapse): 50% < overweight
enum EncumbranceTier {
  normal,       // 과적 0%
  uncomfortable, // 0% < 과적 ≤ 20%
  danger,       // 20% < 과적 ≤ 50%
  collapse,     // 50% < 과적
}

/// EncumbranceTier 확장 메서드
extension EncumbranceTierExtension on EncumbranceTier {
  /// 쿨타임 계수 E
  /// 
  /// finalTickRate = E × (hasteFactor / frostFactor)
  double get cooldownMultiplier {
    switch (this) {
      case EncumbranceTier.normal:
        return 1.0;
      case EncumbranceTier.uncomfortable:
        return 1.0;
      case EncumbranceTier.danger:
        return 0.8;
      case EncumbranceTier.collapse:
        return 0.6;
    }
  }
  
  /// 스태미나 회복 델타 (덧셈 방식)
  /// 
  /// actualRegen = max(0, baseRegen + staminaDelta)
  double get staminaDelta {
    switch (this) {
      case EncumbranceTier.normal:
        return 0.0;
      case EncumbranceTier.uncomfortable:
        return -0.1;
      case EncumbranceTier.danger:
        return -0.2;
      case EncumbranceTier.collapse:
        return -0.3;
    }
  }
  
  /// 한글 이름
  String get displayName {
    switch (this) {
      case EncumbranceTier.normal:
        return '정상';
      case EncumbranceTier.uncomfortable:
        return '불편';
      case EncumbranceTier.danger:
        return '위험';
      case EncumbranceTier.collapse:
        return '붕괴';
    }
  }
}

/// 가방 슬롯 기반 인벤토리 시스템 (v6.2 설계안)
/// 
/// ## 3단 계층 구조
/// - 가방 슬롯 (Bag Slot): 가방을 장착하는 슬롯
/// - 가방 (Bag): 아이템 슬롯을 제공하고 최대 무게를 증가시킴
/// - 아이템 슬롯 (Item Slot): 아이템 1개를 보관
/// 
/// ## 과적 계산
/// - overweight% = (curWeight - maxWeight) / maxWeight × 100
/// - maxWeight = Σ(가방별 무게 보너스)
/// 
/// ## 패널티
/// - 스태미나 회복: 덧셈 방식 (0 / -0.1 / -0.2 / -0.3)
/// - 쿨타임 계수 E: 1.0 / 1.0 / 0.8 / 0.6
class InventorySystem {
  /// 최대 가방 슬롯 하드 캡
  static const int maxBagSlots = 20;
  
  /// 최대 무게 하드 캡
  static const int maxWeightHardCap = 54;
  
  /// UI 히스테리시스 딜레이 (0.5초)
  static const Duration tierChangeDelay = Duration(milliseconds: 500);
  
  /// (legacy compatibility) 이전 그리드 인벤토리에서 쓰던 생성자 시그니처를 유지합니다.
  final int width;
  final int height;

  /// (legacy compatibility) 일부 그리드 유틸/테스트 코드가 참조합니다.
  final GridMap gridMap;

  /// (legacy compatibility) 기존 무게 단위 시스템 호환용
  /// 새 시스템에서는 _bags의 weightBonus 합으로 계산됩니다.
  int maxWeightUnits;

  final SynergySystem synergySystem;
  final ItemAcquisitionHistory acquisitionHistory;
  final CombatLockSystem lockSystem;

  /// 장착된 가방 목록
  final List<Bag> _bags = [];
  
  /// 현재 사용 중인 가방 슬롯 수
  int _usedBagSlots = 0;
  
  /// UI 히스테리시스용: 마지막으로 표시된 단계
  EncumbranceTier _displayedTier = EncumbranceTier.normal;
  
  /// UI 히스테리시스용: 마지막 단계 변경 시간
  DateTime? _lastTierChangeTime;

  /// 아이템 추가 이벤트 스트림
  final StreamController<InventoryItem> _itemAddedController =
      StreamController.broadcast();
  Stream<InventoryItem> get onItemAdded => _itemAddedController.stream;

  InventorySystem({
    required this.width,
    required this.height,
    this.maxWeightUnits = 40, // legacy 호환용 (실제로는 가방 보너스로 계산)
    List<SynergyInfo> synergies = const [],
    bool initWithStarterBags = true,
  })  : gridMap = GridMap(width, height),
        synergySystem = SynergySystem(synergies),
        acquisitionHistory = ItemAcquisitionHistory(),
        lockSystem = CombatLockSystem() {
    // 시작 가방 구성 초기화 (기본 가방 ×3)
    if (initWithStarterBags) {
      for (final bag in BagFactory.createStarterBags()) {
        _addBagInternal(bag);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 가방 관련 API
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// 장착된 가방 목록 (읽기 전용)
  List<Bag> get bags => List.unmodifiable(_bags);
  
  /// 현재 사용 중인 가방 슬롯 수
  int get usedBagSlots => _usedBagSlots;
  
  /// 남은 가방 슬롯 수
  int get availableBagSlots => maxBagSlots - _usedBagSlots;
  
  /// 가방 슬롯이 가득 찼는지 확인
  bool get isBagSlotsFull => _usedBagSlots >= maxBagSlots;
  
  /// 가방 추가 가능 여부 확인 (BagType 기반)
  bool canAddBag(BagType type) {
    return availableBagSlots >= type.bagSlotCost;
  }
  
  /// 가방 추가 가능 여부 확인 (bagSlotCost 직접 지정)
  bool canAddBagByCost(int bagSlotCost) {
    return availableBagSlots >= bagSlotCost;
  }
  
  /// 가방 장착
  /// 
  /// 성공 시 true, 슬롯 부족 또는 잠금 상태면 false 반환.
  bool addBag(Bag bag) {
    final lockCheck = lockSystem.canPerformAction('가방 장착');
    if (!lockCheck.allowed) {
      print('[InventorySystem] ${lockCheck.message}');
      return false;
    }
    
    // JSON 기반 가방(type이 null)과 enum 기반 가방 모두 지원
    final bagSlotCost = bag.bagSlotCost;
    if (!canAddBagByCost(bagSlotCost)) {
      print('[InventorySystem] 가방 슬롯 부족: $bagSlotCost 필요, $availableBagSlots 남음');
      return false;
    }
    
    return _addBagInternal(bag);
  }
  
  /// 내부 가방 추가 (잠금 체크 없음)
  bool _addBagInternal(Bag bag) {
    _bags.add(bag);
    _usedBagSlots += bag.bagSlotCost;
    return true;
  }
  
  /// 가방 제거
  /// 
  /// 내부 아이템은 다른 빈 슬롯으로 이동하거나, 없으면 파괴됩니다.
  /// 반환: (성공 여부, 파괴된 아이템 목록)
  (bool success, List<InventoryItem> destroyedItems) removeBag(Bag bag) {
    final lockCheck = lockSystem.canPerformAction('가방 제거');
    if (!lockCheck.allowed) {
      print('[InventorySystem] ${lockCheck.message}');
      return (false, []);
    }
    
    if (!_bags.contains(bag)) {
      return (false, []);
    }
    
    // 가방 내 아이템들을 다른 빈 슬롯으로 이동 시도
    final itemsToMove = bag.items;
    final destroyedItems = <InventoryItem>[];
    
    for (final item in itemsToMove) {
      // 다른 가방의 빈 슬롯 찾기
      bool moved = false;
      for (final otherBag in _bags) {
        if (otherBag != bag && otherBag.hasEmptySlot) {
          bag.removeItem(item);
          otherBag.addItem(item);
          moved = true;
          break;
        }
      }
      
      if (!moved) {
        // 빈 슬롯 없음 - 아이템 파괴
        bag.removeItem(item);
        destroyedItems.add(item);
      }
    }
    
    // 가방 제거
    _bags.remove(bag);
    _usedBagSlots -= bag.bagSlotCost;
    
    if (destroyedItems.isNotEmpty) {
      print('[InventorySystem] ⚠️ 아이템 ${destroyedItems.length}개 파괴됨: ${destroyedItems.map((i) => i.name).join(', ')}');
    }
    
    return (true, destroyedItems);
  }
  
  /// ID로 가방 찾기
  Bag? getBagById(String bagId) {
    return _bags.where((b) => b.id == bagId).firstOrNull;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 아이템 관련 API
  // ═══════════════════════════════════════════════════════════════════════════

  /// 전체 아이템 목록 (모든 가방 내 아이템)
  List<InventoryItem> get items {
    return _bags.expand((bag) => bag.items).toList();
  }

  /// (legacy compatibility) placedItems = 전체 아이템
  List<InventoryItem> get placedItems => items;

  /// (legacy compatibility) unplacedItems는 항상 빈 리스트
  List<InventoryItem> get unplacedItems => const [];
  
  /// 전체 아이템 슬롯 수 (모든 가방의 슬롯 합)
  int get totalItemSlots {
    return _bags.fold(0, (sum, bag) => sum + bag.itemSlotCount);
  }
  
  /// 사용 중인 아이템 슬롯 수
  int get usedItemSlots {
    return _bags.fold(0, (sum, bag) => sum + bag.usedSlotCount);
  }
  
  /// 빈 아이템 슬롯 수
  int get emptyItemSlots => totalItemSlots - usedItemSlots;
  
  /// 아이템 슬롯이 가득 찼는지 확인
  bool get isItemSlotsFull => emptyItemSlots <= 0;

  /// 아이템 추가
  /// 
  /// 빈 아이템 슬롯을 가진 가방에 추가합니다.
  /// 가방 아이템인 경우 자동으로 Bag으로 변환하여 장착합니다.
  bool tryAddItem(
    InventoryItem item, {
    String? location,
    String? condition,
    Map<String, dynamic>? context,
  }) {
    final lockCheck = lockSystem.canPerformAction('아이템 추가');
    if (!lockCheck.allowed) {
      print('[InventorySystem] ${lockCheck.message}');
      return false;
    }

    // 가방 아이템인 경우 자동으로 Bag으로 변환하여 장착
    if (item.isBag) {
      final bag = BagFactory.fromInventoryItem(item);
      if (bag != null) {
        final success = addBag(bag);
        if (success) {
          print('[InventorySystem] 가방 아이템을 Bag으로 변환하여 장착: ${item.name}');
          acquisitionHistory.recordAcquisition(
            itemId: item.id,
            location: location,
            condition: condition,
            context: context,
          );
        }
        return success;
      } else {
        print('[InventorySystem] 가방 아이템 변환 실패: ${item.name}');
        return false;
      }
    }

    // 일반 아이템: 빈 슬롯이 있는 가방 찾기
    for (final bag in _bags) {
      if (bag.hasEmptySlot) {
        // 위치/회전 정규화 (텍스트형 인벤토리)
        item.position = null;
        
        bag.addItem(item);
        _itemAddedController.add(item);

        acquisitionHistory.recordAcquisition(
          itemId: item.id,
          location: location,
          condition: condition,
          context: context,
        );

        return true;
      }
    }
    
    print('[InventorySystem] 아이템 슬롯 부족');
    return false;
  }

  /// 아이템 제거
  bool removeItem(InventoryItem item) {
    final lockCheck = lockSystem.canPerformAction('아이템 제거');
    if (!lockCheck.allowed) {
      print('[InventorySystem] ${lockCheck.message}');
      return false;
    }

    for (final bag in _bags) {
      if (bag.removeItem(item)) {
        return true;
      }
    }
    return false;
  }

  /// 아이템 ID로 제거 (첫 번째 매칭만)
  bool removeItemById(String itemId) {
    final lockCheck = lockSystem.canPerformAction('아이템 제거');
    if (!lockCheck.allowed) {
      print('[InventorySystem] ${lockCheck.message}');
      return false;
    }

    for (final bag in _bags) {
      if (bag.removeItemById(itemId) != null) {
        return true;
      }
    }
    return false;
  }

  /// 아이템 ID로 검색 (첫 번째 매칭)
  InventoryItem? getItemById(String itemId) {
    for (final bag in _bags) {
      final item = bag.getItemById(itemId);
      if (item != null) return item;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 무게 및 과적 계산 (v6.2 설계안)
  // ═══════════════════════════════════════════════════════════════════════════

  /// 현재 무게 (모든 아이템 무게 합)
  int get currentWeightUnits {
    int sum = 0;
    for (final item in items) {
      sum += _itemTotalWeightUnits(item);
    }
    return sum;
  }

  /// 현재 무게 (실수 표기용, 0.5 단위)
  double get currentWeight => currentWeightUnits / 2.0;

  /// 최대 무게 = Σ(가방 무게 보너스), 하드캡 100 적용
  int get maxWeightFromBags {
    final total = _bags.fold(0, (sum, bag) => sum + bag.weightBonus);
    return total > maxWeightHardCap ? maxWeightHardCap : total;
  }
  
  /// 최대 무게 (실수 표기용)
  /// 
  /// 가방 시스템 기반 계산을 우선 사용합니다.
  double get maxWeight {
    // 가방이 있으면 가방 보너스 합 사용, 없으면 legacy 값 사용
    if (_bags.isNotEmpty) {
      return maxWeightFromBags.toDouble();
    }
    return maxWeightUnits / 2.0;
  }

  /// 과적 퍼센트 (v6.2 공식)
  /// 
  /// - curWeight ≤ maxWeight → 0%
  /// - curWeight > maxWeight → ((curWeight - maxWeight) / maxWeight) × 100
  double get overweightPercent {
    final cur = currentWeight;
    final max = maxWeight;
    if (max <= 0) return double.infinity;
    if (cur <= max) return 0.0;
    return ((cur - max) / max) * 100.0;
  }

  /// (legacy compatibility) 초과 비율 R = W/C
  double get encumbranceRatio {
    final max = maxWeight;
    if (max <= 0) return double.infinity;
    return currentWeight / max;
  }

  /// 과적 단계 (v6.2 설계안)
  /// 
  /// - 정상(Normal): overweight = 0%
  /// - 불편(Uncomfortable): 0% < overweight ≤ 20%
  /// - 위험(Danger): 20% < overweight ≤ 50%
  /// - 붕괴(Collapse): 50% < overweight
  EncumbranceTier get encumbranceTier {
    final percent = overweightPercent;
    if (percent <= 0) return EncumbranceTier.normal;
    if (percent <= 20) return EncumbranceTier.uncomfortable;
    if (percent <= 50) return EncumbranceTier.danger;
    return EncumbranceTier.collapse;
  }
  
  /// UI 표시용 과적 단계 (히스테리시스 적용)
  /// 
  /// 단계 변경 후 0.5초 이내에는 이전 단계를 유지합니다.
  EncumbranceTier get displayedEncumbranceTier {
    final actualTier = encumbranceTier;
    final now = DateTime.now();
    
    if (actualTier != _displayedTier) {
      if (_lastTierChangeTime == null || 
          now.difference(_lastTierChangeTime!) >= tierChangeDelay) {
        // 딜레이가 지났으면 새 단계로 업데이트
        _displayedTier = actualTier;
        _lastTierChangeTime = now;
      }
    }
    
    return _displayedTier;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 패널티 계산 (v6.2 설계안)
  // ═══════════════════════════════════════════════════════════════════════════

  /// 쿨타임 계수 E (v6.2)
  /// 
  /// - Normal: 1.0
  /// - Uncomfortable: 1.0
  /// - Danger: 0.8
  /// - Collapse: 0.6
  double get cooldownTickRateMultiplier {
    return encumbranceTier.cooldownMultiplier;
  }
  
  /// 스태미나 회복 델타 (v6.2, 덧셈 방식)
  /// 
  /// - Normal: 0
  /// - Uncomfortable: -0.1
  /// - Danger: -0.2
  /// - Collapse: -0.3
  double get staminaRecoveryDelta {
    return encumbranceTier.staminaDelta;
  }

  /// (legacy compatibility) 스태미나 회복 배율 (곱셈 방식)
  /// 
  /// 새 코드에서는 staminaRecoveryDelta를 사용하세요.
  double get staminaRegenMultiplier {
    // legacy 호환: delta를 multiplier로 변환 (base=1.0 가정)
    // delta=-0.1 → multiplier=0.9
    return 1.0 + staminaRecoveryDelta;
  }

  /// (legacy compatibility) 쿨다운 페널티 배율
  double get cooldownPenaltyMultiplier {
    // E가 0.8이면 쿨다운이 25% 더 오래 걸림 → 1/0.8 = 1.25
    return 1.0 / cooldownTickRateMultiplier;
  }

  /// 과적 요약 문구
  String get encumbranceSummary {
    final tier = encumbranceTier;
    switch (tier) {
      case EncumbranceTier.normal:
        return '정상';
      case EncumbranceTier.uncomfortable:
        return '과적(불편): 스태미나 회복 -0.1/s';
      case EncumbranceTier.danger:
        return '과적(위험): 스태미나 -0.2/s, 쿨타임 ×0.8';
      case EncumbranceTier.collapse:
        return '과적(붕괴): 스태미나 -0.3/s, 쿨타임 ×0.6';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 히스토리 및 시너지
  // ═══════════════════════════════════════════════════════════════════════════

  bool hasAcquiredItem(String itemId) {
    return acquisitionHistory.hasAcquiredItem(itemId);
  }

  bool checkAcquisitionOrder(List<String> itemIds) {
    return acquisitionHistory.checkAcquisitionOrder(itemIds);
  }

  List<ItemAcquisitionRecord> getAcquisitionHistory() {
    return acquisitionHistory.getAcquisitionHistory();
  }

  List<ItemAcquisitionRecord> getItemAcquisitions(String itemId) {
    return acquisitionHistory.getItemAcquisitions(itemId);
  }

  List<ItemAcquisitionRecord> getAcquisitionsByDateRange(
    DateTime start,
    DateTime end,
  ) {
    return acquisitionHistory.getAcquisitionsByDateRange(start, end);
  }

  List<ItemAcquisitionRecord> getAcquisitionsByLocation(String location) {
    return acquisitionHistory.getAcquisitionsByLocation(location);
  }

  List<ItemAcquisitionRecord> getAcquisitionsByCondition(String condition) {
    return acquisitionHistory.getAcquisitionsByCondition(condition);
  }

  ItemAcquisitionRecord? getLatestAcquisition() {
    return acquisitionHistory.getLatestAcquisition();
  }

  DateTime? getFirstAcquisitionTime(String itemId) {
    return acquisitionHistory.getFirstAcquisitionTime(itemId);
  }

  List<SynergyInfo> getActiveSynergies() {
    return synergySystem.getActiveSynergies(placedItems);
  }

  List<SynergyInfo> getItemSynergies(String itemId) {
    return synergySystem.getRelatedSynergies(itemId, placedItems);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 초기화 및 유틸리티
  // ═══════════════════════════════════════════════════════════════════════════

  void clear() {
    for (final bag in _bags) {
      bag.clear();
    }
    _bags.clear();
    _usedBagSlots = 0;
    acquisitionHistory.clear();
    gridMap.clear();
    _displayedTier = EncumbranceTier.normal;
    _lastTierChangeTime = null;
  }

  void resetForNewRun() {
    clear();
    if (lockSystem.isLocked) {
      lockSystem.unlock();
    }
    // 시작 가방 구성으로 재초기화
    for (final bag in BagFactory.createStarterBags()) {
      _addBagInternal(bag);
    }
  }

  String debugPrint() {
    final buffer = StringBuffer();
    buffer.writeln('=== Inventory System Debug (Bag-based v6.2) ===');
    buffer.writeln('Bag slots: $_usedBagSlots / $maxBagSlots');
    buffer.writeln('Item slots: $usedItemSlots / $totalItemSlots');
    buffer.writeln('Weight: ${currentWeight.toStringAsFixed(1)} / ${maxWeight.toStringAsFixed(1)}');
    buffer.writeln('Overweight: ${overweightPercent.toStringAsFixed(1)}%');
    buffer.writeln('Tier: ${encumbranceTier.displayName}');
    buffer.writeln('E (cooldown): ${cooldownTickRateMultiplier.toStringAsFixed(2)}');
    buffer.writeln('Stamina delta: ${staminaRecoveryDelta.toStringAsFixed(2)}/s');
    buffer.writeln();

    if (_bags.isNotEmpty) {
      buffer.writeln('Bags:');
      for (final bag in _bags) {
        buffer.writeln('  📦 ${bag.name} (${bag.usedSlotCount}/${bag.itemSlotCount} items, +${bag.weightBonus} weight)');
        for (final item in bag.items) {
          final weight = _itemTotalWeightUnits(item) / 2.0;
          buffer.writeln('    - ${item.name} (w=${weight.toStringAsFixed(1)})');
        }
      }
    }

    final activeSynergies = getActiveSynergies();
    if (activeSynergies.isNotEmpty) {
      buffer.writeln('\nActive Synergies:');
      for (final synergy in activeSynergies) {
        buffer.writeln('  🔗 ${synergy.name}');
      }
    }

    return buffer.toString();
  }

  void dispose() {
    _itemAddedController.close();
    lockSystem.dispose();
  }

  int _itemTotalWeightUnits(InventoryItem item) {
    final qty = _getQuantity(item);
    final unit = weightUnitsForInventoryItemId(item.id);
    return unit * qty;
  }

  int _getQuantity(InventoryItem item) {
    final raw = item.properties['quantity'];
    if (raw is int && raw > 0) return raw;
    if (raw is num && raw > 0) return raw.toInt();
    return 1;
  }
}

extension FirstWhereOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
