import 'dart:async';
import 'dart:math' as math;
import 'storage_item.dart';
import '../inventory/item_acquisition_history.dart'; // 기존 시스템 재사용

/// 자유 배치를 위한 위치 클래스
class StoragePosition {
  final double x;
  final double y;
  
  const StoragePosition(this.x, this.y);
  
  /// 두 위치 간의 거리 계산
  double distanceTo(StoragePosition other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }
  
  @override
  String toString() => 'StoragePosition($x, $y)';
}

/// 거리 기반 시너지 정보
class ProximitySynergy {
  final String name;
  final String description;
  final List<String> requiredItemIds;
  final double maxDistance;        // 최대 연결 거리
  final Map<String, dynamic> effects;
  
  const ProximitySynergy({
    required this.name,
    required this.description,
    required this.requiredItemIds,
    required this.maxDistance,
    required this.effects,
  });
}

/// 보관함 기반 대화 선택지
class StorageDialogueOption {
  final List<String> requiredStoredItems;     // 보관함에 있어야 하는 아이템들
  final List<String> requiredHistoryItems;   // 한번이라도 획득했어야 하는 아이템들
  final String targetNpc;
  final String optionText;
  final Map<String, dynamic> conditions;
  
  const StorageDialogueOption({
    this.requiredStoredItems = const [],
    this.requiredHistoryItems = const [],
    required this.targetNpc,
    required this.optionText,
    this.conditions = const {},
  });
}

/// 보관함 기반 인카운터
class StorageEncounter {
  final String encounterId;
  final String title;
  final String description;
  final List<String> requiredStoredItems;     // 현재 보관 중인 아이템
  final List<String> requiredHistoryItems;   // 획득 경험이 있는 아이템  
  final List<String> requiredSynergies;      // 활성화되어야 하는 시너지
  final Map<String, dynamic> conditions;
  final Map<String, dynamic> data;
  
  const StorageEncounter({
    required this.encounterId,
    required this.title,
    required this.description,
    this.requiredStoredItems = const [],
    this.requiredHistoryItems = const [],
    this.requiredSynergies = const [],
    this.conditions = const {},
    this.data = const {},
  });
}

/// 보관함 시스템 (자유 배치 + 조건부 콘텐츠)
class StorageSystem {
  final Map<String, StorageItem> _items = {};           // ID -> 아이템
  final Map<String, StoragePosition> _positions = {};   // ID -> 위치
  final List<ProximitySynergy> _proximitySynergies = [];
  final List<StorageDialogueOption> _dialogueOptions = [];
  final List<StorageEncounter> _encounters = [];
  final Set<String> _triggeredEncounters = {};
  
  int _maxCapacity;
  
  // 기존 시스템 재사용
  final ItemAcquisitionHistory acquisitionHistory;
  
  // 이벤트 스트림들
  final StreamController<StorageItem> _itemStoredController = StreamController.broadcast();
  final StreamController<StorageItem> _itemRetrievedController = StreamController.broadcast();
  final StreamController<StorageItem> _itemRotatedController = StreamController.broadcast();
  final StreamController<ProximitySynergy> _synergyActivatedController = StreamController.broadcast();
  final StreamController<StorageEncounter> _encounterTriggeredController = StreamController.broadcast();
  
  StorageSystem({
    int maxCapacity = 10,
    List<ProximitySynergy> synergies = const [],
    List<StorageDialogueOption> dialogueOptions = const [],
    List<StorageEncounter> encounters = const [],
    ItemAcquisitionHistory? acquisitionHistory,
  }) : _maxCapacity = maxCapacity,
       acquisitionHistory = acquisitionHistory ?? ItemAcquisitionHistory() {
    _proximitySynergies.addAll(synergies);
    _dialogueOptions.addAll(dialogueOptions);
    _encounters.addAll(encounters);
    
    // 아이템 추가/제거 시 조건부 콘텐츠 체크
    _itemStoredController.stream.listen(_checkEncountersOnItemChange);
    _itemRetrievedController.stream.listen(_checkEncountersOnItemChange);
  }
  
  // ═══════════════════════════════════════════════════════════════
  // 기본 기능
  // ═══════════════════════════════════════════════════════════════
  
  /// 아이템 보관 (자유 위치)
  bool tryStoreItem(StorageItem item, StoragePosition position) {
    if (_items.containsKey(item.id)) return false;
    if (_items.length >= _maxCapacity) return false;
    
    // 위치 충돌 검사 (선택사항)
    if (_isPositionOccupied(position, item)) return false;
    
    _items[item.id] = item;
    _positions[item.id] = position;
    
    // 획득 히스토리에 기록
    acquisitionHistory.recordAcquisition(
      itemId: item.id,
      location: 'storage',
      condition: 'stored_manually',
    );
    
    _itemStoredController.add(item);
    _checkProximitySynergies();
    
    return true;
  }
  
  /// 아이템 회수
  StorageItem? retrieveItem(String itemId) {
    final item = _items.remove(itemId);
    if (item != null) {
      _positions.remove(itemId);
      _itemRetrievedController.add(item);
      _checkProximitySynergies();
    }
    return item;
  }
  
  /// 아이템 이동
  bool moveItem(String itemId, StoragePosition newPosition) {
    if (!_items.containsKey(itemId)) return false;
    if (_isPositionOccupied(newPosition, _items[itemId]!, excludeItemId: itemId)) {
      return false;
    }
    
    _positions[itemId] = newPosition;
    _checkProximitySynergies();
    return true;
  }
  
  /// 아이템 회전 (기존 인벤토리 시스템과 동일)
  bool rotateItem(String itemId) {
    final item = _items[itemId];
    if (item == null) return false;
    
    item.rotate();
    _itemRotatedController.add(item);
    return true;
  }
  
  // ═══════════════════════════════════════════════════════════════
  // 거리 기반 시너지 시스템
  // ═══════════════════════════════════════════════════════════════
  
  /// 활성화된 근접 시너지들
  List<ProximitySynergy> getActiveSynergies() {
    final activeSynergies = <ProximitySynergy>[];
    
    for (final synergy in _proximitySynergies) {
      if (_isSynergyActive(synergy)) {
        activeSynergies.add(synergy);
      }
    }
    
    return activeSynergies;
  }
  
  /// 시너지가 활성화되었는지 확인
  bool _isSynergyActive(ProximitySynergy synergy) {
    // 필요한 모든 아이템이 보관되어 있는지 확인
    final requiredItems = synergy.requiredItemIds
        .map((id) => _items[id])
        .where((item) => item != null)
        .cast<StorageItem>()
        .toList();
    
    if (requiredItems.length != synergy.requiredItemIds.length) {
      return false;
    }
    
    // 거리 조건 확인 (모든 아이템이 서로 일정 거리 내에 있어야 함)
    for (int i = 0; i < requiredItems.length; i++) {
      for (int j = i + 1; j < requiredItems.length; j++) {
        final pos1 = _positions[requiredItems[i].id]!;
        final pos2 = _positions[requiredItems[j].id]!;
        
        if (pos1.distanceTo(pos2) > synergy.maxDistance) {
          return false;
        }
      }
    }
    
    return true;
  }
  
  /// 시너지 상태 변화 체크
  void _checkProximitySynergies() {
    final currentSynergies = getActiveSynergies();
    
    for (final synergy in currentSynergies) {
      _synergyActivatedController.add(synergy);
    }
  }
  
  // ═══════════════════════════════════════════════════════════════
  // 조건부 콘텐츠 시스템
  // ═══════════════════════════════════════════════════════════════
  
  /// NPC와의 대화에서 사용 가능한 새로운 선택지들
  List<String> getAvailableDialogueOptions(String npcId) {
    final options = <String>[];
    
    for (final option in _dialogueOptions) {
      if (option.targetNpc != 'any' && option.targetNpc != npcId) continue;
      
      // 현재 보관 중인 아이템 확인
      final hasStoredItems = option.requiredStoredItems.every(
        (itemId) => _items.containsKey(itemId)
      );
      
      // 획득 경험이 있는 아이템 확인
      final hasHistoryItems = option.requiredHistoryItems.every(
        (itemId) => acquisitionHistory.hasAcquiredItem(itemId)
      );
      
      if (hasStoredItems && hasHistoryItems) {
        options.add(option.optionText);
      }
    }
    
    return options;
  }
  
  /// 아이템 변화 시 새로운 인카운터 체크
  void _checkEncountersOnItemChange(StorageItem item) {
    for (final encounter in _encounters) {
      if (_triggeredEncounters.contains(encounter.encounterId)) continue;
      
      if (_shouldTriggerEncounter(encounter)) {
        _triggerEncounter(encounter);
      }
    }
  }
  
  /// 인카운터 발생 조건 확인
  bool _shouldTriggerEncounter(StorageEncounter encounter) {
    // 현재 보관 중인 아이템 확인
    final hasStoredItems = encounter.requiredStoredItems.every(
      (itemId) => _items.containsKey(itemId)
    );
    
    // 획득 경험이 있는 아이템 확인
    final hasHistoryItems = encounter.requiredHistoryItems.every(
      (itemId) => acquisitionHistory.hasAcquiredItem(itemId)
    );
    
    // 필요한 시너지 활성화 확인
    final activeSynergyNames = getActiveSynergies().map((s) => s.name).toSet();
    final hasRequiredSynergies = encounter.requiredSynergies.every(
      (synergyName) => activeSynergyNames.contains(synergyName)
    );
    
    return hasStoredItems && hasHistoryItems && hasRequiredSynergies;
  }
  
  /// 인카운터 발생
  void _triggerEncounter(StorageEncounter encounter) {
    _triggeredEncounters.add(encounter.encounterId);
    _encounterTriggeredController.add(encounter);
    
    print('\n🎭 [새로운 인카운터]');
    print('📖 ${encounter.title}');
    print('${encounter.description}');
  }
  
  // ═══════════════════════════════════════════════════════════════
  // 유틸리티 메서드
  // ═══════════════════════════════════════════════════════════════
  
  /// 위치 충돌 검사 (아이템 크기 고려)
  bool _isPositionOccupied(StoragePosition position, StorageItem item, {String? excludeItemId}) {
    for (final entry in _items.entries) {
      if (entry.key == excludeItemId) continue;
      
      final otherItem = entry.value;
      final otherPosition = _positions[entry.key]!;
      
      // 간단한 AABB 충돌 검사
      if (_itemsOverlap(position, item, otherPosition, otherItem)) {
        return true;
      }
    }
    return false;
  }
  
  /// 두 아이템이 겹치는지 확인
  bool _itemsOverlap(StoragePosition pos1, StorageItem item1, StoragePosition pos2, StorageItem item2) {
    // 간단한 사각형 겹침 검사
    const itemSize = 50.0; // 기본 아이템 크기 (픽셀)
    
    final left1 = pos1.x;
    final right1 = pos1.x + (item1.currentWidth * itemSize);
    final top1 = pos1.y;
    final bottom1 = pos1.y + (item1.currentHeight * itemSize);
    
    final left2 = pos2.x;
    final right2 = pos2.x + (item2.currentWidth * itemSize);
    final top2 = pos2.y;
    final bottom2 = pos2.y + (item2.currentHeight * itemSize);
    
    return !(right1 <= left2 || right2 <= left1 || bottom1 <= top2 || bottom2 <= top1);
  }
  
  // ═══════════════════════════════════════════════════════════════
  // 스트림 접근자
  // ═══════════════════════════════════════════════════════════════
  
  Stream<StorageItem> get onItemStored => _itemStoredController.stream;
  Stream<StorageItem> get onItemRetrieved => _itemRetrievedController.stream;
  Stream<StorageItem> get onItemRotated => _itemRotatedController.stream;
  Stream<ProximitySynergy> get onSynergyActivated => _synergyActivatedController.stream;
  Stream<StorageEncounter> get onEncounterTriggered => _encounterTriggeredController.stream;
  
  // ═══════════════════════════════════════════════════════════════
  // Getters
  // ═══════════════════════════════════════════════════════════════
  
  List<StorageItem> get items => _items.values.toList();
  int get currentCount => _items.length;
  int get maxCapacity => _maxCapacity;
  bool get isFull => _items.length >= _maxCapacity;
  
  void dispose() {
    _itemStoredController.close();
    _itemRetrievedController.close();
    _itemRotatedController.close();
    _synergyActivatedController.close();
    _encounterTriggeredController.close();
  }
} 
 