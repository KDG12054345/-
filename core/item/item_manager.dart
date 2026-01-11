import '../../inventory/synergy_system.dart';
import 'game_item.dart';
import 'item_definition.dart';
import 'item_instance.dart';
import 'derived_calculator.dart';
import 'combat_snapshot.dart';
import 'combat_adapter.dart';

/// 모든 아이템을 통합 관리하는 매니저
class ItemManager {
  final Map<String, ItemDefinition> _definitions = {};
  final Map<String, GameItem> _items = {};
  late final DerivedCalculator _calculator;
  
  ItemManager(SynergySystem synergySystem) {
    _calculator = DerivedCalculator(synergySystem);
  }
  
  /// 계산기 접근을 위한 public getter 추가
  DerivedCalculator getCalculator() => _calculator;
  
  /// 아이템 맵 접근을 위한 public getter 추가
  Map<String, GameItem> getItemsMap() => Map.unmodifiable(_items);
  
  /// 아이템 정의 등록
  void registerDefinition(ItemDefinition definition) {
    _definitions[definition.id] = definition;
  }
  
  /// 새 아이템 인스턴스 생성
  GameItem createItem(String definitionId) {
    final definition = _definitions[definitionId];
    if (definition == null) {
      throw ArgumentError('Unknown item definition: $definitionId');
    }
    
    final instance = ItemInstance(
      instanceId: '${definitionId}_${DateTime.now().millisecondsSinceEpoch}',
      definitionId: definitionId,
    );
    
    final gameItem = GameItem(
      definition: definition,
      instance: instance,
    );
    
    _items[instance.instanceId] = gameItem;
    return gameItem;
  }
  
  /// 아이템 조회
  GameItem? getItem(String instanceId) => _items[instanceId];
  
  /// 모든 아이템 조회
  List<GameItem> getAllItems() => _items.values.toList();
  
  /// 전투용 스냅샷 생성
  List<CombatSnapshot> createCombatSnapshots(List<String> itemIds) {
    final items = itemIds.map((id) => _items[id]).whereType<GameItem>().toList();
    final snapshots = <CombatSnapshot>[];
    
    for (final item in items) {
      final finalStats = _calculator.calculateFinalStats(item, items);
      final activeSynergies = _calculator.calculateActiveSynergies(items);
      
      final snapshot = CombatAdapter.createSnapshot(
        item,
        finalStats,
        activeSynergies.map((s) => s.name).toList(),
      );
      
      snapshots.add(snapshot);
    }
    
    return snapshots;
  }
}
