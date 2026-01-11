import 'dart:async';
import 'inventory_system.dart';
import 'inventory_item.dart';
import '../data/item_rarity.dart';

class ItemTriggeredDialogue {
  final String itemId;
  final String npcId;
  final String dialogueId;
  final List<String> newOptions;
  final Map<String, dynamic> conditions;
  
  const ItemTriggeredDialogue({
    required this.itemId,
    required this.npcId,
    required this.dialogueId,
    required this.newOptions,
    this.conditions = const {},
  });
  
  bool canTrigger(InventorySystem inventory, String currentNpc, Map<String, dynamic> gameState) {
    // 아이템 소지 확인
    final hasItem = inventory.getItemById(itemId) != null;
    if (!hasItem) return false;
    
    // NPC 일치 확인
    if (currentNpc != npcId) return false;
    
    // 추가 조건 확인
    for (final entry in conditions.entries) {
      final key = entry.key;
      final expectedValue = entry.value;
      final actualValue = gameState[key];
      
      if (actualValue != expectedValue) return false;
    }
    
    return true;
  }
}

class ItemBasedEncounter {
  final String triggerId;
  final List<String> requiredItems;
  final List<String> forbiddenItems;
  final String encounterType;
  final Map<String, dynamic> encounterData;
  final Duration? cooldown;
  
  const ItemBasedEncounter({
    required this.triggerId,
    required this.requiredItems,
    this.forbiddenItems = const [],
    required this.encounterType,
    required this.encounterData,
    this.cooldown,
  });
  
  bool shouldTrigger(InventorySystem inventory, Map<String, dynamic> gameState) {
    // 필요한 아이템이 모두 있는지 확인
    final hasRequired = requiredItems.every(
      (itemId) => inventory.getItemById(itemId) != null
    );
    if (!hasRequired) return false;
    
    // 금지된 아이템이 없는지 확인
    final hasForbidden = forbiddenItems.any(
      (itemId) => inventory.getItemById(itemId) != null
    );
    if (hasForbidden) return false;
    
    return true;
  }
}

class ItemEventManager {
  final InventorySystem inventory;
  final List<ItemTriggeredDialogue> _dialogueTriggers = [];
  final List<ItemBasedEncounter> _encounterTriggers = [];
  final Map<String, DateTime> _cooldowns = {};
  final Map<String, dynamic> _gameState = {};
  
  late final StreamSubscription _inventorySubscription;
  
  ItemEventManager(this.inventory) {
    _setupEventListeners();
    _initializeDefaultTriggers();
  }
  
  void _setupEventListeners() {
    // 올바른 구독 : 아이템이 추가될 때만 감지
    _inventorySubscription =
        inventory.onItemAdded.listen(_checkNewItemInteractions);
  }
  
  void _checkNewItemInteractions(InventoryItem item) {
    print('🎒 ${item.name}을(를) 획득했습니다!');
    
    // 특별한 아이템 획득 시 알림
    if (item.rarity == ItemRarity.legendary) {
      print('✨ 전설 아이템을 획득했습니다!');
    }
    
    if (item.properties['cursed'] == true) {
      print('😈 저주받은 아이템을 획득했습니다... 조심하세요!');
    }
    
    // 새로운 인카운터 확인
    _checkForNewEncounters();
  }
  
  void _onItemRemoved(InventoryItem item) {
    print('🗑️ ${item.name}을(를) 잃었습니다.');
  }
  
  void _onItemUsed(InventoryItem item) {
    print('✋ ${item.name}을(를) 사용했습니다.');
    
    // 아이템 사용 효과 처리
    final effects = item.properties['effects'] as Map<String, dynamic>?;
    if (effects != null) {
      _applyItemEffects(effects);
    }
  }
  
  void _applyItemEffects(Map<String, dynamic> effects) {
    for (final entry in effects.entries) {
      final effectType = entry.key;
      final effectValue = entry.value;
      
      switch (effectType) {
        case 'healing':
          print('💚 체력이 $effectValue 회복되었습니다.');
          break;
        case 'mana_restore':
          print('💙 마나가 $effectValue 회복되었습니다.');
          break;
        case 'unlock_area':
          print('🗝️ 새로운 지역 "$effectValue"이(가) 열렸습니다!');
          _gameState['unlocked_areas'] = (_gameState['unlocked_areas'] as List? ?? [])..add(effectValue);
          break;
        case 'learn_spell':
          print('📚 새로운 마법 "$effectValue"을(를) 배웠습니다!');
          break;
      }
    }
  }
  
  void _checkForNewEncounters() {
    for (final encounter in _encounterTriggers) {
      if (encounter.shouldTrigger(inventory, _gameState) && !_isOnCooldown(encounter.triggerId)) {
        _triggerEncounter(encounter);
      }
    }
  }
  
  void _triggerEncounter(ItemBasedEncounter encounter) {
    print('\n🎭 [특별 이벤트] ${encounter.encounterData['title'] ?? '새로운 인카운터'}');
    print('📖 ${encounter.encounterData['description'] ?? '무언가 특별한 일이 일어났습니다...'}');
    
    // 쿨다운 설정
    if (encounter.cooldown != null) {
      _setCooldown(encounter.triggerId, encounter.cooldown!);
    }
    
    // 보상 지급
    final rewards = encounter.encounterData['rewards'] as List?;
    if (rewards != null) {
      for (final reward in rewards) {
        print('🎁 보상: $reward');
      }
    }
  }
  
  bool _isOnCooldown(String triggerId) {
    final cooldownEnd = _cooldowns[triggerId];
    return cooldownEnd != null && DateTime.now().isBefore(cooldownEnd);
  }
  
  void _setCooldown(String triggerId, Duration duration) {
    _cooldowns[triggerId] = DateTime.now().add(duration);
  }
  
  /// 게임 상태 업데이트
  void updateGameState(String key, dynamic value) {
    _gameState[key] = value;
  }
  
  /// 현재 상황에서 사용 가능한 새로운 대화 옵션들
  List<String> getAvailableDialogueOptions(String npcId) {
    final newOptions = <String>[];
    
    for (final trigger in _dialogueTriggers) {
      if (trigger.canTrigger(inventory, npcId, _gameState) && 
          !_isOnCooldown(trigger.dialogueId)) {
        newOptions.addAll(trigger.newOptions);
      }
    }
    
    return newOptions;
  }
  
  /// 특정 상황에서 아이템 기반 선택지 제공
  List<String> getContextualOptions(String context) {
    final options = <String>[];
    final items = inventory.placedItems;
    
    switch (context) {
      case 'locked_door':
        for (final item in items) {
          if (item.properties['can_unlock_doors'] == true) {
            options.add('🗝️ [${item.name} 사용] 문을 연다');
          }
          if (item.properties['explosive'] == true) {
            options.add('💥 [${item.name} 사용] 문을 폭파한다');
          }
        }
        break;
        
      case 'injured_npc':
        for (final item in items) {
          if (item.properties['healing'] == true) {
            options.add('💊 [${item.name} 사용] 치료한다');
          }
        }
        break;
        
      case 'dark_area':
        for (final item in items) {
          if (item.properties['light_source'] == true) {
            options.add('🔦 [${item.name} 사용] 주변을 밝힌다');
          }
        }
        break;
        
      case 'merchant':
        for (final item in items) {
          if (item.properties['valuable'] == true) {
            final value = item.properties['gold_value'] ?? 100;
            options.add('💰 [${item.name} 판매] ${value}골드에 판매');
          }
        }
        break;
    }
    
    return options;
  }
  
  /// 기본 트리거들 초기화
  void _initializeDefaultTriggers() {
    // 대화 트리거들
    _dialogueTriggers.addAll([
      ItemTriggeredDialogue(
        itemId: 'royal_seal',
        npcId: 'castle_guard',
        dialogueId: 'royal_seal_dialogue',
        newOptions: [
          '👑 [왕실 인장 제시] "나는 왕의 특사다!"',
          '📜 [왕실 인장 제시] "이 인장을 보고도 막을 것인가?"'
        ],
        conditions: {'location': 'castle_entrance'}
      ),
      
      ItemTriggeredDialogue(
        itemId: 'master_key',
        npcId: 'any_locked_door',
        dialogueId: 'master_key_usage',
        newOptions: ['🗝️ [마스터 키 사용] 문을 연다'],
      ),
      
      ItemTriggeredDialogue(
        itemId: 'antidote_potion',
        npcId: 'poisoned_villager',
        dialogueId: 'antidote_help',
        newOptions: ['🧪 [해독제 제공] "이걸 드세요!"'],
      ),
    ]);
    
    // 인카운터 트리거들
    _encounterTriggers.addAll([
      ItemBasedEncounter(
        triggerId: 'ancient_spirit_encounter',
        requiredItems: ['magic_sword_of_legends'],
        forbiddenItems: ['cursed_amulet'],
        encounterType: 'dialogue',
        encounterData: {
          'title': '고대 영혼의 인정',
          'description': '전설의 마법검이 빛나며 고대 영혼이 나타납니다.',
          'npc': 'ancient_spirit',
          'rewards': ['spirit_blessing', 'ancient_knowledge']
        },
        cooldown: Duration(hours: 24),
      ),
      
      ItemBasedEncounter(
        triggerId: 'holy_relic_undead_banishment',
        requiredItems: ['holy_relic'],
        encounterType: 'combat_bonus',
        encounterData: {
          'title': '성물의 힘',
          'description': '성물이 빛나며 언데드들이 두려워합니다.',
          'effect': 'undead_weakness',
          'damage_bonus': 50,
        },
      ),
      
      ItemBasedEncounter(
        triggerId: 'mermaid_scale_ocean_event',
        requiredItems: ['mermaid_scale'],
        encounterType: 'discovery',
        encounterData: {
          'title': '인어의 부름',
          'description': '바닷가에서 인어의 비늘이 반응합니다.',
          'summons': 'mermaid_queen',
          'rewards': ['water_breathing_potion', 'pearl_of_wisdom']
        },
        cooldown: Duration(hours: 6),
      ),
    ]);
  }
  
  /// 새로운 대화 트리거 추가
  void addDialogueTrigger(ItemTriggeredDialogue trigger) {
    _dialogueTriggers.add(trigger);
  }
  
  /// 새로운 인카운터 트리거 추가
  void addEncounterTrigger(ItemBasedEncounter trigger) {
    _encounterTriggers.add(trigger);
  }
  
  /// 리소스 정리
  void dispose() {
    _inventorySubscription.cancel();
  }
} 