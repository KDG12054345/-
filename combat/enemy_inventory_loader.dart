/// 적 인벤토리 로더 시스템
/// 
/// 인카운터 메타데이터에서 적의 인벤토리를 생성합니다.
/// Manual, Auto, Hybrid 세 가지 모드를 지원합니다.
library;

import '../inventory/inventory_system.dart';
import '../inventory/inventory_item.dart';
import 'enemy_inventory_generator.dart';

/// 적 인벤토리 로더
class EnemyInventoryLoader {
  /// 인카운터 메타데이터에서 적 인벤토리 로드
  static InventorySystem loadFromEncounter(Map<String, dynamic>? metadata) {
    if (metadata == null) {
      print('[EnemyInventoryLoader] No metadata provided, creating empty inventory');
      return _createEmpty();
    }

    final combat = metadata['combat'] as Map<String, dynamic>?;
    if (combat == null) {
      print('[EnemyInventoryLoader] No combat data in metadata');
      return _createEmpty();
    }

    final inventoryData = combat['enemyInventory'] as Map<String, dynamic>?;
    if (inventoryData == null) {
      print('[EnemyInventoryLoader] No enemyInventory data');
      return _createEmpty();
    }

    final mode = inventoryData['mode'] as String? ?? 'manual';
    print('[EnemyInventoryLoader] Loading enemy inventory (mode: $mode)');

    switch (mode) {
      case 'manual':
        return _loadManual(inventoryData);
      case 'auto':
        return _loadAuto(inventoryData, combat);
      case 'hybrid':
        return _loadHybrid(inventoryData, combat);
      default:
        print('[EnemyInventoryLoader] Unknown mode: $mode, using empty');
        return _createEmpty();
    }
  }

  /// Manual 모드: JSON에서 직접 정의된 아이템 로드
  static InventorySystem _loadManual(Map<String, dynamic> data) {
    final items = data['items'] as List<dynamic>? ?? [];
    final gridData = data['grid'] as Map<String, dynamic>?;
    
    final width = gridData?['width'] as int? ?? 9;
    final height = gridData?['height'] as int? ?? 6;
    
    final inventory = InventorySystem(width: width, height: height);
    
    print('[EnemyInventoryLoader] Manual mode: Loading ${items.length} items');

    for (var itemData in items) {
      final itemMap = itemData as Map<String, dynamic>;
      final itemId = itemMap['id'] as String;
      final rotation = itemMap['rotation'] as int? ?? 0;

      // ItemDatabase에서 아이템 생성 (임시로 더미 아이템)
      final item = _createDummyItem(itemId);
      
      // 회전 적용
      if (rotation == 0 || rotation == 90 || rotation == 180 || rotation == 270) {
        item.setRotationDegrees(rotation);
      } else {
        // legacy step(0..3) 지원
        for (int i = 0; i < (rotation % 4); i++) {
          item.rotate();
        }
      }

      // 텍스트형 인벤토리: 위치/배치 개념이 없으므로 그냥 추가
      inventory.tryAddItem(item);
    }

    return inventory;
  }

  /// Auto 모드: 난이도 기반 자동 생성
  static InventorySystem _loadAuto(Map<String, dynamic> data, Map<String, dynamic> combatData) {
    final autoGen = data['autoGeneration'] as Map<String, dynamic>?;
    
    if (autoGen == null) {
      print('[EnemyInventoryLoader] Auto mode but no autoGeneration config');
      return _createEmpty();
    }

    final config = EnemyInventoryConfig.fromJson(autoGen, combatData);
    print('[EnemyInventoryLoader] Auto mode: difficulty=${config.difficulty}, level=${config.level}');

    return EnemyInventoryGenerator.generate(config);
  }

  /// Hybrid 모드: 필수 아이템(manual) + 자동 생성(auto)
  static InventorySystem _loadHybrid(Map<String, dynamic> data, Map<String, dynamic> combatData) {
    print('[EnemyInventoryLoader] Hybrid mode: Loading manual items first');
    
    // 1. Manual 파트 먼저 로드
    final inventory = _loadManual(data);
    
    // 2. Auto 파트 추가
    final autoGen = data['autoGeneration'] as Map<String, dynamic>?;
    
    if (autoGen != null) {
      final config = EnemyInventoryConfig.fromJson(autoGen, combatData);
      print('[EnemyInventoryLoader] Hybrid mode: Adding auto-generated items');
      
      // 자동 생성 아이템 추가
      final autoItems = EnemyInventoryGenerator.generateItems(config);
      
      for (var item in autoItems) {
        inventory.tryAddItem(item);
      }
    }

    return inventory;
  }

  /// 빈 인벤토리 생성
  static InventorySystem _createEmpty() {
    return InventorySystem(width: 9, height: 6);
  }

  /// 더미 아이템 생성 (임시 - 나중에 실제 ItemDatabase로 교체)
  static InventoryItem _createDummyItem(String itemId) {
    // 임시로 기본 크기 아이템 생성
    return InventoryItem(
      id: itemId,
      name: itemId,
      description: 'Enemy item: $itemId',
      baseWidth: 1,
      baseHeight: 1,
      iconPath: 'assets/items/$itemId.png',
      properties: {'type': 'weapon'},
    );
  }
}

