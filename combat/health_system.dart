import 'combat_entity.dart';
import 'dart:async';

// 새 이벤트 시스템 import 추가
import '../core/state/combat_events.dart';

/// 최대체력 증가 효과
class MaxHealthIncreaseEffect {
  final String id;
  final String name;
  final int amount;              // 증가량
  final String source;           // 효과 소스
  final Duration? duration;      // 지속시간 (null이면 영구)
  final Map<String, dynamic> conditions; // 발동 조건
  
  MaxHealthIncreaseEffect({
    required this.id,
    required this.name,
    required this.amount,
    required this.source,
    this.duration,
    this.conditions = const {},
  });
}

abstract class Buff {
  String get id;
  String get name;
  void onApply();
  void onRemove();
}

class AllOutAttackBuff implements Buff {
  final String id;
  final String name = "맹공";
  int stack;
  final int weaponAttackPower; // 전투 시작 시 고정
  final double ratio; // 예: 1.0이면 스택당 +1, 0.5면 스택당 +0.5
  final void Function(int) onAttackPowerChanged; // 공격력 변화 콜백

  AllOutAttackBuff({
    required this.id,
    required this.stack,
    required this.weaponAttackPower,
    this.ratio = 1.0,
    required this.onAttackPowerChanged,
  });

  int get bonusAttack => (stack * weaponAttackPower * ratio).toInt();

  void addStack(int amount) {
    stack += amount;
    if (stack < 0) stack = 0;
    onAttackPowerChanged(bonusAttack);
    if (stack == 0) {
      onRemove();
    }
  }

  void removeStack(int amount) {
    addStack(-amount);
  }

  @override
  void onApply() {
    onAttackPowerChanged(bonusAttack);
  }

  @override
  void onRemove() {
    onAttackPowerChanged(0);
    // 버프 관리 시스템에서 이 버프를 제거해야 함
  }
}

class WeaknessDebuff implements Buff {
  final String id;
  final String name = "약화";
  int stack;
  final int weaponAttackPower; // 전투 시작 시 고정
  final double ratio; // 예: 1.0이면 스택당 -1, 0.5면 스택당 -0.5
  final void Function(int) onAttackPowerChanged; // 공격력 변화 콜백

  WeaknessDebuff({
    required this.id,
    required this.stack,
    required this.weaponAttackPower,
    this.ratio = 1.0,
    required this.onAttackPowerChanged,
  });

  int get penaltyAttack => (stack * weaponAttackPower * ratio).toInt();

  void addStack(int amount) {
    stack += amount;
    if (stack < 0) stack = 0;
    onAttackPowerChanged(-penaltyAttack); // 음수로 적용
    if (stack == 0) {
      onRemove();
    }
  }

  void removeStack(int amount) {
    addStack(-amount);
  }

  void onApply() {
    onAttackPowerChanged(-penaltyAttack);
  }

  void onRemove() {
    onAttackPowerChanged(0);
    // 버프 관리 시스템에서 이 디버프를 제거해야 함
  }
}

/// 체력 관리 시스템
mixin HealthSystem on CombatEntity {
  final List<MaxHealthIncreaseEffect> _activeHealthEffects = [];
  
  /// 최대체력 증가 적용
  void increaseMaxHealth(int amount, String source, {
    String? effectId,
    Duration? duration,
    Map<String, dynamic> data = const {},
  }) {
    if (amount <= 0) return;
    
    final oldMaxHealth = maxHealth;
    final oldCurrentHealth = currentHealth;
    final wasFullHealth = (currentHealth == maxHealth);
    
    // 효과 추가 (영구 효과는 stats에 직접 적용, 임시 효과는 리스트에 추가)
    if (duration == null) {
      // 영구 효과 - stats에 직접 적용
      stats.modifyMaxHealth(amount);
    } else {
      // 임시 효과 - 효과 리스트에 추가
      final effect = MaxHealthIncreaseEffect(
        id: effectId ?? 'temp_health_${DateTime.now().millisecondsSinceEpoch}',
        name: source,
        amount: amount,
        source: source,
        duration: duration,
      );
      _activeHealthEffects.add(effect);
      
      // 타이머 설정하여 지속시간 후 제거
      Timer(duration, () => _removeHealthEffect(effect.id));
    }
    
    final newMaxHealth = maxHealth;
    int newCurrentHealth = currentHealth;
    
    // 풀피였다면 현재체력도 함께 증가
    if (wasFullHealth) {
      newCurrentHealth = newMaxHealth;
      stats.currentHealth = newCurrentHealth;
    }
    
    // 새 이벤트 시스템 사용
    dispatchEvent(HealthChangedEvent(
      healthEventType: HealthEventType.maxHealthIncreased,
      amount: amount,
      oldMaxHealth: oldMaxHealth,
      newMaxHealth: newMaxHealth,
      oldCurrentHealth: oldCurrentHealth,
      newCurrentHealth: newCurrentHealth,
      source: source,
      entity: this,
      data: data,
    ));
    
    print('🔋 최대체력 증가! +$amount ($source)');
    print('   체력: $newCurrentHealth/$newMaxHealth ${wasFullHealth ? "(풀피 보너스!)" : ""}');
  }
  
  /// 최대체력 감소 적용
  void decreaseMaxHealth(int amount, String source, {
    Map<String, dynamic> data = const {},
  }) {
    if (amount <= 0) return;
    
    final oldMaxHealth = maxHealth;
    final oldCurrentHealth = currentHealth;
    
    // 최대체력 감소
    stats.modifyMaxHealth(-amount);
    
    final newMaxHealth = maxHealth;
    int newCurrentHealth = currentHealth;
    
    // 현재체력이 새로운 최대체력을 초과하면 조정
    if (currentHealth > newMaxHealth) {
      newCurrentHealth = newMaxHealth;
      stats.currentHealth = newCurrentHealth;
    }
    
    // 새 이벤트 시스템 사용
    dispatchEvent(HealthChangedEvent(
      healthEventType: HealthEventType.maxHealthDecreased,
      amount: amount,
      oldMaxHealth: oldMaxHealth,
      newMaxHealth: newMaxHealth,
      oldCurrentHealth: oldCurrentHealth,
      newCurrentHealth: newCurrentHealth,
      source: source,
      entity: this,
      data: data,
    ));
    
    print('💔 최대체력 감소! -$amount ($source)');
    print('   체력: $newCurrentHealth/$newMaxHealth');
  }
  
  /// 임시 체력 효과 제거
  void _removeHealthEffect(String effectId) {
    final effect = _activeHealthEffects.where((e) => e.id == effectId).firstOrNull;
    if (effect == null) return;
    
    _activeHealthEffects.removeWhere((e) => e.id == effectId);
    decreaseMaxHealth(effect.amount, '${effect.source} 효과 종료');
  }
  
  /// 현재 활성화된 임시 체력 효과들의 총합
  int get temporaryMaxHealthBonus {
    return _activeHealthEffects.fold(0, (total, effect) => total + effect.amount);
  }
  
  /// 전투 시작 시 아이템 효과 적용
  void applyCombatStartEffects() {
    print('⚔️ 전투 시작! 아이템 효과 적용 중...');
    
    // 모든 아이템의 최대체력 보너스 적용
    for (final item in items) {
      final healthBonus = item.stats.maxHealth;
      if (healthBonus > 0) {
        increaseMaxHealth(
          healthBonus, 
          item.name,
          data: {'itemId': item.id, 'combatStart': true},
        );
      }
    }
    
    // 전투 시작 이벤트
    dispatchEvent(HealthChangedEvent(
      healthEventType: HealthEventType.combatStarted,
      amount: 0,
      oldMaxHealth: maxHealth,
      newMaxHealth: maxHealth,
      oldCurrentHealth: currentHealth,
      newCurrentHealth: currentHealth,
      source: 'combat_start',
      entity: this,
    ));
  }
} 