import 'dart:math';
import 'character_models.dart';
import '../../inventory/inventory_system.dart';
import '../../inventory/inventory_item.dart';

/// 캐릭터 특성 효과 적용 시스템
class CharacterEffectsSystem {
  /// 게임 시작시 특성 효과들을 적용
  void applyStartingEffects(
    Player player,
    InventorySystem inventory,
    List<InventoryItem> allBagItems,
  ) {
    for (final trait in player.traits) {
      _applyTraitEffect(trait, player, inventory, allBagItems);
    }
  }

  /// 개별 특성 효과 적용
  void _applyTraitEffect(
    Trait trait,
    Player player,
    InventorySystem inventory,
    List<InventoryItem> allBagItems,
  ) {
    switch (trait.id) {
      case 'obsessive':
        _applyObsessiveEffect(player, inventory, allBagItems);
        break;
      // 다른 특성 효과들도 여기에 추가
      default:
        break;
    }
  }

  /// 결벽증 특성 효과 적용
  void _applyObsessiveEffect(
    Player player,
    InventorySystem inventory,
    List<InventoryItem> allBagItems,
  ) {
    if (allBagItems.isEmpty) return;

    // 랜덤 가방 아이템 선택
    final random = Random();
    final bagTemplate = allBagItems[random.nextInt(allBagItems.length)];
    final bagToGive = bagTemplate.copyWith();

    // 텍스트형 인벤토리에서는 "배치 공간" 개념이 없으므로 바로 추가
    final added = inventory.tryAddItem(bagToGive, location: 'trait', condition: 'obsessive');
    if (added) {
      print('[ObsessiveTrait] 시작 가방 지급: ${bagToGive.name}');
    } else {
      print('[ObsessiveTrait] 시작 가방 지급 실패(인벤토리 잠김): ${bagToGive.name}');
    }
  }
}









