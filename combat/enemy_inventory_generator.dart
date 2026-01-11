/// 적 인벤토리 자동 생성 시스템
/// 
/// 난이도, 레벨, 적 타입에 따라 적절한 아이템을 자동으로 생성합니다.
library;

import 'dart:math';
import '../inventory/inventory_system.dart';
import '../inventory/inventory_item.dart';

/// 적 인벤토리 생성 설정
class EnemyInventoryConfig {
  final String difficulty;      // "easy", "normal", "hard", "boss"
  final int level;               // 적 레벨 (1~10)
  final String? enemyType;       // "bandit", "monster", "undead" 등
  final int itemBudget;          // 아이템 총 가치 예산
  final List<String> guaranteed; // 반드시 포함할 아이템
  final List<String>? excludeTypes; // 제외할 아이템 타입

  const EnemyInventoryConfig({
    required this.difficulty,
    required this.level,
    this.enemyType,
    required this.itemBudget,
    this.guaranteed = const [],
    this.excludeTypes,
  });

  factory EnemyInventoryConfig.fromJson(
    Map<String, dynamic> json,
    Map<String, dynamic> combatData,
  ) {
    final difficulty = json['difficulty'] as String? ?? 'normal';
    final level = json['level'] as int? ?? 1;
    final enemyType = json['enemyType'] as String? ?? combatData['enemyType'] as String?;
    
    // 난이도에 따른 기본 예산 설정
    int budget = json['itemBudget'] as int? ?? _getDefaultBudget(difficulty, level);
    
    final guaranteed = (json['guaranteed'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList() ?? [];
    
    final excludeTypes = (json['excludeTypes'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList();

    return EnemyInventoryConfig(
      difficulty: difficulty,
      level: level,
      enemyType: enemyType,
      itemBudget: budget,
      guaranteed: guaranteed,
      excludeTypes: excludeTypes,
    );
  }

  static int _getDefaultBudget(String difficulty, int level) {
    final baseBudget = switch (difficulty) {
      'easy' => 50,
      'normal' => 100,
      'hard' => 200,
      'boss' => 400,
      _ => 100,
    };
    
    // 레벨당 +20% 추가
    return (baseBudget * (1.0 + (level - 1) * 0.2)).round();
  }
}

/// 적 인벤토리 자동 생성기
class EnemyInventoryGenerator {
  static final Random _random = Random();

  /// 인벤토리 생성 (완성된 InventorySystem 반환)
  static InventorySystem generate(EnemyInventoryConfig config) {
    final inventory = InventorySystem(width: 9, height: 6);
    final items = generateItems(config);
    
    print('[EnemyInventoryGenerator] Generated ${items.length} items for budget ${config.itemBudget}');
    
    // 아이템 배치 (큰 것부터)
    items.sort((a, b) {
      final aSize = a.currentWidth * a.currentHeight;
      final bSize = b.currentWidth * b.currentHeight;
      return bSize.compareTo(aSize);
    });
    
    for (var item in items) {
      final placed = inventory.tryAddItem(item);
      if (!placed) {
        print('[EnemyInventoryGenerator]   - Failed to place ${item.id}');
      }
    }
    
    return inventory;
  }

  /// 아이템 목록만 생성 (배치는 별도)
  static List<InventoryItem> generateItems(EnemyInventoryConfig config) {
    final items = <InventoryItem>[];
    int remainingBudget = config.itemBudget;

    // 1. 보장된 아이템 먼저 추가
    for (var itemId in config.guaranteed) {
      final item = _createItemById(itemId);
      if (item != null) {
        items.add(item);
        remainingBudget -= _getItemValue(itemId);
      }
    }

    // 2. 아이템 풀 필터링
    final pool = _getItemPool(config);
    
    // 3. 예산 내에서 랜덤 아이템 추가
    while (remainingBudget > 0 && pool.isNotEmpty) {
      // 가중치 기반 랜덤 선택
      final itemId = _selectWeightedRandom(pool);
      final itemValue = _getItemValue(itemId);
      
      if (itemValue <= remainingBudget) {
        final item = _createItemById(itemId);
        if (item != null) {
          items.add(item);
          remainingBudget -= itemValue;
        }
      } else {
        // 더 이상 살 수 있는 아이템이 없으면 종료
        pool.removeWhere((id) => _getItemValue(id) > remainingBudget);
      }
      
      // 무한 루프 방지
      if (items.length > 20) break;
    }

    print('[EnemyInventoryGenerator] Generated ${items.length} items (budget used: ${config.itemBudget - remainingBudget}/${config.itemBudget})');
    return items;
  }

  /// 적 타입과 난이도에 맞는 아이템 풀 생성
  static List<String> _getItemPool(EnemyInventoryConfig config) {
    // 임시 아이템 풀 (나중에 실제 ItemDatabase에서 가져오기)
    final allItems = <String>[];

    // 난이도별 기본 아이템
    switch (config.difficulty) {
      case 'easy':
        allItems.addAll(['rusty_dagger', 'torn_cloth', 'wooden_shield']);
        break;
      case 'normal':
        allItems.addAll(['iron_sword', 'leather_armor', 'healing_potion']);
        break;
      case 'hard':
        allItems.addAll(['steel_sword', 'chain_armor', 'mana_potion', 'magic_ring']);
        break;
      case 'boss':
        allItems.addAll(['legendary_weapon', 'dragon_armor', 'elixir', 'artifact']);
        break;
    }

    // 적 타입별 추가 아이템
    if (config.enemyType != null) {
      switch (config.enemyType) {
        case 'bandit':
          allItems.addAll(['dagger', 'bow', 'poison_vial']);
          break;
        case 'monster':
          allItems.addAll(['claw', 'fang', 'hide']);
          break;
        case 'undead':
          allItems.addAll(['cursed_blade', 'bone_armor', 'soul_gem']);
          break;
        case 'mage':
          allItems.addAll(['staff', 'spell_book', 'wand', 'robe']);
          break;
      }
    }

    // 제외 타입 필터링
    if (config.excludeTypes != null) {
      // 실제 구현에서는 아이템 타입을 확인하여 필터링
      // 임시로는 제외 타입에 해당하는 이름을 제거
      allItems.removeWhere((id) {
        for (var excludeType in config.excludeTypes!) {
          if (id.contains(excludeType)) return true;
        }
        return false;
      });
    }

    return allItems;
  }

  /// 가중치 기반 랜덤 선택
  static String _selectWeightedRandom(List<String> pool) {
    if (pool.isEmpty) throw StateError('Empty item pool');
    
    // 임시로 균등 확률 (나중에 dropWeight 활용)
    return pool[_random.nextInt(pool.length)];
  }

  /// 아이템 가치 계산 (예산 시스템용)
  static int _getItemValue(String itemId) {
    // 임시 가치 테이블 (나중에 실제 데이터로 교체)
    const valueTable = {
      'rusty_dagger': 10,
      'torn_cloth': 5,
      'wooden_shield': 15,
      'iron_sword': 30,
      'leather_armor': 25,
      'healing_potion': 20,
      'steel_sword': 60,
      'chain_armor': 50,
      'mana_potion': 30,
      'magic_ring': 80,
      'legendary_weapon': 200,
      'dragon_armor': 150,
      'elixir': 100,
      'artifact': 250,
      'dagger': 20,
      'bow': 40,
      'poison_vial': 25,
      'claw': 15,
      'fang': 15,
      'hide': 20,
      'cursed_blade': 70,
      'bone_armor': 60,
      'soul_gem': 90,
      'staff': 50,
      'spell_book': 80,
      'wand': 40,
      'robe': 35,
    };

    return valueTable[itemId] ?? 20;
  }

  /// 아이템 ID로 실제 아이템 생성
  static InventoryItem? _createItemById(String itemId) {
    // 임시 더미 아이템 생성 (나중에 실제 ItemDatabase로 교체)
    final sizeMap = {
      'rusty_dagger': [1, 3],
      'torn_cloth': [2, 2],
      'wooden_shield': [2, 3],
      'iron_sword': [1, 4],
      'leather_armor': [3, 3],
      'healing_potion': [1, 2],
      'steel_sword': [1, 4],
      'chain_armor': [3, 4],
      'mana_potion': [1, 2],
      'magic_ring': [1, 1],
      'legendary_weapon': [2, 5],
      'dragon_armor': [4, 4],
      'elixir': [1, 2],
      'artifact': [2, 2],
    };

    final size = sizeMap[itemId] ?? [1, 1];
    final width = size[0];
    final height = size[1];

    return InventoryItem(
      id: itemId,
      name: itemId.replaceAll('_', ' ').toUpperCase(),
      description: 'Enemy item: ${itemId.replaceAll('_', ' ')}',
      baseWidth: width,
      baseHeight: height,
      iconPath: 'assets/items/$itemId.png',
      properties: {
        'type': _guessItemType(itemId),
        'value': _getItemValue(itemId),
      },
    );
  }

  /// 아이템 ID로 타입 추정
  static String _guessItemType(String itemId) {
    if (itemId.contains('sword') || itemId.contains('dagger') || itemId.contains('weapon')) {
      return 'weapon';
    } else if (itemId.contains('armor') || itemId.contains('shield') || itemId.contains('cloth')) {
      return 'armor';
    } else if (itemId.contains('potion') || itemId.contains('elixir')) {
      return 'consumable';
    } else if (itemId.contains('ring') || itemId.contains('artifact')) {
      return 'accessory';
    }
    return 'misc';
  }
}

