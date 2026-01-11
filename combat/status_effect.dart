import 'dart:math' as math;
import 'character.dart';  // Character 클래스 import 추가
import 'stats.dart';
import 'effect_type.dart';  // EffectType enum import 추가
import '../event_system.dart';
import 'combat_entity.dart';  // CombatEntity import 추가
import 'item.dart';  // Item 클래스 import 추가
import 'combat_engine.dart';


/// 상태 효과의 기본 클래스
abstract class StatusEffect {
  final String id;
  final String name;
  final EffectType type;
  int stacks;
  final CombatEntity target;  // Character를 CombatEntity로 변경
  double _duration;  // Add duration tracking
  final double _maxDuration;  // Add max duration

  StatusEffect({
    required this.id,
    required this.name,
    required this.type,
    this.stacks = 0,
    required this.target,
    double? maxDuration,  // Make maxDuration optional
  }) : _maxDuration = maxDuration ?? double.infinity,  // Default to infinite duration
       _duration = maxDuration ?? double.infinity;

  /// 매 틱마다 호출되는 로직
  void tick(double deltaTimeMs) {
    // 기본 구현은 비어있음
    // 하위 클래스에서 필요한 경우 오버라이드
  }

  /// Reduce the remaining duration
  void reduceDuration(double deltaTimeMs) {
    if (_maxDuration == double.infinity) return;
    _duration = math.max(0, _duration - deltaTimeMs);
  }

  /// Reset the duration to its maximum value or a new specified duration
  void resetDuration([double? newDuration]) {
    _duration = newDuration ?? _maxDuration;
  }

  /// Check if the effect has expired due to duration or stacks
  bool isExpired() => stacks <= 0 || _duration <= 0;

  /// 기존: 단순 스탯 합산용
  CombatStats getEffectModifiers() => CombatStats();

  /// 치명타 확률 수정 (0.0 ~ 1.0)
  double modifyCritChance(double base) => base;

  /// 치명타 배율 수정 (>= 1.0)
  double modifyCritMultiplier(double base) => base;

  /// 최대 체력 수정 (base: 원래 최대 체력)
  int modifyMaxHealth(int base) => base;

  /// 스택 추가
  void addStacks(int amount) {
    if (amount < 0) return;
    stacks = math.min(stacks + amount, getMaxStacks());
  }

  /// 스택 제거
  void removeStacks(int amount) {
    if (amount < 0) return;
    stacks = math.max(0, stacks - amount);
  }

  /// 최대 스택 수 반환
  int getMaxStacks() => 100;

  // 이벤트 기반 시스템에서 사용할 메서드들
  void onEvent(GameEvent event) {
    switch (event.type) {
      case GameEventType.TICK:
        final deltaTime = event.data['deltaTime'] as double? ?? 0.0;  // 기본값 0.0 사용
        tick(deltaTime);  // onTick 대신 tick 직접 호출
        break;
      case GameEventType.EFFECT_STACK_CHANGED:
        onStackChanged(event.data['oldStack'], event.data['newStack']);
        break;
      case GameEventType.STAMINA_CONSUMED:  // 새로운 이벤트 타입 추가
        // 기본적으로는 스태미나 소비에 대해 특별한 처리를 하지 않음
        break;
      default:
        // 다른 이벤트들은 하위 클래스에서 처리
        break;
    }
  }

  void onStackChanged(int oldStack, int newStack) {
    // 기본 구현은 비어있음
  }
}

/// 마나 효과
class ManaEffect extends StatusEffect {
  // maxStacks 필드 제거

  ManaEffect({
    required CombatEntity target,  // target 매개변수 필수
  }) : super(
    id: 'mana',
    name: '마나',
    type: EffectType.BUFF,
    target: target,  // target 전달
  );

  @override
  void tick(double deltaTimeMs) {
    // 마나는 시간 경과에 따른 자동 감소/증가가 없으므로 아무 동작도 하지 않음
    // 스택은 아이템 사용을 통해서만 변경됨
  }

  @override
  bool isExpired() => stacks <= 0;  // 스택이 0이면 효과 소멸

  /// 마나 스택 소비 시도
  bool tryConsume(int amount) {
    if (stacks >= amount) {
      removeStacks(amount);
      return true;
    }
    return false;
  }

  /// 스택 추가 (제한 없음)
  @override
  void addStacks(int amount) {
    if (amount < 0) return;
    stacks += amount; // 제한 없이 누적
  }

  /// 스택 제거
  @override
  void removeStacks(int amount) {
    if (amount < 0) return;
    stacks = math.max(0, stacks - amount);
  }

  /// 최대 스택 수 반환 (제한 없음을 나타내기 위해 매우 큰 값 반환)
  @override
  int getMaxStacks() => 2147483647;  // Int32 최대값

  @override
  void onEvent(GameEvent event) {
    super.onEvent(event);
    
    switch (event.type) {
      case GameEventType.MANA_CONSUME:
        // 마나 소비 처리
        final int amount = event.data['amount'] as int;
        removeStacks(amount);
        break;
      case GameEventType.MANA_GAIN:
        // 마나 획득 처리
        final int amount = event.data['amount'] as int;
        addStacks(amount);
        break;
      case GameEventType.EFFECT_STACK_CHANGED:
        if (stacks <= 0) {
          // 스택이 0이 되면 효과 제거 이벤트 발생
          eventManager.dispatchEvent(GameEvent(
            type: GameEventType.EFFECT_REMOVED,
            data: {'effect': this}
          ));
        }
        break;
      case GameEventType.TICK:
      case GameEventType.EFFECT_DURATION:
      case GameEventType.DAMAGE_DEALT:
      case GameEventType.DAMAGE_TAKEN:
      case GameEventType.HEAL:
      case GameEventType.CRITICAL_HIT:
      case GameEventType.EFFECT_APPLIED:
      case GameEventType.EFFECT_REMOVED:
      case GameEventType.ITEM_USE:
      case GameEventType.ITEM_COOLDOWN:
      case GameEventType.ADD_ITEM:
      case GameEventType.REMOVE_ITEM:
      case GameEventType.CHANGE_STAT:
      case GameEventType.SET_FLAG:
      case GameEventType.CHANGE_SCENE:
        // 다른 이벤트들은 무시
        break;
      case GameEventType.STAMINA_CONSUMED:
      case GameEventType.STAMINA_RECOVERED:
        // 스태미나 관련 이벤트는 ManaEffect와 무관
        break;
      case GameEventType.WEAPON_QUEUED:
      case GameEventType.WEAPON_AUTO_USED:
      case GameEventType.WEAPON_CANCELLED:
        break;
      default:
        break;
    }
  }
}

/// 마나 획득 아이템
class ManaGainItem extends Item {
  final int manaGainAmount;  // 획득할 마나 스택 수

  ManaGainItem({
    required super.id,
    required super.name,
    required this.manaGainAmount,
    required super.baseCooldown,
    CombatStats? stats,  // nullable로 변경
  }) : super(
      stats: stats ?? CombatStats.empty,
      type: ItemType.consumable  // 마나 획득 아이템은 소비형
    );  // null이면 empty 사용

  @override
  void applyEffect(CombatEntity user, CombatEntity target) {
    // Character 타입 체크
    if (user is! Character) {
      return;  // Character가 아니면 효과를 적용하지 않음
    }

    // 마나 효과가 없으면 새로 생성
    var manaEffect = user.statusEffects['mana'] as ManaEffect?;
    if (manaEffect == null) {
      manaEffect = ManaEffect(
        target: user,  // 마나는 사용자에게 적용
      );
      user.statusEffects['mana'] = manaEffect;
    }
    
    // 마나 스택 추가
    manaEffect.addStacks(manaGainAmount);
  }
}

/// 화상 효과 - 2초마다 스택당 1의 피해를 주는 디버프
class BurnEffect extends StatusEffect {
  double _damageTimer = 0;

  BurnEffect({
    required CombatEntity target,
    int initialStacks = 0,
  }) : super(
    id: 'burn',
    name: '화상',
    type: EffectType.DEBUFF,
    stacks: initialStacks,
    target: target,
  );

  @override
  void tick(double deltaTimeMs) {
    _damageTimer += deltaTimeMs;
    if (_damageTimer >= 1000) {  // 1초마다
      if (target is CombatEntity) {
        // target.takeDamage(stacks);  // 기존 코드, 삭제 금지
        final payload = DamagePayload(
          source: target, // 혹은 상태이상을 건 주체
          target: target,
          baseDamage: 5 * stacks,
          sourceType: DamageSourceType.burn,
          isDot: true,
          ignoresDefense: false,
          originEffectId: 'burn',
        );
        applyDamage(payload);
      }
      _damageTimer = 0;
    }
  }

  @override
  bool isExpired() => stacks <= 0;

  @override
  void onEvent(GameEvent event) {
    super.onEvent(event);
    
    switch (event.type) {
      case GameEventType.TICK:
        // tick 메서드에서 처리됨
        break;
      case GameEventType.EFFECT_STACK_CHANGED:
        if (stacks <= 0) {
          // 스택이 0이 되면 효과 제거 이벤트 발생
          eventManager.dispatchEvent(GameEvent(
            type: GameEventType.EFFECT_REMOVED,
            data: {'effect': this}
          ));
        }
        break;
      case GameEventType.EFFECT_DURATION:
      case GameEventType.DAMAGE_DEALT:
      case GameEventType.DAMAGE_TAKEN:
      case GameEventType.HEAL:
      case GameEventType.CRITICAL_HIT:
      case GameEventType.EFFECT_APPLIED:
      case GameEventType.EFFECT_REMOVED:
      case GameEventType.MANA_CONSUME:
      case GameEventType.MANA_GAIN:
      case GameEventType.ITEM_USE:
      case GameEventType.ITEM_COOLDOWN:
      case GameEventType.ADD_ITEM:
      case GameEventType.REMOVE_ITEM:
      case GameEventType.CHANGE_STAT:
      case GameEventType.SET_FLAG:
      case GameEventType.CHANGE_SCENE:
        // 화상 효과와 관련 없는 이벤트들은 무시
        break;
      case GameEventType.STAMINA_CONSUMED:
      case GameEventType.STAMINA_RECOVERED:
        // 스태미나 관련 이벤트 무시
        break;
      case GameEventType.WEAPON_QUEUED:
      case GameEventType.WEAPON_AUTO_USED:
      case GameEventType.WEAPON_CANCELLED:
        break;
      default:
        break;
    }
  }

  /// 화상 효과의 현재 2초당 데미지 계산
  int getCurrentDamagePerTick() {
    return stacks;  // 스택당 1의 피해
  }

  @override
  int getMaxStacks() => 2147483647;  // Int32 최대값 (실질적으로 무제한)
}

/// 생명력 흡수 효과 - 공격 적중 시 스택당 1의 회복을 제공하는 버프
class LifestealEffect extends StatusEffect {
  LifestealEffect({
    required CombatEntity target,
    int initialStacks = 0,
  }) : super(
    id: 'lifesteal',
    name: '생명력 흡수',
    type: EffectType.BUFF,
    stacks: initialStacks,
    target: target,
  );

  @override
  void tick(double deltaTimeMs) {
    // 생명력 흡수는 공격 시에만 발동하므로 틱에서는 아무것도 하지 않음
  }

  @override
  void onEvent(GameEvent event) {
    super.onEvent(event);
    
    switch (event.type) {
      case GameEventType.DAMAGE_DEALT:
        // 데미지를 줄 때마다 스택만큼 회복
        if (event.data['source'] == target) {  // 효과를 가진 캐릭터가 데미지를 준 경우
          int damage = event.data['damage'] as int;
          if (damage > 0) {
            int healAmount = stacks;  // 스택당 1의 회복량
            target.heal(healAmount);
            
            // 회복 이벤트 발생
            eventManager.dispatchEvent(GameEvent(
              type: GameEventType.HEAL,
              data: {
                'source': this,
                'target': target,
                'amount': healAmount,
                'type': 'lifesteal',
              }
            ));
          }
        }
        break;
      case GameEventType.TICK:
      case GameEventType.EFFECT_DURATION:
      case GameEventType.DAMAGE_TAKEN:
      case GameEventType.HEAL:
      case GameEventType.CRITICAL_HIT:
      case GameEventType.EFFECT_APPLIED:
      case GameEventType.EFFECT_REMOVED:
      case GameEventType.EFFECT_STACK_CHANGED:
      case GameEventType.MANA_CONSUME:
      case GameEventType.MANA_GAIN:
      case GameEventType.ITEM_USE:
      case GameEventType.ITEM_COOLDOWN:
      case GameEventType.ADD_ITEM:
      case GameEventType.REMOVE_ITEM:
      case GameEventType.CHANGE_STAT:
      case GameEventType.SET_FLAG:
      case GameEventType.CHANGE_SCENE:
        // 생명력 흡수 효과와 관련 없는 이벤트들은 무시
        break;
      case GameEventType.STAMINA_CONSUMED:
      case GameEventType.STAMINA_RECOVERED:
        break;
      case GameEventType.WEAPON_QUEUED:
      case GameEventType.WEAPON_AUTO_USED:
      case GameEventType.WEAPON_CANCELLED:
        break;
      default:
        break;
    }
  }

  @override
  bool isExpired() => stacks <= 0;

  @override
  int getMaxStacks() => 2147483647;  // Int32 최대값 (실질적으로 무제한)
}

/// 행운 효과 - 이벤트 기반으로 치명타 확률 증가
class LuckEffect extends StatusEffect {
  LuckEffect({
    required CombatEntity target,  // target을 필수 매개변수로 추가
    int initialStacks = 0,
  }) : super(
    id: 'luck',
    name: '행운',
    type: EffectType.BUFF,
    stacks: initialStacks,
    target: target,  // 전달받은 target 사용
  );

  @override
  void tick(double deltaTimeMs) {
    // 시간 경과에 따른 스택 감소 없음
  }

  @override
  bool isExpired() => stacks <= 0;  // 스택이 0이면 효과 소멸

  @override
  CombatStats getEffectModifiers() {
    // 스택당 정확성 3% 증가만 적용 (치명타 관련 제거)
    return CombatStats(
      accuracy: (stacks * 3),  // 3% per stack
    );
  }

  @override
  void onEvent(GameEvent event) {
    super.onEvent(event);
    
    switch (event.type) {
      case GameEventType.EFFECT_STACK_CHANGED:
        if (stacks <= 0) {
          // 스택이 0이 되면 효과 제거 이벤트 발생
          eventManager.dispatchEvent(GameEvent(
            type: GameEventType.EFFECT_REMOVED,
            data: {'effect': this}
          ));
        }
        break;
      case GameEventType.TICK:
      case GameEventType.EFFECT_DURATION:
      case GameEventType.DAMAGE_DEALT:
      case GameEventType.DAMAGE_TAKEN:
      case GameEventType.HEAL:
      case GameEventType.CRITICAL_HIT:
      case GameEventType.EFFECT_APPLIED:
      case GameEventType.EFFECT_REMOVED:
      case GameEventType.MANA_CONSUME:
      case GameEventType.MANA_GAIN:
      case GameEventType.ITEM_USE:
      case GameEventType.ITEM_COOLDOWN:
      case GameEventType.ADD_ITEM:
      case GameEventType.REMOVE_ITEM:
      case GameEventType.CHANGE_STAT:
      case GameEventType.SET_FLAG:
      case GameEventType.CHANGE_SCENE:
        // 행운 효과와 관련 없는 이벤트들은 무시
        break;
      case GameEventType.STAMINA_CONSUMED:
      case GameEventType.STAMINA_RECOVERED:
        break;
      case GameEventType.WEAPON_QUEUED:
      case GameEventType.WEAPON_AUTO_USED:
      case GameEventType.WEAPON_CANCELLED:
        break;
      default:
        break;
    }
  }
} 

/// 가시 효과
class ThornsEffect extends StatusEffect {
  ThornsEffect({
    required CombatEntity target,  // target을 필수 매개변수로 추가
    int initialStacks = 0,
  }) : super(
    id: 'thorns',
    name: '가시',
    type: EffectType.BUFF,
    stacks: initialStacks,
    target: target,  // 전달받은 target 사용
  );

  @override
  void tick(double deltaTimeMs) {
    // 시간 경과에 따른 스택 감소 없음
  }

  @override
  bool isExpired() => stacks <= 0;  // 스택이 0이면 효과 소멸

  @override
  void onEvent(GameEvent event) {
    super.onEvent(event);
    
    switch (event.type) {
      case GameEventType.CRITICAL_HIT:
        // 근접 치명타를 받았을 때만 처리
        if (event.data['target'] == true && event.data['isCloseRange'] == true) {
          // 공격자에게 스택당 1의 피해를 줌
          final attacker = event.data['attacker'] as Character;
          final damage = stacks;  // 스택당 1의 피해
          
          // 피해 이벤트 발생
          eventManager.dispatchEvent(GameEvent(
            type: GameEventType.DAMAGE_DEALT,
            data: {
              'source': event.data['target'],  // 가시 효과 보유자
              'target': attacker,
              'damage': damage,
              'isThorns': true  // 가시 피해임을 표시
            }
          ));
        }
        break;
      case GameEventType.EFFECT_STACK_CHANGED:
        if (stacks <= 0) {
          // 스택이 0이 되면 효과 제거 이벤트 발생
          eventManager.dispatchEvent(GameEvent(
            type: GameEventType.EFFECT_REMOVED,
            data: {'effect': this}
          ));
        }
        break;
      case GameEventType.TICK:
      case GameEventType.EFFECT_DURATION:
      case GameEventType.DAMAGE_DEALT:
      case GameEventType.DAMAGE_TAKEN:
      case GameEventType.HEAL:
      case GameEventType.EFFECT_APPLIED:
      case GameEventType.EFFECT_REMOVED:
      case GameEventType.MANA_CONSUME:
      case GameEventType.MANA_GAIN:
      case GameEventType.ITEM_USE:
      case GameEventType.ITEM_COOLDOWN:
      case GameEventType.ADD_ITEM:
      case GameEventType.REMOVE_ITEM:
      case GameEventType.CHANGE_STAT:
      case GameEventType.SET_FLAG:
      case GameEventType.CHANGE_SCENE:
        // 가시 효과와 관련 없는 이벤트들은 무시
        break;
      case GameEventType.STAMINA_CONSUMED:
      case GameEventType.STAMINA_RECOVERED:
        break;
      case GameEventType.WEAPON_QUEUED:
      case GameEventType.WEAPON_AUTO_USED:
      case GameEventType.WEAPON_CANCELLED:
        break;
      default:
        break;
    }
  }
} 

/// 회복 효과
class RegenerationEffect extends StatusEffect {
  static const double HEAL_INTERVAL = 2000.0;  // 2초(2000ms)마다 회복
  double _timeSinceLastHeal = 0.0;  // 마지막 회복 이후 경과 시간

  RegenerationEffect({
    required CombatEntity target,  // target을 필수 매개변수로 추가
    int initialStacks = 0,
  }) : super(
    id: 'regeneration',
    name: '회복',
    type: EffectType.BUFF,
    stacks: initialStacks,
    target: target,  // 전달받은 target 사용
  );

  @override
  void tick(double deltaTimeMs) {
    _timeSinceLastHeal += deltaTimeMs;
    
    // 2초마다 회복 처리
    if (_timeSinceLastHeal >= HEAL_INTERVAL) {
      // 스택당 1의 체력 회복
      final healAmount = stacks;
      
      // 회복 이벤트 발생
      eventManager.dispatchEvent(GameEvent(
        type: GameEventType.HEAL,
        data: {
          'target': target,
          'amount': healAmount,
          'source': this
        }
      ));
      
      // 타이머 리셋 (남은 시간 고려)
      _timeSinceLastHeal -= HEAL_INTERVAL;
    }
  }

  @override
  bool isExpired() => stacks <= 0;  // 스택이 0이면 효과 소멸

  @override
  void onEvent(GameEvent event) {
    super.onEvent(event);
    
    switch (event.type) {
      case GameEventType.EFFECT_STACK_CHANGED:
        if (stacks <= 0) {
          // 스택이 0이 되면 효과 제거 이벤트 발생
          eventManager.dispatchEvent(GameEvent(
            type: GameEventType.EFFECT_REMOVED,
            data: {'effect': this}
          ));
        }
        break;
      case GameEventType.TICK:
      case GameEventType.EFFECT_DURATION:
      case GameEventType.DAMAGE_DEALT:
      case GameEventType.DAMAGE_TAKEN:
      case GameEventType.HEAL:
      case GameEventType.CRITICAL_HIT:
      case GameEventType.EFFECT_APPLIED:
      case GameEventType.EFFECT_REMOVED:
      case GameEventType.MANA_CONSUME:
      case GameEventType.MANA_GAIN:
      case GameEventType.ITEM_USE:
      case GameEventType.ITEM_COOLDOWN:
      case GameEventType.ADD_ITEM:
      case GameEventType.REMOVE_ITEM:
      case GameEventType.CHANGE_STAT:
      case GameEventType.SET_FLAG:
      case GameEventType.CHANGE_SCENE:
        // 회복 효과와 관련 없는 이벤트들은 무시
        break;
      case GameEventType.STAMINA_CONSUMED:
      case GameEventType.STAMINA_RECOVERED:
        break;
      case GameEventType.WEAPON_QUEUED:
      case GameEventType.WEAPON_AUTO_USED:
      case GameEventType.WEAPON_CANCELLED:
        break;
      default:
        break;
    }
  }
} 

/// 출혈 효과 - 방어력 무시 지속 피해 + 치명타 데미지 증가
class BleedingEffect extends StatusEffect {
  double _timeSinceLastTick = 0.0;
  static const double DAMAGE_INTERVAL = 3000.0; // 3초(ms)

  BleedingEffect({
    required CombatEntity target,
    int initialStacks = 0,
  }) : super(
    id: 'bleeding',
    name: '출혈',
    type: EffectType.DEBUFF,
    stacks: initialStacks,
    target: target,
  );

  @override
  void tick(double deltaTimeMs) {
    _timeSinceLastTick += deltaTimeMs;
    
    // 3초마다 스택당 1의 고정 피해
    if (_timeSinceLastTick >= DAMAGE_INTERVAL) {
      final trueDamage = stacks;
      // target.takeDamage(trueDamage, isTrueDamage: true); // 기존 코드, 삭제 금지
      applyDamage(DamagePayload(
        source: target,           // CombatEntity 타입으로 수정
        target: target,
        baseDamage: trueDamage,
        sourceType: DamageSourceType.dot,
        isDot: true,
        ignoresDefense: true,
        originEffectId: 'bleeding',
      ));
      
      // 피해 이벤트 발생
      eventManager.dispatchEvent(GameEvent(
        type: GameEventType.DAMAGE_DEALT,
        data: {
          'amount': trueDamage,
          'isTrueDamage': true,
          'source': this,
          'target': target,
          'type': 'bleeding',
        }
      ));
      
      _timeSinceLastTick -= DAMAGE_INTERVAL;
    }
  }

  @override
  void onEvent(GameEvent event) {
    super.onEvent(event);
    
    switch (event.type) {
      case GameEventType.CRITICAL_HIT:
        // 출혈 상태의 대상이 치명타를 받을 때 데미지 증가
        if (event.data['target'] == target) {
          final double originalMultiplier = event.data['criticalMultiplier'] as double? ?? 1.0;
          final double bonusMultiplier = stacks * 0.01;  // 스택당 1% 증가
          
          // 치명타 데미지 배율 증가
          event.data['criticalMultiplier'] = originalMultiplier + bonusMultiplier;
          
          // 출혈로 인한 치명타 강화 이벤트
          eventManager.dispatchEvent(GameEvent(
            type: GameEventType.EFFECT_STACK_CHANGED,
            data: {
              'effect': this,
              'enhancedCritical': true,
              'bonusMultiplier': bonusMultiplier,
              'finalMultiplier': event.data['criticalMultiplier'],
            }
          ));
        }
        break;
      case GameEventType.EFFECT_STACK_CHANGED:
        if (stacks <= 0) {
          eventManager.dispatchEvent(GameEvent(
            type: GameEventType.EFFECT_REMOVED,
            data: {'effect': this}
          ));
        }
        break;
      case GameEventType.TICK:
      case GameEventType.EFFECT_DURATION:
      case GameEventType.DAMAGE_DEALT:
      case GameEventType.DAMAGE_TAKEN:
      case GameEventType.HEAL:
      case GameEventType.CRITICAL_HIT:
      case GameEventType.EFFECT_APPLIED:
      case GameEventType.EFFECT_REMOVED:
      case GameEventType.MANA_CONSUME:
      case GameEventType.MANA_GAIN:
      case GameEventType.ITEM_USE:
      case GameEventType.ITEM_COOLDOWN:
      case GameEventType.ADD_ITEM:
      case GameEventType.REMOVE_ITEM:
      case GameEventType.CHANGE_STAT:
      case GameEventType.SET_FLAG:
      case GameEventType.CHANGE_SCENE:
        // 출혈 효과와 관련 없는 이벤트들은 무시
        break;
      case GameEventType.STAMINA_CONSUMED:
      case GameEventType.STAMINA_RECOVERED:
        break;
      case GameEventType.WEAPON_QUEUED:
      case GameEventType.WEAPON_AUTO_USED:
      case GameEventType.WEAPON_CANCELLED:
        break;
      default:
        break;
    }
  }

  @override
  int getMaxStacks() => 100; // 최대 100스택으로 제한

  @override
  bool isExpired() => stacks <= 0;
}

/// 디버프 저항 효과
class ResistanceEffect extends StatusEffect {
  ResistanceEffect({
    required CombatEntity target,  // target을 필수 매개변수로 추가
    int initialStacks = 0,
  }) : super(
    id: 'resistance',
    name: '저항',
    type: EffectType.BUFF,
    stacks: initialStacks,
    target: target,  // 전달받은 target 사용
  );

  @override
  void tick(double deltaTimeMs) {
    // 시간 경과에 따른 처리 없음 (자동 스택 감소 없음)
  }

  @override
  bool isExpired() => stacks <= 0;  // 스택이 0이면 효과 소멸

  @override
  void onEvent(GameEvent event) {
    super.onEvent(event);
    
    switch (event.type) {
      case GameEventType.EFFECT_APPLIED:
        // 디버프가 적용될 때만 처리
        final StatusEffect? effect = event.data['effect'];
        // effect가 null이 아니고 디버프인 경우에만 처리
        if (effect != null && effect.type == EffectType.DEBUFF) {
          final int originalStacks = event.data['stacks'] ?? 0;
          
          if (originalStacks > 0 && stacks > 0) {
            // 저항할 수 있는 스택 수 계산 (저항 스택과 디버프 스택 중 작은 값)
            final int resistedStacks = math.min(stacks, originalStacks);
            
            // 저항 스택 소모 (저항한 만큼 차감)
            removeStacks(resistedStacks);
            
            // 실제 적용될 디버프 스택 수정 (저항한 만큼 차감)
            event.data['stacks'] = originalStacks - resistedStacks;
            
            // 저항 효과 발동 이벤트 발생
            eventManager.dispatchEvent(GameEvent(
              type: GameEventType.EFFECT_STACK_CHANGED,
              data: {
                'effect': this,
                'oldStack': stacks + resistedStacks,
                'newStack': stacks,
                'resistedDebuff': effect.id,  // effect는 이미 null이 아님이 확인됨
                'resistedAmount': resistedStacks,
              }
            ));

            // 스택이 0이 되었는지 확인하고 효과 제거
            if (isExpired()) {
              eventManager.dispatchEvent(GameEvent(
                type: GameEventType.EFFECT_REMOVED,
                data: {'effect': this}
              ));
            }
          }
        }
        break;
      case GameEventType.TICK:
      case GameEventType.EFFECT_DURATION:
      case GameEventType.DAMAGE_DEALT:
      case GameEventType.DAMAGE_TAKEN:
      case GameEventType.HEAL:
      case GameEventType.CRITICAL_HIT:
      case GameEventType.EFFECT_REMOVED:
      case GameEventType.EFFECT_STACK_CHANGED:
      case GameEventType.MANA_CONSUME:
      case GameEventType.MANA_GAIN:
      case GameEventType.ITEM_USE:
      case GameEventType.ITEM_COOLDOWN:
      case GameEventType.ADD_ITEM:
      case GameEventType.REMOVE_ITEM:
      case GameEventType.CHANGE_STAT:
      case GameEventType.SET_FLAG:
      case GameEventType.CHANGE_SCENE:
        // 저항 효과와 관련 없는 이벤트들은 무시
        break;
      case GameEventType.STAMINA_CONSUMED:
      case GameEventType.STAMINA_RECOVERED:
        break;
      case GameEventType.WEAPON_QUEUED:
      case GameEventType.WEAPON_AUTO_USED:
      case GameEventType.WEAPON_CANCELLED:
        break;
      default:
        break;
    }
  }
} 

/// 방어 효과 - 수정된 버전
class DefenseEffect extends StatusEffect {
  DefenseEffect({
    required CombatEntity target,  // target을 필수 매개변수로 추가
    int initialStacks = 0,
  }) : super(
    id: 'defense',
    name: '방어',
    type: EffectType.BUFF,
    stacks: initialStacks,
    target: target,  // 전달받은 target 사용
  );

  @override
  void tick(double deltaTimeMs) {
    // 시간 경과에 따른 스택 감소 없음
  }

  @override
  bool isExpired() => stacks <= 0;  // 스택이 0이면 효과 소멸

  @override
  void onEvent(GameEvent event) {
    super.onEvent(event);
    
    switch (event.type) {
      case GameEventType.DAMAGE_TAKEN:
        if (event.data['target'] == target) {
          final int incomingDamage = event.data['damage'] as int;
          final bool bypassDefense = event.data['bypassDefense'] as bool? ?? false;
          final bool isTrueDamage = event.data['isTrueDamage'] as bool? ?? false;  // 🔥 추가!
          
          // bypassDefense 또는 isTrueDamage가 true인 경우 방어 효과를 적용하지 않음
          if (!bypassDefense && !isTrueDamage && incomingDamage > 0 && stacks > 0) {  // 🔥 수정!
            final int absorbedDamage = math.min(stacks, incomingDamage);
            removeStacks(absorbedDamage);
            final int remainingDamage = incomingDamage - absorbedDamage;
            
            // 데미지 이벤트 수정
            event.data['damage'] = remainingDamage;
            
            // 방어 효과 발동 이벤트 발생
            eventManager.dispatchEvent(GameEvent(
              type: GameEventType.EFFECT_STACK_CHANGED,
              data: {
                'effect': this,
                'oldStack': stacks + absorbedDamage,
                'newStack': stacks,
                'absorbed': absorbedDamage,
                'wasBlocked': true,
              }
            ));
          }
        }
        break;
      case GameEventType.EFFECT_STACK_CHANGED:
        if (stacks <= 0) {
          // 스택이 0이 되면 효과 제거 이벤트 발생
          eventManager.dispatchEvent(GameEvent(
            type: GameEventType.EFFECT_REMOVED,
            data: {'effect': this}
          ));
        }
        break;
      case GameEventType.TICK:
      case GameEventType.EFFECT_DURATION:
      case GameEventType.DAMAGE_DEALT:
      case GameEventType.HEAL:
      case GameEventType.CRITICAL_HIT:
      case GameEventType.EFFECT_APPLIED:
      case GameEventType.EFFECT_REMOVED:
      case GameEventType.MANA_CONSUME:
      case GameEventType.MANA_GAIN:
      case GameEventType.ITEM_USE:
      case GameEventType.ITEM_COOLDOWN:
      case GameEventType.ADD_ITEM:
      case GameEventType.REMOVE_ITEM:
      case GameEventType.CHANGE_STAT:
      case GameEventType.SET_FLAG:
      case GameEventType.CHANGE_SCENE:
        // 다른 이벤트들은 무시
        break;
      case GameEventType.STAMINA_CONSUMED:
      case GameEventType.STAMINA_RECOVERED:
        break;
      case GameEventType.WEAPON_QUEUED:
      case GameEventType.WEAPON_AUTO_USED:
      case GameEventType.WEAPON_CANCELLED:
        break;
      default:
        break;
    }
  }
} 

/// 중독 효과 - 2초마다 스택당 1의 피해를 주는 디버프
class PoisonEffect extends StatusEffect {
  double _damageTimer = 0;
  static const double DAMAGE_INTERVAL = 2000.0;  // 2초(2000ms)마다 데미지

  PoisonEffect({
    required CombatEntity target,
    int initialStacks = 0,
  }) : super(
    id: 'poison',
    name: '중독',
    type: EffectType.DEBUFF,
    stacks: initialStacks,
    target: target,
  );

  @override
  void tick(double deltaTimeMs) {
    _damageTimer += deltaTimeMs;
    if (_damageTimer >= DAMAGE_INTERVAL) {
      final damage = stacks;
      // target.takeDamage(damage);  // 기존 코드, 삭제 금지
      final payload = DamagePayload(
        source: target, // 혹은 상태이상을 건 주체
        target: target,
        baseDamage: 5 * stacks,
        sourceType: DamageSourceType.poison,
        isDot: true,
        ignoresDefense: false,
        originEffectId: 'poison',
      );
      applyDamage(payload);
      _damageTimer -= DAMAGE_INTERVAL;
    }
  }

  @override
  bool isExpired() => stacks <= 0;  // 스택이 0이면 효과 소멸

  @override
  void onEvent(GameEvent event) {
    super.onEvent(event);
    
    switch (event.type) {
      case GameEventType.EFFECT_STACK_CHANGED:
        if (stacks <= 0) {
          // 스택이 0이 되면 효과 제거 이벤트 발생
          eventManager.dispatchEvent(GameEvent(
            type: GameEventType.EFFECT_REMOVED,
            data: {'effect': this}
          ));
        }
        break;
      case GameEventType.TICK:
        // tick 메서드에서 처리됨
        break;
      case GameEventType.EFFECT_DURATION:
      case GameEventType.DAMAGE_DEALT:
      case GameEventType.DAMAGE_TAKEN:
      case GameEventType.HEAL:
      case GameEventType.CRITICAL_HIT:
      case GameEventType.EFFECT_APPLIED:
      case GameEventType.EFFECT_REMOVED:
      case GameEventType.MANA_CONSUME:
      case GameEventType.MANA_GAIN:
      case GameEventType.ITEM_USE:
      case GameEventType.ITEM_COOLDOWN:
      case GameEventType.ADD_ITEM:
      case GameEventType.REMOVE_ITEM:
      case GameEventType.CHANGE_STAT:
      case GameEventType.SET_FLAG:
      case GameEventType.CHANGE_SCENE:
        // 중독 효과와 관련 없는 이벤트들은 무시
        break;
      case GameEventType.STAMINA_CONSUMED:
      case GameEventType.STAMINA_RECOVERED:
        break;
      case GameEventType.WEAPON_QUEUED:
      case GameEventType.WEAPON_AUTO_USED:
      case GameEventType.WEAPON_CANCELLED:
        break;
      default:
        break;
    }
  }

  @override
  int getMaxStacks() => 2147483647;  // Int32 최대값 (실질적으로 무제한)
} 

/// 가속 효과 - 쿨타임 감소 속도를 증가시키는 버프
class HasteEffect extends StatusEffect {
  /// k = 1% per stack (shared formula constant with FrostEffect)
  static const double k = 0.01;

  HasteEffect({
    required CombatEntity target,
    int initialStacks = 0,
  }) : super(
    id: 'haste',
    name: '가속',
    type: EffectType.BUFF,
    stacks: initialStacks,
    target: target,
  );

  @override
  void tick(double deltaTimeMs) {
    // 시간 경과에 따른 자동 스택 감소 없음
  }

  /// Returns raw haste factor: 1 + k * stacks
  /// Used as numerator in finalTickRate = E * (hasteFactor / frostFactor)
  /// Example: 50 stacks => 1.5 (50% faster cooldown)
  double getCooldownModifier() {
    return 1.0 + (k * stacks);
  }

  @override
  bool isExpired() => stacks <= 0;

  @override
  int getMaxStacks() => 2147483647;  // Int32 최대값 (실질적으로 무제한)
}


/// 동상 효과 ­― 쿨다운 감소 속도를 늦추는 디버프
class FrostEffect extends StatusEffect {
  /// k = 1% per stack (shared formula constant with HasteEffect)
  static const double k = 0.01;

  FrostEffect({
    required CombatEntity target,
    int initialStacks = 0,
  }) : super(
    id: 'frost',
    name: '동상',
    type: EffectType.DEBUFF,
    stacks: initialStacks,
    target: target,
  );

  @override
  void tick(double deltaTimeMs) {
    // 시간 경과에 따른 자동 스택 감소 없음
  }

  /// Returns raw frost factor: 1 + k * stacks
  /// Used as denominator in finalTickRate = E * (hasteFactor / frostFactor)
  /// Brawl-style: division ensures cooldown never stops (frostFactor >= 1.0)
  /// Example: 50 stacks => 1.5 => tickRate divided by 1.5 (33% slower cooldown)
  double getCooldownModifier() {
    return 1.0 + (k * stacks);
  }

  @override
  int getMaxStacks() => 2147483647;  // Int32 최대값 (실질적으로 무제한)

  @override
  bool isExpired() => stacks <= 0;
}

/// 과거 이름과의 호환성
typedef FreezeEffect = FrostEffect; 

/// 실명 효과 - 명중률, 치명타 확률, 치명타 데미지를 감소시키는 디버프
class BlindEffect extends StatusEffect {
  BlindEffect({
    required CombatEntity target,
    int initialStacks = 0,
  }) : super(
          id: 'blind',
          name: '실명',
          type: EffectType.DEBUFF,
          stacks: initialStacks,
          target: target,
        );

  @override
  double modifyCritChance(double base) {
    return (base - stacks * 0.01).clamp(0.0, 1.0);
  }

  @override
  double modifyCritMultiplier(double base) {
    return (base - stacks * 0.01).clamp(1.0, double.infinity);
  }

  @override
  CombatStats getEffectModifiers() {
    // 명중률은 최소 10%까지만 감소 (-90%가 최대 감소)
    final accuracyReduction = (stacks * 3).clamp(0, 90); // 최대 90% 감소
    return CombatStats(
      accuracy: -accuracyReduction,
    );
  }

  @override
  bool isExpired() => stacks <= 0;
} 

/// 약화(Weakness) 효과 - 스택당 무기 공격력 -1을 제공하는 디버프
class WeaknessEffect extends StatusEffect {
  WeaknessEffect({
    required CombatEntity target,
    int initialStacks = 0,
  }) : super(
    id: 'weak',
    name: '약화',
    type: EffectType.DEBUFF,
    stacks: initialStacks,
    target: target,
  );

  @override
  CombatStats getEffectModifiers() {
    // 스택당 무기 공격력 -1 (최소 0까지)
    return CombatStats(attackPower: -stacks);
  }

  @override
  void tick(double deltaTimeMs) {
    // 시간 경과에 따라 스택이 줄어들지 않음
  }

  @override
  bool isExpired() => stacks <= 0;
} 

class CleanseEffect extends StatusEffect {
  CleanseEffect({
    required CombatEntity target,
    int initialStacks = 1,
  }) : super(
    id: 'cleanse',
    name: '정화',
    type: EffectType.BUFF,
    stacks: initialStacks,
    target: target,
  );

  @override
  void onApply() {
    final random = math.Random();
    int stacksToRemove = stacks;

    // 현재 적용된 디버프만 추출 (스택이 1 이상인 것만)
    List<StatusEffect> debuffs = target.statusEffects.values
        .where((e) => e.type == EffectType.DEBUFF && e.stacks > 0 && !e.isExpired())
        .toList();

    for (int i = 0; i < stacksToRemove; i++) {
      if (debuffs.isEmpty) break;
      // 랜덤으로 하나 선택
      final idx = random.nextInt(debuffs.length);
      final debuff = debuffs[idx];
      debuff.removeStacks(1);

      // 만약 해당 디버프가 모두 사라졌으면 리스트에서 제거
      if (debuff.isExpired()) {
        debuffs.removeAt(idx);
      }
      // (여기서 피드백/이펙트/로그 등 추가 가능)
    }

    // 정화 효과는 즉시 소멸
    stacks = 0;
  }

  @override
  void tick(double deltaTimeMs) {
    // 즉발 효과이므로 아무 동작도 하지 않음
  }

  @override
  bool isExpired() => true; // 항상 즉시 소멸
} 

// ────✅ DamageSourceType 열거형(누락 상수 추가 + 중복 없게 재정렬) ────
enum DamageSourceType {
  physical,   // 물리
  magical,    // 마법
  dot,        // DoT(공통)
  burn,       // 화상
  poison,     // 중독
  freeze,     // 빙결
  pet,        // 펫
  trueDamage, // 방어 무시 고정 피해
  other,      // 기타
}
// ──────────────────────────────────────────

class DamagePayload {
  final CombatEntity source;         // 피해를 준 주체
  final CombatEntity target;         // 피해를 받는 대상
  final int baseDamage;              // 방어력 적용 전 순수 피해량
  final DamageSourceType sourceType; // 물리, 마법, 지속 등
  final bool isDot;                  // 지속피해 여부 (true: 화상/중독 등)
  final bool ignoresDefense;         // 방어 무시 여부
  final String? originEffectId;      // 어떤 스킬/효과/상태이상으로 발생했는지 추적

  DamagePayload({
    required this.source,
    required this.target,
    required this.baseDamage,
    required this.sourceType,
    this.isDot = false,
    this.ignoresDefense = false,
    this.originEffectId,
  });
} 

void applyDamage(DamagePayload payload) {
  if (payload.baseDamage <= 0) return;
  
  // 방어 무시 여부에 따라 피해 적용
  final isTrueDamage = payload.ignoresDefense;
  payload.target.takeDamage(
    payload.baseDamage, 
    isTrueDamage: isTrueDamage,
    isDot: payload.isDot,  // DoT 여부 전달 (고정 데미지 감소 적용 여부 결정)
  );
  
  // 디버그 로그 (DoT의 경우 과도한 로그 방지를 위해 주석 처리 가능)
  // print('[applyDamage] ${payload.target}에게 ${payload.baseDamage} 피해 (방어 무시: $isTrueDamage, 타입: ${payload.sourceType})');
} 