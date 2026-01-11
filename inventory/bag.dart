import 'inventory_item.dart';

/// 가방 종류 (v6.2 설계안)
/// 
/// 각 가방 타입은 점유 슬롯 수, 제공 아이템 슬롯 수, 무게 보너스가 다릅니다.
enum BagType {
  /// 기본 가방: 슬롯 1, 아이템 1, 무게 +5
  basic,
  
  /// 구멍난 가방: 슬롯 1, 아이템 1, 무게 +3
  /// - 저품질, 항상 저렴한 타협 선택지
  damaged,
  
  /// 대형 가방: 슬롯 2, 아이템 2, 무게 +10
  /// - 슬롯을 빠르게 소모하는 대신 안정적인 무게 효율
  large,
  
  /// 구멍난 대형 가방: 슬롯 2, 아이템 2, 무게 +5
  /// - 가장 낮은 효율의 함정 선택지
  damagedLarge,
  
  /// 파우치: 슬롯 1, 아이템 1, 무게 +1
  /// - 무게 증가가 거의 필요 없을 때의 선택
  pouch,
}

/// BagType 확장 메서드
extension BagTypeExtension on BagType {
  /// 점유하는 가방 슬롯 수
  int get bagSlotCost {
    switch (this) {
      case BagType.basic:
      case BagType.damaged:
      case BagType.pouch:
        return 1;
      case BagType.large:
      case BagType.damagedLarge:
        return 2;
    }
  }
  
  /// 제공하는 아이템 슬롯 수
  int get itemSlotCount {
    switch (this) {
      case BagType.basic:
      case BagType.damaged:
      case BagType.pouch:
        return 1;
      case BagType.large:
      case BagType.damagedLarge:
        return 2;
    }
  }
  
  /// 최대 무게 증가량
  int get weightBonus {
    switch (this) {
      case BagType.basic:
        return 5;
      case BagType.damaged:
        return 3;
      case BagType.large:
        return 10;
      case BagType.damagedLarge:
        return 5;
      case BagType.pouch:
        return 1;
    }
  }
  
  /// 한글 이름
  String get displayName {
    switch (this) {
      case BagType.basic:
        return '기본 가방';
      case BagType.damaged:
        return '구멍난 가방';
      case BagType.large:
        return '대형 가방';
      case BagType.damagedLarge:
        return '구멍난 대형 가방';
      case BagType.pouch:
        return '파우치';
    }
  }
  
  /// 설명
  String get description {
    switch (this) {
      case BagType.basic:
        return '모든 효율 계산의 기준이 되는 표준 가방';
      case BagType.damaged:
        return '저품질 가방. 기본 가방보다 항상 저렴한 타협 선택지';
      case BagType.large:
        return '슬롯을 빠르게 소모하는 대신 안정적인 무게 효율을 제공';
      case BagType.damagedLarge:
        return '가장 낮은 효율의 가방. 명확한 함정 선택지';
      case BagType.pouch:
        return '무게 증가가 거의 필요 없을 때의 최선 선택';
    }
  }
}

/// 가방 클래스
/// 
/// 가방 슬롯에 장착되어 아이템 슬롯을 제공하고 최대 무게를 증가시킵니다.
class Bag {
  /// 가방 고유 ID
  final String id;
  
  /// 가방 종류 (레거시 호환용, JSON 기반 가방은 null일 수 있음)
  final BagType? type;
  
  /// JSON 기반 가방 속성 (type이 null인 경우 사용)
  final String? _itemId;
  final String? _name;
  final String? _description;
  final int? _bagSlotCost;
  final int? _itemSlotCount;
  final int? _weightBonus;
  
  /// 아이템 슬롯 (null = 빈 슬롯)
  /// 
  /// 리스트 크기는 itemSlotCount와 동일하게 유지됩니다.
  final List<InventoryItem?> _itemSlots;
  
  /// 생성자 (BagType 기반, 레거시 호환용)
  Bag({
    required this.id,
    required this.type,
  }) : _itemId = null,
       _name = null,
       _description = null,
       _bagSlotCost = null,
       _itemSlotCount = null,
       _weightBonus = null,
       _itemSlots = List<InventoryItem?>.filled(type!.itemSlotCount, null);
  
  /// 생성자 (JSON 기반)
  Bag.fromJson({
    required this.id,
    required String itemId,
    required String name,
    required String description,
    required int bagSlotCost,
    required int itemSlotCount,
    required int weightBonus,
  }) : type = null,
       _itemId = itemId,
       _name = name,
       _description = description,
       _bagSlotCost = bagSlotCost,
       _itemSlotCount = itemSlotCount,
       _weightBonus = weightBonus,
       _itemSlots = List<InventoryItem?>.filled(itemSlotCount, null);
  
  /// 점유하는 가방 슬롯 수
  int get bagSlotCost => type?.bagSlotCost ?? _bagSlotCost ?? 1;
  
  /// 제공하는 아이템 슬롯 수
  int get itemSlotCount => type?.itemSlotCount ?? _itemSlotCount ?? 1;
  
  /// 최대 무게 증가량
  int get weightBonus => type?.weightBonus ?? _weightBonus ?? 0;
  
  /// 가방 이름 (JSON 기반인 경우)
  String get name => type?.displayName ?? _name ?? '가방';
  
  /// 가방 설명 (JSON 기반인 경우)
  String get description => type?.description ?? _description ?? '';
  
  /// 원본 아이템 ID (JSON 기반인 경우)
  String? get itemId => _itemId;
  
  /// 아이템 슬롯 목록 (읽기 전용)
  List<InventoryItem?> get itemSlots => List.unmodifiable(_itemSlots);
  
  /// 현재 가방에 담긴 아이템 목록 (null 제외)
  List<InventoryItem> get items => _itemSlots.whereType<InventoryItem>().toList();
  
  /// 사용 중인 아이템 슬롯 수
  int get usedSlotCount => items.length;
  
  /// 빈 아이템 슬롯 수
  int get emptySlotCount => itemSlotCount - usedSlotCount;
  
  /// 빈 슬롯이 있는지 확인
  bool get hasEmptySlot => emptySlotCount > 0;
  
  /// 가방이 비어있는지 확인
  bool get isEmpty => usedSlotCount == 0;
  
  /// 가방이 가득 찼는지 확인
  bool get isFull => emptySlotCount == 0;
  
  /// 현재 가방에 담긴 아이템들의 총 무게
  /// 
  /// 외부에서 무게 계산 함수를 주입받아 사용합니다.
  int calculateTotalWeight(int Function(InventoryItem) weightCalculator) {
    return items.fold(0, (sum, item) => sum + weightCalculator(item));
  }
  
  /// 아이템 추가
  /// 
  /// 빈 슬롯에 아이템을 추가합니다.
  /// 성공 시 true, 빈 슬롯이 없으면 false 반환.
  bool addItem(InventoryItem item) {
    final emptyIndex = _itemSlots.indexWhere((slot) => slot == null);
    if (emptyIndex == -1) return false;
    
    _itemSlots[emptyIndex] = item;
    return true;
  }
  
  /// 아이템 제거
  /// 
  /// 지정된 아이템을 슬롯에서 제거합니다.
  /// 성공 시 true, 아이템이 없으면 false 반환.
  bool removeItem(InventoryItem item) {
    final index = _itemSlots.indexWhere((slot) => slot == item);
    if (index == -1) return false;
    
    _itemSlots[index] = null;
    return true;
  }
  
  /// 아이템 ID로 제거
  /// 
  /// 지정된 ID의 첫 번째 아이템을 제거합니다.
  /// 제거된 아이템을 반환하고, 없으면 null 반환.
  InventoryItem? removeItemById(String itemId) {
    final index = _itemSlots.indexWhere((slot) => slot?.id == itemId);
    if (index == -1) return null;
    
    final item = _itemSlots[index];
    _itemSlots[index] = null;
    return item;
  }
  
  /// 특정 인덱스의 아이템 가져오기
  InventoryItem? getItemAt(int index) {
    if (index < 0 || index >= itemSlotCount) return null;
    return _itemSlots[index];
  }
  
  /// 특정 인덱스에 아이템 설정
  /// 
  /// 기존 아이템이 있으면 덮어씁니다.
  /// 성공 시 true, 인덱스가 유효하지 않으면 false 반환.
  bool setItemAt(int index, InventoryItem? item) {
    if (index < 0 || index >= itemSlotCount) return false;
    _itemSlots[index] = item;
    return true;
  }
  
  /// 가방 비우기
  /// 
  /// 제거된 아이템 목록을 반환합니다.
  List<InventoryItem> clear() {
    final removedItems = items;
    for (int i = 0; i < _itemSlots.length; i++) {
      _itemSlots[i] = null;
    }
    return removedItems;
  }
  
  /// 아이템 ID로 검색
  InventoryItem? getItemById(String itemId) {
    return _itemSlots.firstWhere(
      (slot) => slot?.id == itemId,
      orElse: () => null,
    );
  }
  
  /// 특정 아이템이 이 가방에 있는지 확인
  bool containsItem(InventoryItem item) {
    return _itemSlots.contains(item);
  }
  
  /// 특정 ID의 아이템이 이 가방에 있는지 확인
  bool containsItemById(String itemId) {
    return _itemSlots.any((slot) => slot?.id == itemId);
  }
  
  /// 복사본 생성 (아이템 포함)
  Bag copyWith({String? id, BagType? type}) {
    final newBag = Bag(
      id: id ?? this.id,
      type: type ?? this.type,
    );
    
    // 아이템 복사 (새 타입의 슬롯 수가 충분한 경우에만)
    for (int i = 0; i < _itemSlots.length && i < newBag.itemSlotCount; i++) {
      newBag._itemSlots[i] = _itemSlots[i];
    }
    
    return newBag;
  }
  
  @override
  String toString() {
    return 'Bag{id: $id, name: $name, items: $usedSlotCount/$itemSlotCount, weight: +$weightBonus}';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Bag && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}

/// 가방 팩토리 클래스
/// 
/// 가방 생성을 위한 유틸리티 메서드를 제공합니다.
class BagFactory {
  static int _idCounter = 0;
  
  /// 고유 ID 생성
  static String _generateId() {
    return 'bag_${++_idCounter}_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  /// InventoryItem에서 Bag 생성 (JSON 기반)
  /// 
  /// 가방 아이템을 받아서 Bag 객체로 변환합니다.
  /// 가방이 아닌 경우 null을 반환합니다.
  static Bag? fromInventoryItem(InventoryItem item, {String? customId}) {
    if (!item.isBag) return null;
    
    final bagProps = item.bagProperties;
    if (bagProps == null) return null;
    
    final bagSlotCost = (bagProps['bagSlotCost'] as num?)?.toInt() ?? 1;
    final itemSlotCount = (bagProps['itemSlotCount'] as num?)?.toInt() ?? 1;
    final weightBonus = (bagProps['weightBonus'] as num?)?.toInt() ?? 0;
    
    // JSON 기반 Bag 생성
    return Bag.fromJson(
      id: customId ?? _generateId(),
      itemId: item.id,
      name: item.name,
      description: item.description,
      bagSlotCost: bagSlotCost,
      itemSlotCount: itemSlotCount,
      weightBonus: weightBonus,
    );
  }
  
  /// 기본 가방 생성
  static Bag createBasic({String? id}) {
    return Bag(id: id ?? _generateId(), type: BagType.basic);
  }
  
  /// 구멍난 가방 생성
  static Bag createDamaged({String? id}) {
    return Bag(id: id ?? _generateId(), type: BagType.damaged);
  }
  
  /// 대형 가방 생성
  static Bag createLarge({String? id}) {
    return Bag(id: id ?? _generateId(), type: BagType.large);
  }
  
  /// 구멍난 대형 가방 생성
  static Bag createDamagedLarge({String? id}) {
    return Bag(id: id ?? _generateId(), type: BagType.damagedLarge);
  }
  
  /// 파우치 생성
  static Bag createPouch({String? id}) {
    return Bag(id: id ?? _generateId(), type: BagType.pouch);
  }
  
  /// 타입으로 가방 생성
  static Bag create(BagType type, {String? id}) {
    return Bag(id: id ?? _generateId(), type: type);
  }
  
  /// 시작 가방 구성 생성 (기본 가방 ×3)
  static List<Bag> createStarterBags() {
    return [
      createBasic(),
      createBasic(),
      createBasic(),
    ];
  }
  
  /// ID 카운터 리셋 (테스트용)
  static void resetIdCounter() {
    _idCounter = 0;
  }
}
