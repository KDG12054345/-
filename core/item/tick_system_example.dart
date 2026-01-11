import 'dart:async';
import '../../inventory/synergy_system.dart';
import '../../inventory/inventory_system.dart';
import '../../inventory/vector2_int.dart';
import '../state/events.dart';
import 'item_manager_extended.dart';
import 'legacy_bridge.dart';
import 'item_definition.dart';
import '../../combat/item.dart';
import '../../combat/stats.dart';

/// 틱 정렬 시스템 사용 예시
class TickSystemExample {
  late final TickAlignedItemManager itemManager;
  late final LegacyInventoryBridge bridge;
  
  void initialize(Function(GEvent) dispatch) {
    // 1. 새로운 매니저 생성
    final synergySystem = SynergySystem([]);
    itemManager = TickAlignedItemManager(synergySystem, dispatch);
    
    // 2. 기존 시스템과 브리지 연결
    final legacySystem = InventorySystem(width: 10, height: 10);
    bridge = LegacyInventoryBridge(
      newManager: itemManager,
      legacySystem: legacySystem,
    );
    
    // 3. 틱 시스템 시작
    itemManager.startTickSystem();
    
    // 4. 테스트용 아이템 정의 등록
    _registerTestItems();
    
    // 5. 기존 데이터 동기화
    bridge.syncFromLegacy();
  }
  
  /// 테스트용 아이템 정의 등록
  void _registerTestItems() {
    final firesword = ItemDefinition(
      id: 'fire_sword',
      name: '불타는 검',
      description: '화염의 힘이 깃든 검',
      iconPath: 'assets/items/fire_sword.png',
      baseWidth: 1,
      baseHeight: 3,
      type: ItemType.weapon,
      baseStats: CombatStats(attackPower: 15),
    );
    
    final iceshield = ItemDefinition(
      id: 'ice_shield',
      name: '얼음 방패',
      description: '차가운 얼음으로 만든 방패',
      iconPath: 'assets/items/ice_shield.png',
      baseWidth: 2,
      baseHeight: 2,
      type: ItemType.armor,
      baseStats: CombatStats(maxHealth: 20),
    );
    
    itemManager.registerDefinition(firesword); // 수정: fireword → firesword
    itemManager.registerDefinition(iceshield);
  }
  
  /// 전투 잠금 모드 시뮬레이션 (하이브리드 모드 대신)
  void simulateCombatLockMode() {
    // 1. 테스트용 아이템 생성
    final sword = itemManager.createItem('fire_sword');
    final shield = itemManager.createItem('ice_shield');
    
    // 2. 아이템 배치
    itemManager.moveItem(sword.id, Vector2Int(0, 0));
    itemManager.moveItem(shield.id, Vector2Int(2, 0));
    
    print('아이템 배치 완료');
    
    // 3. 전투 시작 - 인벤토리 잠금
    final playerItemIds = itemManager.getAllItems().map((i) => i.id).toList();
    final combatSnapshot = itemManager.startCombat(playerItemIds);
    
    print('전투 시작 - 인벤토리 잠금됨 (스냅샷 ID: ${combatSnapshot.snapshotId})');
    
    // 4. 전투 중 인벤토리 조작 시도 (실패해야 함)
    Timer(Duration(milliseconds: 500), () {
      try {
        itemManager.rotateItem(sword.id);
        print('ERROR: 전투 중 회전이 허용되었습니다!');
      } catch (e) {
        print('정상: 전투 중 회전 차단됨 - $e');
      }
      
      try {
        itemManager.moveItem(sword.id, Vector2Int(1, 1));
        print('ERROR: 전투 중 이동이 허용되었습니다!');
      } catch (e) {
        print('정상: 전투 중 이동 차단됨 - $e');
      }
    });
    
    // 5. 전투 종료 - 인벤토리 잠금 해제
    Timer(Duration(seconds: 2), () {
      itemManager.endCombat();
      print('전투 종료 - 인벤토리 잠금 해제됨');
      
      // 6. 전투 후 인벤토리 조작 테스트 (성공해야 함)
      try {
        itemManager.rotateItem(sword.id);
        print('정상: 전투 후 회전 허용됨');
      } catch (e) {
        print('ERROR: 전투 후에도 회전이 차단됨 - $e');
      }
      
      try {
        itemManager.moveItem(shield.id, Vector2Int(3, 1));
        print('정상: 전투 후 이동 허용됨');
      } catch (e) {
        print('ERROR: 전투 후에도 이동이 차단됨 - $e');
      }
    });
  }
  
  /// 성능 테스트
  void performanceTest() {
    print('성능 테스트 시작...');
    
    final stopwatch = Stopwatch()..start();
    
    // 대량 아이템 생성
    for (int i = 0; i < 100; i++) {
      final item = itemManager.createItem('fire_sword');
      itemManager.moveItem(item.id, Vector2Int(i % 10, i ~/ 10));
    }
    
    stopwatch.stop();
    print('100개 아이템 생성 및 배치: ${stopwatch.elapsedMilliseconds}ms');
    
    // 대량 회전 테스트
    stopwatch.reset();
    stopwatch.start();
    
    final allItems = itemManager.getAllItems();
    for (final item in allItems) {
      itemManager.rotateItem(item.id);
    }
    
    stopwatch.stop();
    print('${allItems.length}개 아이템 회전: ${stopwatch.elapsedMilliseconds}ms');
  }
  
  /// 시너지 테스트
  void synergyTest() {
    print('시너지 테스트 시작...');
    
    // 시너지를 위한 아이템들 생성
    final sword1 = itemManager.createItem('fire_sword');
    final sword2 = itemManager.createItem('fire_sword');
    final shield = itemManager.createItem('ice_shield');
    
    // 인접하게 배치 (시너지 활성화)
    itemManager.moveItem(sword1.id, Vector2Int(0, 0));
    itemManager.moveItem(sword2.id, Vector2Int(1, 0));
    itemManager.moveItem(shield.id, Vector2Int(0, 1));
    
    print('아이템들을 인접하게 배치함');
    
    // 시너지 계산 확인
    Timer(Duration(milliseconds: 200), () {
      final calculator = itemManager.getCalculator();
      final allItems = itemManager.getAllItems();
      final synergies = calculator.calculateActiveSynergies(allItems);
      
      print('활성 시너지 개수: ${synergies.length}');
      for (final synergy in synergies) {
        print('- ${synergy.name}: ${synergy.description}');
      }
    });
  }
  
  void dispose() {
    itemManager.stopTickSystem();
  }
}
