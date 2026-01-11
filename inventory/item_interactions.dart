import 'inventory_system.dart';
import 'inventory_item.dart';
import 'dart:async';

/// 아이템 기반 새로운 선택지
class ItemDialogueOption {
  final String itemId;           // 필요한 아이템 ID
  final List<String> requiredItems; // 여러 아이템이 필요한 경우
  final String targetNpc;        // 대상 NPC
  final String optionText;       // 선택지 텍스트
  final String? condition;       // 추가 조건
  final Map<String, dynamic> requirements; // 복잡한 요구사항

  const ItemDialogueOption({
    this.itemId = '',
    this.requiredItems = const [],
    required this.targetNpc,
    required this.optionText,
    this.condition,
    this.requirements = const {},
  });
}

/// 아이템 기반 새로운 인카운터
class ItemEncounter {
  final String itemId;           // 트리거 아이템 ID
  final List<String> requiredItems; // 여러 아이템이 필요한 경우
  final List<String> blockingItems; // 이 아이템들이 있으면 발생하지 않음
  final String encounterId;      // 인카운터 고유 ID
  final String title;            // 인카운터 제목
  final String description;      // 인카운터 설명
  final String? location;        // 특정 장소에서만 발생 (선택사항)
  final Map<String, dynamic> data; // 추가 데이터
  final Map<String, dynamic> conditions; // 추가 조건들

  const ItemEncounter({
    this.itemId = '',
    this.requiredItems = const [],
    this.blockingItems = const [],
    required this.encounterId,
    required this.title,
    required this.description,
    this.location,
    this.data = const {},
    this.conditions = const {},
  });
}

/// 아이템 획득 기록
class ItemAcquisitionRecord {
  final String itemId;
  final DateTime timestamp;
  final Map<String, dynamic> context;

  const ItemAcquisitionRecord({
    required this.itemId,
    required this.timestamp,
    this.context = const {},
  });
}

/// 히스토리 기반 인카운터
class HistoryBasedEncounter {
  final List<String> requiredAcquisitions; // 획득 기록이 필요한 아이템들
  final String encounterId;
  final String title;
  final String description;
  final Map<String, dynamic> conditions;
  final Map<String, dynamic> data;

  const HistoryBasedEncounter({
    required this.requiredAcquisitions,
    required this.encounterId,
    required this.title,
    required this.description,
    this.conditions = const {},
    this.data = const {},
  });
}

/// 아이템 인터랙션 관리자
class ItemInteractionManager {
  final InventorySystem _inventory;
  final List<ItemDialogueOption> _dialogueOptions = [];
  final List<ItemEncounter> _encounters = [];
  final List<HistoryBasedEncounter> _historyEncounters = [];
  final Set<String> _triggeredEncounters = {}; // 이미 발생한 인카운터들
  final List<ItemAcquisitionRecord> _acquisitionHistory = []; // 아이템 획득 기록
  
  late final StreamSubscription _itemSubscription;
  
  // 인카운터 발생 스트림
  final StreamController<ItemEncounter> _encounterController = StreamController.broadcast();
  Stream<ItemEncounter> get onEncounterTriggered => _encounterController.stream;
  
  ItemInteractionManager(this._inventory) {
    _itemSubscription = _inventory.onItemAdded.listen(_handleItemAcquisition);
    _setupDefaultInteractions();
  }

  /// 아이템 획득 처리
  void _handleItemAcquisition(InventoryItem item) {
    // 획득 기록 추가
    _acquisitionHistory.add(ItemAcquisitionRecord(
      itemId: item.id,
      timestamp: DateTime.now(),
      context: {
        'location': _getCurrentLocation(),
        'time': _getCurrentTime(),
        'weather': _getCurrentWeather(),
      },
    ));

    print('🎒 ${item.name} 획득!');
    
    // 일반 인카운터 체크
    _checkNewItemInteractions(item);
    
    // 히스토리 기반 인카운터 체크
    _checkHistoryBasedEncounters();
  }

  /// 새로 획득한 아이템에 따른 인카운터 검사
  void _checkNewItemInteractions(InventoryItem item) {
    for (final encounter in _encounters) {
      // 이미 발생한 인카운터는 건너뜀
      if (_triggeredEncounters.contains(encounter.encounterId)) continue;

      // 특정 아이템 트리거가 있는 경우 일치 여부 확인
      if (encounter.itemId.isNotEmpty && encounter.itemId != item.id) {
        continue;
      }

      // 필수 아이템 보유 여부 확인
      final hasRequiredItems = encounter.requiredItems.isEmpty ||
          encounter.requiredItems.every((id) => _inventory.getItemById(id) != null);

      if (!hasRequiredItems) continue;

      // 방해 아이템 존재 여부 확인
      final hasBlockingItems = encounter.blockingItems.any((id) => _inventory.getItemById(id) != null);
      if (hasBlockingItems) continue;

      // 위치 조건 확인
      final locationCheck = encounter.location == null || _checkLocation(encounter.location!);
      if (!locationCheck) continue;

      // 추가 조건 확인
      final conditionsCheck = _checkConditions(encounter.conditions);
      if (!conditionsCheck) continue;

      // 모든 조건을 만족하면 인카운터 발생
      _triggerEncounter(encounter);
    }
  }

  /// 인카운터 발생
  void _triggerEncounter(ItemEncounter encounter) {
    _triggeredEncounters.add(encounter.encounterId);
    _encounterController.add(encounter);
    
    // 콘솔 출력 (실제 게임에서는 UI로 표시)
    print('\n🎭 [새로운 인카운터]');
    print('📖 ${encounter.title}');
    print('${encounter.description}');
    if (encounter.data.isNotEmpty) {
      print('추가 정보: ${encounter.data}');
    }
    print('');
  }

  /// 특정 NPC와의 대화에서 사용 가능한 새로운 선택지들
  List<String> getDialogueOptions(String npcId) {
    final options = <String>[];
    
    for (final option in _dialogueOptions) {
      // NPC 매칭 (any는 모든 NPC)
      if (option.targetNpc != 'any' && option.targetNpc != npcId) continue;
      
      // 기본 아이템 소지 확인
      bool hasMainItem = option.itemId.isEmpty || 
          _inventory.getItemById(option.itemId) != null;
      
      // 필수 아이템들 확인
      bool hasRequiredItems = option.requiredItems.isEmpty ||
          option.requiredItems.every((itemId) => _inventory.getItemById(itemId) != null);
      
      // 추가 조건 확인
      bool conditionsCheck = option.condition == null || 
          _checkCondition(option.condition!);
      
      // 복잡한 요구사항 확인
      bool requirementsCheck = _checkRequirements(option.requirements);
      
      if (hasMainItem && hasRequiredItems && conditionsCheck && requirementsCheck) {
        options.add(option.optionText);
      }
    }
    
    return options;
  }
  
  /// 조건 확인 (간단한 구현)
  bool _checkCondition(String condition) {
    // 예시: "has_item:key" 형태
    if (condition.startsWith('has_item:')) {
      final itemId = condition.substring(9);
      return _inventory.getItemById(itemId) != null;
    }
    
    // 예시: "location:castle" 형태 (실제로는 게임 상태에서 확인)
    if (condition.startsWith('location:')) {
      // 실제 구현에서는 현재 위치를 확인
      return true; // 임시
    }
    
    return true;
  }

  /// 현재 위치 확인 (게임 상태에 따라 구현)
  bool _checkLocation(String location) {
    // TODO: 실제 게임 상태에서 현재 위치 확인
    return true; // 임시 구현
  }

  /// 복잡한 요구사항 확인
  bool _checkRequirements(Map<String, dynamic> requirements) {
    for (final entry in requirements.entries) {
      switch (entry.key) {
        case 'minLevel':
          if (_getPlayerLevel() < entry.value) return false;
          break;
        case 'reputation':
          if (!_checkReputation(entry.value)) return false;
          break;
        case 'questCompleted':
          if (!_isQuestCompleted(entry.value)) return false;
          break;
        case 'time':
          if (!_checkTimeCondition(entry.value)) return false;
          break;
        // 추가 조건들...
      }
    }
    return true;
  }

  /// 추가 조건들 확인
  bool _checkConditions(Map<String, dynamic> conditions) {
    for (final entry in conditions.entries) {
      switch (entry.key) {
        case 'playerHealth':
          if (!_checkHealthCondition(entry.value)) return false;
          break;
        case 'worldState':
          if (!_checkWorldState(entry.value)) return false;
          break;
        case 'weather':
          if (!_checkWeather(entry.value)) return false;
          break;
        // 추가 조건들...
      }
    }
    return true;
  }

  // 임시 구현된 체크 메서드들 (실제 게임 상태에 따라 구현 필요)
  int _getPlayerLevel() => 1;
  bool _checkReputation(String faction) => true;
  bool _isQuestCompleted(String questId) => true;
  bool _checkTimeCondition(String timeReq) => true;
  bool _checkHealthCondition(int threshold) => true;
  bool _checkWorldState(String state) => true;
  bool _checkWeather(String weather) => true;
  
  /// 새로운 대화 옵션 추가
  void addDialogueOption(ItemDialogueOption option) {
    _dialogueOptions.add(option);
  }
  
  /// 새로운 인카운터 추가
  void addEncounter(ItemEncounter encounter) {
    _encounters.add(encounter);
  }
  
  /// 히스토리 기반 인카운터 추가
  void addHistoryEncounter(HistoryBasedEncounter encounter) {
    _historyEncounters.add(encounter);
  }

  /// 기본 인터랙션들 설정
  void _setupDefaultInteractions() {
    // 대화 옵션들
    _dialogueOptions.addAll([
      ItemDialogueOption(
        itemId: 'royal_seal',
        requiredItems: ['noble_clothes', 'royal_letter'],
        targetNpc: 'castle_guard',
        optionText: '👑 [왕실 인장 제시] "나는 왕의 특사다!"',
        requirements: {
          'minLevel': 10,
          'reputation': 'royal_court',
        }
      ),
      
      ItemDialogueOption(
        requiredItems: ['ancient_rune', 'magic_scroll', 'wizard_staff'],
        targetNpc: 'ancient_wizard',
        optionText: '✨ [고대 마법 의식] "룬과 두루마리로 의식을 시작합니다"',
        requirements: {'time': 'night', 'weather': 'clear'}
      ),
      
      ItemDialogueOption(
        itemId: 'master_key',
        targetNpc: 'any',
        optionText: '🗝️ [마스터 키 사용] 문을 연다',
      ),
      
      ItemDialogueOption(
        itemId: 'healing_potion',
        targetNpc: 'injured_villager',
        optionText: '🧪 [치료 물약 제공] "이걸 드세요!"',
      ),
      
      ItemDialogueOption(
        itemId: 'ancient_map',
        targetNpc: 'wise_sage',
        optionText: '🗺️ [고대 지도 보여주기] "이 지도를 해석해 주실 수 있나요?"',
      ),
    ]);
    
    // 인카운터들
    _encounters.addAll([
      ItemEncounter(
        itemId: 'dragon_scale',
        requiredItems: ['ancient_sword', 'dragon_book'],
        blockingItems: ['cursed_amulet'],
        encounterId: 'dragon_recognition',
        title: '드래곤의 인정',
        description: '드래곤의 비늘이 따뜻하게 빛나며 고대 드래곤이 당신을 인정합니다.',
        location: 'dragon_altar',
        conditions: {'worldState': 'dragons_awakened'},
        data: {'unlocks': 'dragon_lair', 'reputation': 'dragon_friend'},
      ),
      
      ItemEncounter(
        requiredItems: ['holy_water', 'silver_cross', 'sacred_text'],
        blockingItems: ['dark_artifact'],
        encounterId: 'undead_cleansing',
        title: '언데드 정화 의식',
        description: '성수와 성물이 공명하며 주변의 언데드들이 정화됩니다.',
        location: 'graveyard',
        conditions: {'time': 'midnight'},
        data: {'effect': 'undead_banish', 'duration': 300},
      ),
      
      ItemEncounter(
        itemId: 'cursed_amulet',
        encounterId: 'curse_awakening',
        title: '저주의 각성',
        description: '저주받은 목걸이를 얻는 순간, 어둠의 기운이 당신을 감쌉니다...',
        data: {'debuff': 'cursed', 'attracts': 'undead'},
      ),
      
      ItemEncounter(
        itemId: 'phoenix_feather',
        encounterId: 'phoenix_blessing',
        title: '불사조의 축복',
        description: '불사조의 깃털이 타오르며 당신에게 재생의 힘을 부여합니다.',
        data: {'buff': 'regeneration', 'immunity': 'fire'},
      ),
      
      ItemEncounter(
        itemId: 'mermaid_pearl',
        encounterId: 'ocean_calling',
        title: '바다의 부름',
        description: '인어의 진주가 바다의 속삭임을 전해줍니다. 깊은 바다가 당신을 부르고 있습니다.',
        location: 'seaside',
        data: {'unlocks': 'underwater_city', 'ability': 'water_breathing'},
      ),
      
      ItemEncounter(
        itemId: 'star_fragment',
        encounterId: 'cosmic_vision',
        title: '우주의 환상',
        description: '별의 파편이 빛나며 우주의 비밀을 엿볼 수 있게 해줍니다.',
        data: {'vision': 'future_glimpse', 'knowledge': 'cosmic_secrets'},
      ),
    ]);
    
    // 히스토리 기반 인카운터들 추가
    _historyEncounters.addAll([
      HistoryBasedEncounter(
        requiredAcquisitions: ['ancient_scroll', 'magic_crystal', 'dragon_scale'],
        encounterId: 'ancient_knowledge_revelation',
        title: '고대의 지식 계시',
        description: '과거에 수집한 유물들의 기억이 떠올랐다. 고대 문명의 비밀이 마음속에서 울린다...',
        data: {
          'unlock': 'ancient_wisdom',
          'grant_skill': 'ancient_magic',
        }
      ),
      
      HistoryBasedEncounter(
        requiredAcquisitions: ['cursed_dagger', 'demon_heart', 'dark_crystal'],
        encounterId: 'dark_power_awakening',
        title: '어둠의 힘 각성',
        description: '수집했던 어둠의 유물들이 공명하기 시작한다. 금기의 힘이 깨어난다...',
        conditions: {'time': 'night'},
        data: {
          'unlock': 'dark_magic',
          'corruption': 10,
        }
      ),
      
      HistoryBasedEncounter(
        requiredAcquisitions: ['holy_grail', 'angel_feather', 'divine_scripture'],
        encounterId: 'divine_blessing',
        title: '신성한 축복',
        description: '과거에 모았던 성물들의 기억이 빛나기 시작한다. 신성한 기운이 당신을 감싼다...',
        conditions: {'location': 'temple'},
        data: {
          'unlock': 'divine_magic',
          'purification': 100,
        }
      ),
    ]);
  }
  
  /// 발생한 인카운터 목록
  List<String> getTriggeredEncounters() {
    return List.from(_triggeredEncounters);
  }
  
  /// 인카운터 초기화 (테스트용)
  void resetEncounters() {
    _triggeredEncounters.clear();
  }

  /// 히스토리 기반 인카운터 체크
  void _checkHistoryBasedEncounters() {
    final acquiredItems = _acquisitionHistory.map((record) => record.itemId).toSet();
    
    for (final encounter in _historyEncounters) {
      // 이미 발생한 인카운터는 스킵
      if (_triggeredEncounters.contains(encounter.encounterId)) continue;
      
      // 필요한 아이템들을 모두 한번이라도 획득한 적이 있는지 확인
      bool hasRequiredAcquisitions = encounter.requiredAcquisitions
          .every((itemId) => acquiredItems.contains(itemId));
      
      // 추가 조건 확인
      bool conditionsCheck = _checkConditions(encounter.conditions);
      
      if (hasRequiredAcquisitions && conditionsCheck) {
        _triggerHistoryEncounter(encounter);
      }
    }
  }

  /// 히스토리 기반 인카운터 발생
  void _triggerHistoryEncounter(HistoryBasedEncounter encounter) {
    _triggeredEncounters.add(encounter.encounterId);
    
    // 일반 ItemEncounter 형식으로 변환하여 발생
    final itemEncounter = ItemEncounter(
      encounterId: encounter.encounterId,
      title: encounter.title,
      description: encounter.description,
      data: encounter.data,
    );
    
    _encounterController.add(itemEncounter);
    
    print('\n📚 [과거의 기억]');
    print('📖 ${encounter.title}');
    print('${encounter.description}');
    if (encounter.data.isNotEmpty) {
      print('추가 정보: ${encounter.data}');
    }
    print('');
  }

  // 현재 상태 조회 메서드들 (실제 구현 필요)
  String _getCurrentLocation() => 'unknown';
  String _getCurrentTime() => 'day';
  String _getCurrentWeather() => 'clear';

  /// 아이템 획득 기록 조회
  List<ItemAcquisitionRecord> getAcquisitionHistory() {
    return List.unmodifiable(_acquisitionHistory);
  }

  /// 특정 아이템의 획득 여부 확인
  bool hasAcquiredItem(String itemId) {
    return _acquisitionHistory.any((record) => record.itemId == itemId);
  }

  /// 특정 아이템들의 획득 순서 확인
  bool checkAcquisitionOrder(List<String> itemIds) {
    int lastIndex = -1;
    for (final itemId in itemIds) {
      final index = _acquisitionHistory.indexWhere((record) => record.itemId == itemId);
      if (index == -1 || index <= lastIndex) return false;
      lastIndex = index;
    }
    return true;
  }
  
  /// 리소스 정리
  void dispose() {
    _itemSubscription.cancel();
    _encounterController.close();
  }
}