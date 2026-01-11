import 'dart:async';
import 'dart:math' as math;
import 'storage_item.dart';

/// 보관함 이벤트 타입
enum StorageEventType {
  itemStored,      // 아이템 보관
  itemRetrieved,   // 아이템 회수
  capacityChanged, // 최대 보관 갯수 변경
  storageFull,     // 보관함 가득 참
}

/// 보관함 이벤트 클래스
class StorageEvent {
  final StorageEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  
  StorageEvent({
    required this.type,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  @override
  String toString() => 'StorageEvent{type: $type, data: $data}';
}

/// 보관함 시스템
/// 그리드나 위치 개념 없이 단순히 아이템 목록을 관리
class StorageSystem {
  final List<StorageItem> _items = [];
  int _maxCapacity;
  
  // 이벤트 스트림 컨트롤러들
  final StreamController<StorageEvent> _eventController = StreamController.broadcast();
  final StreamController<StorageItem> _itemStoredController = StreamController.broadcast();
  final StreamController<StorageItem> _itemRetrievedController = StreamController.broadcast();
  
  StorageSystem({
    int maxCapacity = 10, // 기본 최대 보관 갯수
  }) : _maxCapacity = maxCapacity;
  
  // ═══════════════════════════════════════════════════════════════
  // Getters
  // ═══════════════════════════════════════════════════════════════
  
  /// 현재 보관된 아이템 목록 (읽기 전용)
  List<StorageItem> get items => List.unmodifiable(_items);
  
  /// 현재 보관된 아이템 갯수
  int get currentCount => _items.length;
  
  /// 최대 보관 갯수
  int get maxCapacity => _maxCapacity;
  
  /// 남은 보관 가능 갯수
  int get remainingCapacity => math.max(0, _maxCapacity - _items.length);
  
  /// 보관함이 가득 찼는지 여부
  bool get isFull => _items.length >= _maxCapacity;
  
  /// 보관함이 비어있는지 여부
  bool get isEmpty => _items.isEmpty;
  
  // ═══════════════════════════════════════════════════════════════
  // 이벤트 스트림
  // ═══════════════════════════════════════════════════════════════
  
  /// 모든 보관함 이벤트 스트림
  Stream<StorageEvent> get onEvent => _eventController.stream;
  
  /// 아이템 보관 이벤트 스트림
  Stream<StorageItem> get onItemStored => _itemStoredController.stream;
  
  /// 아이템 회수 이벤트 스트림
  Stream<StorageItem> get onItemRetrieved => _itemRetrievedController.stream;
  
  // ═══════════════════════════════════════════════════════════════
  // 핵심 기능
  // ═══════════════════════════════════════════════════════════════
  
  /// 아이템 보관 시도
  /// 성공하면 true, 실패하면 false 반환
  bool tryStoreItem(StorageItem item) {
    // 이미 존재하는 아이템인지 확인
    if (_items.any((existingItem) => existingItem.id == item.id)) {
      return false;
    }
    
    // 보관함이 가득 찬 경우
    if (isFull) {
      _dispatchEvent(StorageEventType.storageFull, {
        'attemptedItem': item,
        'currentCount': currentCount,
        'maxCapacity': maxCapacity,
      });
      return false;
    }
    
    // 아이템 보관
    _items.add(item);
    
    // 이벤트 발생
    _dispatchEvent(StorageEventType.itemStored, {
      'item': item,
      'currentCount': currentCount,
      'remainingCapacity': remainingCapacity,
    });
    
    _itemStoredController.add(item);
    
    return true;
  }
  
  /// 아이템 ID로 회수
  StorageItem? retrieveItemById(String itemId) {
    final itemIndex = _items.indexWhere((item) => item.id == itemId);
    if (itemIndex == -1) return null;
    
    final item = _items.removeAt(itemIndex);
    
    // 이벤트 발생
    _dispatchEvent(StorageEventType.itemRetrieved, {
      'item': item,
      'currentCount': currentCount,
      'remainingCapacity': remainingCapacity,
    });
    
    _itemRetrievedController.add(item);
    
    return item;
  }
  
  /// 특정 아이템 회수
  bool retrieveItem(StorageItem item) {
    final removed = _items.remove(item);
    
    if (removed) {
      // 이벤트 발생
      _dispatchEvent(StorageEventType.itemRetrieved, {
        'item': item,
        'currentCount': currentCount,
        'remainingCapacity': remainingCapacity,
      });
      
      _itemRetrievedController.add(item);
    }
    
    return removed;
  }
  
  /// 인덱스로 아이템 회수
  StorageItem? retrieveItemAt(int index) {
    if (index < 0 || index >= _items.length) return null;
    
    final item = _items.removeAt(index);
    
    // 이벤트 발생
    _dispatchEvent(StorageEventType.itemRetrieved, {
      'item': item,
      'currentCount': currentCount,
      'remainingCapacity': remainingCapacity,
    });
    
    _itemRetrievedController.add(item);
    
    return item;
  }
  
  // ═══════════════════════════════════════════════════════════════
  // 용량 관리
  // ═══════════════════════════════════════════════════════════════
  
  /// 최대 보관 갯수 변경
  void setMaxCapacity(int newCapacity) {
    if (newCapacity < 0) newCapacity = 0;
    
    final oldCapacity = _maxCapacity;
    _maxCapacity = newCapacity;
    
    // 용량이 줄어들어서 현재 아이템이 초과되는 경우 처리
    if (_items.length > _maxCapacity) {
      // 초과된 아이템들을 제거하지 않고 경고만 발생
      // 실제 제거는 게임 로직에서 결정하도록 함
    }
    
    _dispatchEvent(StorageEventType.capacityChanged, {
      'oldCapacity': oldCapacity,
      'newCapacity': newCapacity,
      'currentCount': currentCount,
      'isOverCapacity': _items.length > _maxCapacity,
    });
  }
  
  /// 최대 보관 갯수 증가
  void increaseCapacity(int amount) {
    setMaxCapacity(_maxCapacity + amount);
  }
  
  /// 최대 보관 갯수 감소
  void decreaseCapacity(int amount) {
    setMaxCapacity(_maxCapacity - amount);
  }
  
  // ═══════════════════════════════════════════════════════════════
  // 검색 및 조회
  // ═══════════════════════════════════════════════════════════════
  
  /// ID로 아이템 찾기
  StorageItem? findItemById(String itemId) {
    try {
      return _items.firstWhere((item) => item.id == itemId);
    } catch (e) {
      return null;
    }
  }
  
  /// 이름으로 아이템 찾기 (부분 일치)
  List<StorageItem> findItemsByName(String name, {bool exactMatch = false}) {
    if (exactMatch) {
      return _items.where((item) => item.name == name).toList();
    } else {
      return _items.where((item) => 
        item.name.toLowerCase().contains(name.toLowerCase())
      ).toList();
    }
  }
  
  /// 속성으로 아이템 찾기
  List<StorageItem> findItemsByProperty(String key, dynamic value) {
    return _items.where((item) => item.properties[key] == value).toList();
  }
  
  /// 특정 아이템이 보관되어 있는지 확인
  bool containsItem(String itemId) {
    return _items.any((item) => item.id == itemId);
  }
  
  /// 특정 아이템의 인덱스 찾기
  int getItemIndex(String itemId) {
    return _items.indexWhere((item) => item.id == itemId);
  }
  
  // ═══════════════════════════════════════════════════════════════
  // 정렬 및 관리
  // ═══════════════════════════════════════════════════════════════
  
  /// 이름순으로 정렬
  void sortByName({bool ascending = true}) {
    _items.sort((a, b) => ascending 
      ? a.name.compareTo(b.name)
      : b.name.compareTo(a.name)
    );
  }
  
  /// 추가된 시간순으로 정렬
  void sortByAddedTime({bool ascending = true}) {
    _items.sort((a, b) => ascending 
      ? a.addedAt.compareTo(b.addedAt)
      : b.addedAt.compareTo(a.addedAt)
    );
  }
  
  /// 모든 아이템 제거
  void clear() {
    final removedItems = List<StorageItem>.from(_items);
    _items.clear();
    
    for (final item in removedItems) {
      _dispatchEvent(StorageEventType.itemRetrieved, {
        'item': item,
        'currentCount': currentCount,
        'remainingCapacity': remainingCapacity,
      });
    }
  }
  
  // ═══════════════════════════════════════════════════════════════
  // 내부 유틸리티
  // ═══════════════════════════════════════════════════════════════
  
  /// 이벤트 발생
  void _dispatchEvent(StorageEventType type, Map<String, dynamic> data) {
    final event = StorageEvent(type: type, data: data);
    _eventController.add(event);
  }
  
  // ═══════════════════════════════════════════════════════════════
  // 리소스 정리
  // ═══════════════════════════════════════════════════════════════
  
  /// 스트림 컨트롤러 정리
  void dispose() {
    _eventController.close();
    _itemStoredController.close();
    _itemRetrievedController.close();
  }
  
  // ═══════════════════════════════════════════════════════════════
  // 디버깅 및 정보
  // ═══════════════════════════════════════════════════════════════
  
  /// 보관함 상태 정보
  Map<String, dynamic> getStorageInfo() {
    return {
      'currentCount': currentCount,
      'maxCapacity': maxCapacity,
      'remainingCapacity': remainingCapacity,
      'isFull': isFull,
      'isEmpty': isEmpty,
      'items': _items.map((item) => item.toString()).toList(),
    };
  }
  
  @override
  String toString() {
    return 'StorageSystem{count: $currentCount/$maxCapacity, items: ${_items.length}}';
  }
}

/// 보관함용 아이템 클래스
/// 인벤토리와 달리 위치 개념은 없지만 회전 상태는 유지
class StorageItem {
  final String id;
  final String name;
  final String description;
  final String iconPath;
  final Map<String, dynamic> properties;
  final DateTime addedAt; // 보관함에 추가된 시간
  
  // 회전 관련 필드 추가
  final int baseWidth;        // 기본 너비
  final int baseHeight;       // 기본 높이  
  bool isRotated;             // 회전 상태
  
  StorageItem({
    required this.id,
    required this.name,
    required this.description,
    required this.iconPath,
    required this.baseWidth,
    required this.baseHeight,
    this.isRotated = false,
    this.properties = const {},
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();
  
  /// 현재 회전 상태를 고려한 실제 너비
  int get currentWidth => isRotated ? baseHeight : baseWidth;
  
  /// 현재 회전 상태를 고려한 실제 높이  
  int get currentHeight => isRotated ? baseWidth : baseHeight;
  
  /// 시계방향 90도 회전
  void rotate() {
    isRotated = !isRotated;
  }
  
  /// InventoryItem에서 StorageItem으로 변환
  factory StorageItem.fromInventoryItem(dynamic inventoryItem) {
    return StorageItem(
      id: inventoryItem.id,
      name: inventoryItem.name,
      description: inventoryItem.description,
      iconPath: inventoryItem.iconPath,
      baseWidth: inventoryItem.baseWidth,
      baseHeight: inventoryItem.baseHeight,
      isRotated: inventoryItem.isRotated,
      properties: Map<String, dynamic>.from(inventoryItem.properties),
    );
  }
  
  /// StorageItem을 InventoryItem으로 변환
  /// (인벤토리 시스템으로 다시 이동할 때 사용)
  dynamic toInventoryItem() {
    // 이 부분은 실제 InventoryItem 클래스 구조에 맞게 수정 필요
    // 현재는 동적 타입으로 반환
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconPath': iconPath,
      'baseWidth': baseWidth,
      'baseHeight': baseHeight,
      'isRotated': isRotated,
      'properties': properties,
    };
  }
  
  /// 아이템 복사
  StorageItem copyWith({
    String? id,
    String? name,
    String? description,
    String? iconPath,
    int? baseWidth,
    int? baseHeight,
    bool? isRotated,
    Map<String, dynamic>? properties,
    DateTime? addedAt,
  }) {
    return StorageItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconPath: iconPath ?? this.iconPath,
      baseWidth: baseWidth ?? this.baseWidth,
      baseHeight: baseHeight ?? this.baseHeight,
      isRotated: isRotated ?? this.isRotated,
      properties: properties ?? this.properties,
      addedAt: addedAt ?? this.addedAt,
    );
  }
  
  @override
  String toString() {
    return 'StorageItem{id: $id, name: $name, size: ${currentWidth}x${currentHeight}, rotated: $isRotated, addedAt: $addedAt}';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StorageItem && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
} 