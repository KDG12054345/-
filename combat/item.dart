import 'dart:math' as math;
import 'combat_entity.dart';  // CombatEntity import로 변경
import 'character.dart';      // Character는 여전히 필요 (StatusEffect 때문에)
import 'status_effect.dart';
import 'effect_type.dart';
import 'stats.dart';
import 'effect_processor.dart';
import 'combat_rng.dart';     // 시드 기반 RNG
import '../event_system.dart' show GameEvent, GameEventType, eventManager;
import 'package:meta/meta.dart';           // @mustCallSuper 제공

// 아이템 종류를 구분하는 enum
enum ItemType {
  weapon,
  consumable,
  accessory,    // 추가
  armor,        // 추가
  // 다른 아이템 타입들...
}

/* ────────────────✨ ItemEffect 기본 클래스 추가 ✨─────────────── */
abstract class ItemEffect {
  const ItemEffect();
  void apply(CombatEntity user, CombatEntity target);
}

// 기본 아이템 클래스
abstract class Item {
  final String id;
  final String name;
  final ItemType type;
  final List<ItemEffect> effects;
  final CombatStats stats;

  // 쿨다운 관리용
  final double baseCooldown;
  double remainingCooldown = 0;

  Item({
    required this.id,
    required this.name,
    required this.type,
    required this.stats,
    this.effects = const [],
    this.baseCooldown = 0,
  });

  /// 실제 효과를 적용하는 추상 메서드
  void applyEffect(CombatEntity user, CombatEntity target);

  /// 기본 use 구현 (쿨다운 처리 포함)
  @mustCallSuper
  bool use(CombatEntity user, CombatEntity target) {
    if (remainingCooldown > 0) return false;

    applyEffect(user, target);
    remainingCooldown = baseCooldown;
    return true;
  }
}

// 장비 아이템 기본 클래스 (무기 외에 다른 장비도 치명타 제공 가능)
abstract class EquipmentItem extends Item {
  final double criticalChance;      // 치명타 확률 (0.0 ~ 1.0)
  final double criticalMultiplier;  // 치명타 배율 (1.0부터 시작)

  EquipmentItem({
    required super.id,
    required super.name,
    required super.type,
    required super.stats,
    super.effects = const [],
    super.baseCooldown = 0,
    this.criticalChance = 0.0,
    this.criticalMultiplier = 1.0,
  });
}

// 무기는 EquipmentItem을 상속
abstract class Weapon extends EquipmentItem {
  final double baseDamage;
  final double staminaCost;
  final double accuracy;
  
  /// 데미지 범위 (optional)
  /// 
  /// - 설정된 경우: min~max 범위에서 랜덤 롤로 기본 데미지 결정
  /// - 설정되지 않은 경우: baseDamage 단일값 사용 (레거시 호환)
  /// 
  /// 예시: DamageRange(min: 4, max: 5) → 적중 시 4 또는 5 데미지
  final DamageRange? damageRange;
  
  // criticalChance와 criticalMultiplier는 EquipmentItem에서 상속받으므로 여기서 정의하지 않음

  Weapon({
    required String id,
    required String name,
    required this.baseDamage,
    required this.staminaCost,
    required double baseCooldown,
    required this.accuracy,
    required double criticalChance,      // 매개변수로는 받음
    required double criticalMultiplier,  // 매개변수로는 받음
    this.damageRange,                    // 데미지 범위 (optional)
    CombatStats? stats,
    List<ItemEffect> effects = const [],
  }) : super(
          id: id,
          name: name,
          type: ItemType.weapon,
          stats: stats ?? CombatStats.empty,
          effects: effects,
          baseCooldown: baseCooldown,
          criticalChance: criticalChance,      // super에 전달
          criticalMultiplier: criticalMultiplier, // super에 전달
        );

  /* Item 의 추상 메서드 구현 */
  @override
  void applyEffect(CombatEntity user, CombatEntity target) {
    // 기본 효과: ItemEffect 리스트 적용
    for (final effect in effects) {
      effect.apply(user, target);
    }
  }
  
  /// 기본 데미지 롤
  /// 
  /// 데미지 계산 순서:
  /// 1. damageRange가 있으면: min~max 범위에서 랜덤 롤
  /// 2. damageRange가 없으면: baseDamage 단일값 사용
  /// 
  /// [rng]가 null이면 새 Random 인스턴스 사용 (비재현성, 레거시 호환)
  int rollBaseDamage(CombatRng? rng) {
    // damageRange가 설정된 경우
    if (damageRange != null) {
      final range = damageRange!;
      
      // 유효성 검증 및 fallback
      if (!range.isValid) {
        assert(false, '[Weapon] Invalid damageRange: $range, falling back to baseDamage');
        return baseDamage.round();
      }
      
      // 단일값 (min == max): RNG 호출 생략
      if (range.isSingle) {
        return range.min;
      }
      
      // RNG가 제공된 경우 시드 기반 롤
      if (rng != null) {
        return rng.rollDamageRange(range.min, range.max);
      }
      
      // RNG가 없으면 새 Random 사용 (레거시 호환)
      return range.min + math.Random().nextInt(range.max - range.min + 1);
    }
    
    // damageRange가 없으면 baseDamage 사용 (레거시 호환)
    return baseDamage.round();
  }
  
  /// 데미지 표시 문자열 (UI/툴팁용)
  /// 
  /// - 범위: "4–5"
  /// - 단일값: "5"
  String get damageDisplayString {
    if (damageRange != null) {
      return damageRange!.toDisplayString();
    }
    return baseDamage.round().toString();
  }

  @override
  bool use(CombatEntity user, CombatEntity target) {
    // 1. 스태미나 체크 및 즉시 소모
    if (!user.consumeStamina(staminaCost)) return false;
    
    // RNG 획득 (CombatEntity에서 제공, 없으면 null)
    final rng = user.combatRng;

    // 2. 명중 판정 (시드 기반 RNG 사용)
    final hitRoll = rng?.nextDouble() ?? math.Random().nextDouble();
    final hits = hitRoll <= accuracy;

    // 3. 명중했을 때만 데미지 계산 및 적용
    if (hits) {
      // 치명타 판정 이벤트 먼저 발생 (상태 효과들이 수정할 수 있도록)
      var critEventData = {
        'attacker': user,
        'target': target,
        'weapon': this,
        'criticalChance': criticalChance,
        'criticalMultiplier': criticalMultiplier,
      };
      
      eventManager.dispatchEvent(GameEvent(
        type: GameEventType.CRITICAL_HIT,
        data: critEventData,
      ));
      
      // 수정된 값으로 치명타 판정 (시드 기반 RNG 사용)
      final double finalCritChance = critEventData['criticalChance'] as double;
      final double finalCritMultiplier = critEventData['criticalMultiplier'] as double;
      final critRoll = rng?.nextDouble() ?? math.Random().nextDouble();
      final isCritical = critRoll <= finalCritChance;
      
      // ═══════════════════════════════════════════════════════════════════════════
      // 데미지 계산 (v2.0: 범위 데미지 지원)
      // ═══════════════════════════════════════════════════════════════════════════
      // 계산 순서:
      // (1) 기본 데미지 롤: damageRange 또는 baseDamage
      // (2) 공격력 추가: + user.combatStats.attackPower
      // (3) 크리티컬 배수 적용 (성공 시)
      // (4) 이후 방어/저항/버프/디버프 등 기존 파이프라인 적용
      // ═══════════════════════════════════════════════════════════════════════════
      final int rolledBaseDamage = rollBaseDamage(rng);
      double damage = rolledBaseDamage.toDouble() + user.combatStats.attackPower;
      
      if (isCritical) {
        damage *= finalCritMultiplier;
      }
      
      // 데미지 적용
      target.takeDamage(damage.round());
      
      // 데미지 이벤트 발생 (롤 결과 포함)
      eventManager.dispatchEvent(GameEvent(
        type: GameEventType.DAMAGE_DEALT,
        data: {
          'source': user,
          'target': target,
          'damage': damage.round(),
          'rolledBaseDamage': rolledBaseDamage,  // 롤 결과 스냅샷
          'weapon': this,
          'isCritical': isCritical,
        }
      ));
      
      // 추가 효과 적용
      applyEffect(user, target);
      
      // properties['effects'] 처리 (InventoryItem에서 변환된 무기의 경우)
      // EffectProcessor를 통해 확률 기반 효과 적용
      final sourceItem = EffectProcessor.getWeaponSource(this);
      if (sourceItem != null) {
        EffectProcessor.processWeaponEffects(
          weapon: this,
          attacker: user,
          target: target,
          sourceItem: sourceItem,
        );
      }
    }

    // 4. 쿨다운 적용 (명중 여부와 무관)
    remainingCooldown = baseCooldown;
    return true;
  }

  /// 쿨다운 갱신
  void updateCooldown(double deltaTimeMs) {
    if (remainingCooldown > 0) {
      remainingCooldown =
          math.max(0, remainingCooldown - deltaTimeMs / 1000.0);
    }
  }

  bool get isReady => remainingCooldown <= 0;
}

/* ────────────────🛠️ Melee / Ranged 무기 구현 🛠️─────────────── */
class MeleeWeapon extends Weapon {
  MeleeWeapon({
    required String id,
    required String name,
    required double baseDamage,
    required double staminaCost,
    required double baseCooldown,
    required double accuracy,
    required double criticalChance,
    required double criticalMultiplier,
    DamageRange? damageRange,  // 데미지 범위 (optional)
    CombatStats? stats,
    List<ItemEffect> effects = const [],
  }) : super(
          id: id,
          name: name,
          baseDamage: baseDamage,
          staminaCost: staminaCost,
          baseCooldown: baseCooldown,
          accuracy: accuracy,
          criticalChance: criticalChance,
          criticalMultiplier: criticalMultiplier,
          damageRange: damageRange,
          stats: stats,
          effects: effects,
        );
}

class RangedWeapon extends Weapon {
  RangedWeapon({
    required String id,
    required String name,
    required double baseDamage,
    required double staminaCost,
    required double baseCooldown,
    required double accuracy,
    required double criticalChance,
    required double criticalMultiplier,
    DamageRange? damageRange,  // 데미지 범위 (optional)
    CombatStats? stats,
    List<ItemEffect> effects = const [],
  }) : super(
          id: id,
          name: name,
          baseDamage: baseDamage,
          staminaCost: staminaCost,
          baseCooldown: baseCooldown,
          accuracy: accuracy,
          criticalChance: criticalChance,
          criticalMultiplier: criticalMultiplier,
          damageRange: damageRange,
          stats: stats,
          effects: effects,
        );
}

// 액세서리 예시 (치명타 제공 가능)
class Accessory extends EquipmentItem {
  Accessory({
    required String id,
    required String name,
    required double criticalChance,
    required double criticalMultiplier,
    CombatStats? stats,
    List<ItemEffect> effects = const [],
  }) : super(
          id: id,
          name: name,
          type: ItemType.accessory,  // 새로운 아이템 타입
          stats: stats ?? CombatStats.empty,
          effects: effects,
          criticalChance: criticalChance,
          criticalMultiplier: criticalMultiplier,
        );

  @override
  void applyEffect(CombatEntity user, CombatEntity target) {
    // 액세서리의 특수 효과 적용
    for (final effect in effects) {
      effect.apply(user, target);
    }
  }
}

// 방어구 예시 (치명타 제공 가능)
class Armor extends EquipmentItem {
  final double damageReduction;

  Armor({
    required String id,
    required String name,
    required this.damageReduction,
    double criticalChance = 0.0,
    double criticalMultiplier = 1.0,
    CombatStats? stats,
    List<ItemEffect> effects = const [],
  }) : super(
          id: id,
          name: name,
          type: ItemType.armor,  // 새로운 아이템 타입
          stats: stats ?? CombatStats.empty,
          effects: effects,
          criticalChance: criticalChance,
          criticalMultiplier: criticalMultiplier,
        );

  @override
  void applyEffect(CombatEntity user, CombatEntity target) {
    // 방어구의 특수 효과 적용
    for (final effect in effects) {
      effect.apply(user, target);
    }
  }
}

/// 마나 획득 아이템
class ManaGainItem extends Item {
  final int manaGainAmount;

  ManaGainItem({
    required String id,
    required String name,
    required this.manaGainAmount,
    required double baseCooldown,
    CombatStats? stats,
  }) : super(
    id: id,
    name: name,
    type: ItemType.consumable,      // ✅ 추가
    stats: stats ?? CombatStats(),
    baseCooldown: baseCooldown,
  );

  @override
  void applyEffect(CombatEntity user, CombatEntity target) {
    // Character 타입 체크를 먼저 수행
    if (user is! Character) {
      print('Warning: ManaGainItem can only be used by Characters');
      return;
    }
    
    // 이제 user는 Character 타입으로 처리됨
    var manaEffect = user.statusEffects['mana'] as ManaEffect?;
    if (manaEffect == null) {
      manaEffect = ManaEffect(
        target: user,
      );
      user.statusEffects['mana'] = manaEffect;
    }
    
    manaEffect.addStacks(manaGainAmount);
  }
}

/// 마나 소비 아이템
class ManaConsumingItem extends Item {
  final int manaCost;

  ManaConsumingItem({
    required String id,
    required String name,
    required this.manaCost,
    required double baseCooldown,
    CombatStats? stats,
  }) : super(
    id: id,
    name: name,
    type: ItemType.consumable,      // ✅ 추가
    stats: stats ?? CombatStats(),
    baseCooldown: baseCooldown,
  );

  @override
  void applyEffect(CombatEntity user, CombatEntity target) {
    if (user is! Character) return;  // Character 타입 체크 추가
    
    final manaEffect = user.statusEffects['mana'] as ManaEffect?;
    if (manaEffect?.tryConsume(manaCost) == true) {
      onEffectApplied(user, target);
      
      if (manaEffect!.isExpired()) {
        user.statusEffects.remove('mana');
      }
    }
  }

  /// 실제 아이템 효과 구현 (하위 클래스에서 구현)
  void onEffectApplied(CombatEntity user, CombatEntity target) {}  // Character를 CombatEntity로 변경
}

/// 화상 효과를 부여하는 아이템
class BurnInflictingItem extends Item {
  final int burnStacks;

  BurnInflictingItem({
    required String id,
    required String name,
    required this.burnStacks,
    required double baseCooldown,
    CombatStats? stats,
  }) : super(
    id: id,
    name: name,
    type: ItemType.consumable,      // ✅ 추가
    stats: stats ?? CombatStats(),
    baseCooldown: baseCooldown,
  );

  @override
  void applyEffect(CombatEntity user, CombatEntity target) {
    // Character 타입 체크를 먼저 수행
    if (target is! Character) {
      print('Warning: BurnEffect can only be applied to Characters');
      return;
    }
    
    var burnEffect = target.statusEffects['burn'] as BurnEffect?;
    
    if (burnEffect == null) {
      burnEffect = BurnEffect(
        initialStacks: burnStacks,
        target: target,
      );
      target.statusEffects['burn'] = burnEffect;
      
      eventManager.dispatchEvent(GameEvent(
        type: GameEventType.EFFECT_APPLIED,
        data: {
          'effect': burnEffect,
          'target': target,
          'source': user,
        }
      ));
    } else {
      burnEffect.addStacks(burnStacks);
    }
  }
}

/// 생명력 흡수 효과를 부여하는 아이템
class LifestealInflictingItem extends Item {
  final int lifestealStacks;

  LifestealInflictingItem({
    required String id,
    required String name,
    required this.lifestealStacks,
    required double baseCooldown,
    CombatStats? stats,
  }) : super(
    id: id,
    name: name,
    type: ItemType.consumable,      // ✅ 추가
    stats: stats ?? CombatStats(),
    baseCooldown: baseCooldown,
  );

  @override
  void applyEffect(CombatEntity user, CombatEntity target) {
    if (target is! Character) return;  // Character 타입 체크 추가
    
    var lifestealEffect = target.statusEffects['lifesteal'] as LifestealEffect?;
    
    if (lifestealEffect == null) {
      lifestealEffect = LifestealEffect(
        initialStacks: lifestealStacks,
        target: target,
      );
      target.statusEffects['lifesteal'] = lifestealEffect;
      
      eventManager.dispatchEvent(GameEvent(
        type: GameEventType.EFFECT_APPLIED,
        data: {
          'effect': lifestealEffect,
          'target': target,
          'source': user,
        }
      ));
    } else {
      lifestealEffect.addStacks(lifestealStacks);
    }
  }
} 

/// 동상 효과를 부여하는 아이템
class FrostInflictingItem extends Item {  // FreezeInflicting -> FrostInflicting
  final int frostStacks;  // freeze -> frost

  FrostInflictingItem({
    required String id,
    required String name,
    required this.frostStacks,
    required double baseCooldown,
    CombatStats? stats,
  }) : super(
    id: id,
    name: name,
    type: ItemType.consumable,      // ✅ 추가
    stats: stats ?? CombatStats(),
    baseCooldown: baseCooldown,
  );

  @override
  void applyEffect(CombatEntity user, CombatEntity target) {
    if (target is! Character) return;
    
    var frostEffect = target.statusEffects['frost'] as FrostEffect?;  // freeze -> frost
    
    if (frostEffect == null) {
      frostEffect = FrostEffect(
        target: target,
        initialStacks: frostStacks,
      );
      target.statusEffects['frost'] = frostEffect;
      
      eventManager.dispatchEvent(GameEvent(
        type: GameEventType.EFFECT_APPLIED,
        data: {
          'effect': frostEffect,
          'target': target,
          'source': user,
        }
      ));
    } else {
      frostEffect.addStacks(frostStacks);
    }
  }
} 

/// 실명 효과를 부여하는 아이템
class BlindInflictingItem extends Item {
  final int blindStacks;  // 부여할 실명 스택 수

  BlindInflictingItem({
    required String id,
    required String name,
    required this.blindStacks,
    required double baseCooldown,
    CombatStats? stats,
  }) : super(
    id: id,
    name: name,
    type: ItemType.consumable,      // ✅ 추가
    stats: stats ?? CombatStats(),
    baseCooldown: baseCooldown,
  );

  @override
  void applyEffect(CombatEntity user, CombatEntity target) {
    if (target is! Character) return;
    
    var blindEffect = target.statusEffects['blind'] as BlindEffect?;
    
    if (blindEffect == null) {
      // 실명 효과가 없으면 새로 생성
      blindEffect = BlindEffect(
        target: target,
        initialStacks: blindStacks,
      );
      target.statusEffects['blind'] = blindEffect;
      
      // 효과 적용 이벤트 발생
      eventManager.dispatchEvent(GameEvent(
        type: GameEventType.EFFECT_APPLIED,
        data: {
          'effect': blindEffect,
          'target': target,
          'source': user,
        }
      ));
    } else {
      // 이미 있으면 스택 추가
      blindEffect.addStacks(blindStacks);
    }
  }
} 

/// 스태미너 회복 아이템
class StaminaRecoveryItem extends Item {
  final double staminaRecoveryAmount;

  StaminaRecoveryItem({
    required String id,
    required String name,
    required this.staminaRecoveryAmount,
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
    target.recoverStamina(staminaRecoveryAmount);
  }
}

/// 스태미너 회복 속도 증가 효과 (상태효과)
class StaminaRegenEffect extends StatusEffect {
  final double regenMultiplier; // 회복 속도 배율

  StaminaRegenEffect({
    required CombatEntity target,
    required this.regenMultiplier,
    int initialStacks = 1,
    double? duration = 30000, // 30초, make it optional
  }) : super(
    id: 'stamina_regen',
    name: '스태미너 회복 증진',
    type: EffectType.BUFF,
    stacks: initialStacks,
    target: target,
    maxDuration: duration,  // Pass duration as maxDuration
  );

  @override
  void tick(double deltaTimeMs) {
    reduceDuration(deltaTimeMs);
  }

  @override
  CombatStats getEffectModifiers() => CombatStats.empty;

  /// 스태미너 회복 배율 반환
  double getStaminaRegenMultiplier() {
    return 1.0 + (stacks * regenMultiplier);
  }
}

/// 스태미너 회복 증진 아이템
class StaminaRegenBoostItem extends Item {
  final double regenMultiplier;
  final double duration;

  StaminaRegenBoostItem({
    required String id,
    required String name,
    required this.regenMultiplier,
    required this.duration,
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
    if (target is! Character) return;

    var regenEffect = target.statusEffects['stamina_regen'] as StaminaRegenEffect?;
    
    if (regenEffect == null) {
      regenEffect = StaminaRegenEffect(
        target: target,
        regenMultiplier: regenMultiplier,
        duration: duration,
      );
      target.statusEffects['stamina_regen'] = regenEffect;
      
      eventManager.dispatchEvent(GameEvent(
        type: GameEventType.EFFECT_APPLIED,
        data: {
          'effect': regenEffect,
          'target': target,
          'source': user,
        }
      ));
    } else {
      regenEffect.addStacks(1);
      regenEffect.resetDuration(duration);
    }
  }
} 
