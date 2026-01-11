import 'dart:math';
import 'stats.dart';
import 'combat_entity.dart';
import 'character.dart';
import 'effect_type.dart';
import 'status_effect.dart';
import '../event_system.dart';
import 'item.dart';

/// 정화 아이템 - 디버프를 제거하는 아이템
class PurifyItem extends Item {
  final int purifyAmount;  // 정화할 디버프 스택 수

  PurifyItem({
    required String id,
    required String name,
    required double baseCooldown,
    required this.purifyAmount,
    CombatStats? stats,
  }) : super(
          id: id,
          name: name,
          type: ItemType.consumable,
          stats: stats ?? CombatStats.empty,
          baseCooldown: baseCooldown,
        );

  @override
  void applyEffect(CombatEntity user, CombatEntity target) {
    // Character 타입 체크
    if (target is! Character) {
      return;  // Character가 아니면 효과를 적용하지 않음
    }

    // 디버프만 필터링
    final debuffs = target.statusEffects.values
        .where((effect) => effect.type == EffectType.DEBUFF)
        .toList();

    if (debuffs.isEmpty) return;

    // 랜덤으로 디버프를 선택하고 스택 제거
    final random = Random();
    int remainingPurify = purifyAmount;

    while (remainingPurify > 0 && debuffs.isNotEmpty) {
      final index = random.nextInt(debuffs.length);
      final debuff = debuffs[index];

      final stacksToRemove = min(remainingPurify, debuff.stacks);
      debuff.removeStacks(stacksToRemove);
      remainingPurify -= stacksToRemove;

      if (debuff.isExpired()) {
        debuffs.removeAt(index);
        target.statusEffects.remove(debuff.id);
      }
    }

    // 정화 이벤트 발생
    // TODO: 새 이벤트 시스템으로 마이그레이션
    eventManager.dispatchEvent(GameEvent(
      type: GameEventType.EFFECT_REMOVED,
      data: {
        'amount': purifyAmount - remainingPurify,
        'target': target,
        'effectType': 'purify'
      }
    ));
  }
}

/// 중독 효과를 부여하는 아이템
class PoisonInflictingItem extends Item {
  final int poisonStacks;           // 부여할 중독 스택 수

  PoisonInflictingItem({
    required String id,
    required String name,
    required this.poisonStacks,
    required double baseCooldown,
    CombatStats? stats,
  }) : super(
          id: id,
          name: name,
          type: ItemType.consumable,
          stats: stats ?? CombatStats.empty,
          baseCooldown: baseCooldown,
        );

  @override
  void applyEffect(CombatEntity user, CombatEntity target) {
    // Character 타입이 아니면 효과 적용하지 않음
    if (target is! Character) return;

    // 기존 중독 효과 확인
    var poisonEffect = target.statusEffects['poison'] as PoisonEffect?;

    if (poisonEffect == null) {
      // 중독 효과가 없으면 새로 생성
      poisonEffect = PoisonEffect(
        target: target,
        initialStacks: poisonStacks,
      );
      target.statusEffects['poison'] = poisonEffect;

      // 효과 적용 이벤트
      // TODO: 새 이벤트 시스템으로 마이그레이션
      eventManager.dispatchEvent(GameEvent(
        type: GameEventType.EFFECT_APPLIED,
        data: {
          'effect': poisonEffect,
          'target': target,
          'source': user,
        },
      ));
    } else {
      // 기존 효과가 있으면 스택만 추가
      poisonEffect.addStacks(poisonStacks);
    }
  }
}

/// 사용 예시를 위한 테스트 함수
void testPurifyItem() {
  // 정화 아이템 생성
  final purifyPotion = PurifyItem(
    id: 'purify_potion_01',
    name: '정화 물약',
    baseCooldown: 10.0,  // 10초 쿨다운
    purifyAmount: 3,     // 3스택 제거
    stats: CombatStats(  // 수정된 스탯
      maxHealth: 10,     // ✅ 유효한 매개변수
      attackPower: 2,    // ✅ 유효한 매개변수
      accuracy: 5,       // ✅ 유효한 매개변수
    ),
  );

  // 아이템 사용 예시 (실제 Character 객체 필요)
  // purifyPotion.use(player, target);
} 