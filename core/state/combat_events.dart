import 'events.dart';
import '../../combat/combat_entity.dart';
import '../../combat/status_effect.dart';

/// 최대체력 이벤트 타입
enum HealthEventType {
  maxHealthIncreased,    // 최대체력 증가
  maxHealthDecreased,    // 최대체력 감소
  healthRestored,        // 체력 회복
  combatStarted,         // 전투 시작
}

/// 전투 관련 이벤트들의 기본 클래스
abstract class CombatEvent extends GEvent {
  const CombatEvent();
}

/// 체력 변화 이벤트
class HealthChangedEvent extends CombatEvent {
  final HealthEventType healthEventType;
  final int amount;
  final int oldMaxHealth;
  final int newMaxHealth;
  final int oldCurrentHealth;
  final int newCurrentHealth;
  final String source;
  final CombatEntity entity;
  final Map<String, dynamic> data;
  
  const HealthChangedEvent({
    required this.healthEventType,
    required this.amount,
    required this.oldMaxHealth,
    required this.newMaxHealth,
    required this.oldCurrentHealth,
    required this.newCurrentHealth,
    required this.source,
    required this.entity,
    this.data = const {},
  });
  
  @override
  String toString() => 'HealthChangedEvent($healthEventType: $oldCurrentHealth→$newCurrentHealth, source: $source)';
}

/// 데미지를 입힘
class DamageDealtEvent extends CombatEvent {
  final CombatEntity source;
  final CombatEntity target;
  final int damage;
  final bool isCritical;
  final String weaponName;
  
  const DamageDealtEvent({
    required this.source,
    required this.target,
    required this.damage,
    required this.isCritical,
    required this.weaponName,
  });
  
  @override
  String toString() => 'DamageDealtEvent($weaponName: $damage damage${isCritical ? " (CRIT)" : ""})';
}

/// 데미지를 받음
class DamageTakenEvent extends CombatEvent {
  final CombatEntity entity;
  final int damage;
  final String source;
  final int? rawDamage;  // 원본 피해 (방어 적용 전)
  final int? defenseReduced;  // 방어로 막은 양
  
  const DamageTakenEvent({
    required this.entity,
    required this.damage,
    required this.source,
    this.rawDamage,
    this.defenseReduced,
  });
  
  @override
  String toString() {
    if (rawDamage != null && defenseReduced != null && defenseReduced! > 0) {
      return 'DamageTakenEvent($rawDamage → $damage damage from $source, blocked: $defenseReduced)';
    }
    return 'DamageTakenEvent($damage from $source)';
  }
}

/// 회복
class HealEvent extends CombatEvent {
  final CombatEntity entity;
  final int amount;
  final String source;
  
  const HealEvent({
    required this.entity,
    required this.amount,
    required this.source,
  });
  
  @override
  String toString() => 'HealEvent(+$amount from $source)';
}

/// 크리티컬 히트
class CriticalHitEvent extends CombatEvent {
  final CombatEntity source;
  final CombatEntity target;
  final int damage;
  final String weaponName;
  
  const CriticalHitEvent({
    required this.source,
    required this.target,
    required this.damage,
    required this.weaponName,
  });
  
  @override
  String toString() => 'CriticalHitEvent($weaponName: $damage CRITICAL!)';
}

/// 효과 적용
class EffectAppliedEvent extends CombatEvent {
  final StatusEffect effect;
  final CombatEntity target;
  final CombatEntity? source;
  
  const EffectAppliedEvent({
    required this.effect,
    required this.target,
    this.source,
  });
  
  @override
  String toString() => 'EffectAppliedEvent(${effect.id} on $target)';
}

/// 효과 제거
class EffectRemovedEvent extends CombatEvent {
  final String effectId;
  final CombatEntity target;
  final int amount;
  final String effectType;
  
  const EffectRemovedEvent({
    required this.effectId,
    required this.target,
    required this.amount,
    required this.effectType,
  });
  
  @override
  String toString() => 'EffectRemovedEvent($effectId: $amount)';
}

/// 효과 스택 변화
class EffectStackChangedEvent extends CombatEvent {
  final String effectId;
  final CombatEntity target;
  final int oldStacks;
  final int newStacks;
  
  const EffectStackChangedEvent({
    required this.effectId,
    required this.target,
    required this.oldStacks,
    required this.newStacks,
  });
  
  @override
  String toString() => 'EffectStackChangedEvent($effectId: $oldStacks→$newStacks)';
}

/// 무기 대기열 추가
class WeaponQueuedEvent extends CombatEvent {
  final String weaponName;
  final CombatEntity user;
  final CombatEntity target;
  final double currentStamina;
  final double requiredStamina;
  
  const WeaponQueuedEvent({
    required this.weaponName,
    required this.user,
    required this.target,
    required this.currentStamina,
    required this.requiredStamina,
  });
  
  @override
  String toString() => 'WeaponQueuedEvent($weaponName: need ${requiredStamina - currentStamina} more stamina)';
}

/// 무기 자동 사용
class WeaponAutoUsedEvent extends CombatEvent {
  final String weaponName;
  final CombatEntity user;
  final CombatEntity target;
  
  const WeaponAutoUsedEvent({
    required this.weaponName,
    required this.user,
    required this.target,
  });
  
  @override
  String toString() => 'WeaponAutoUsedEvent($weaponName auto-used)';
}

/// 무기 대기열 취소
class WeaponCancelledEvent extends CombatEvent {
  final String weaponName;
  final CombatEntity user;
  final String reason;
  
  const WeaponCancelledEvent({
    required this.weaponName,
    required this.user,
    required this.reason,
  });
  
  @override
  String toString() => 'WeaponCancelledEvent($weaponName cancelled: $reason)';
}

/// 스태미나 소비
class StaminaConsumedEvent extends CombatEvent {
  final CombatEntity entity;
  final double amount;
  final double currentStamina;
  final String source;
  
  const StaminaConsumedEvent({
    required this.entity,
    required this.amount,
    required this.currentStamina,
    required this.source,
  });
  
  @override
  String toString() => 'StaminaConsumedEvent($source: -$amount, current: $currentStamina)';
}

/// 스태미나 회복
class StaminaRecoveredEvent extends CombatEvent {
  final CombatEntity entity;
  final double amount;
  final double currentStamina;
  
  const StaminaRecoveredEvent({
    required this.entity,
    required this.amount,
    required this.currentStamina,
  });
  
  @override
  String toString() => 'StaminaRecoveredEvent(+$amount, current: $currentStamina)';
}

/// 틱 이벤트 (전투 시스템용)
class CombatTickEvent extends CombatEvent {
  final double deltaTime;
  final int tickNumber;
  
  const CombatTickEvent({
    required this.deltaTime,
    required this.tickNumber,
  });
  
  @override
  String toString() => 'CombatTickEvent(tick #$tickNumber, dt: $deltaTime)';
}

