import 'dart:async';
import 'stats.dart';
import 'item.dart';
import 'dart:math' as math;
import 'status_effect.dart';
import '../trait_system.dart';
import 'character.dart';
import 'combat_rng.dart';  // 시드 기반 RNG

// 새 이벤트 시스템 import 추가
import '../core/state/events.dart' show GEvent;
import '../core/state/combat_events.dart';

abstract class ItemEffect {
  const ItemEffect();
  void apply(CombatEntity user, CombatEntity target);
}

abstract class CombatEntity {
  static const double DEFAULT_STAMINA = 5.0;        // 기본 스태미나
  static const double BASE_STAMINA_REGEN = 1.0;     // 기본 초당 회복량
  
  final List<Item> items;
  final CombatStats stats;
  final Map<String, StatusEffect> statusEffects = {};  // 상태 효과 맵 추가

  /// 전투용 시드 기반 RNG (재현성 보장)
  /// 
  /// - CombatEngine에서 시드를 설정하면 동일한 전투 결과 재현 가능
  /// - 설정되지 않으면 null (Weapon에서 새 Random 사용, 레거시 호환)
  /// 
  /// 사용처:
  /// - 명중 판정
  /// - 크리티컬 판정
  /// - 데미지 범위 롤
  CombatRng? combatRng;

  /// (v6.2) 인컴버런스(무게 초과)로 인한 스태미나 회복 델타 (덧셈 방식)
  /// - 기본값 0.0 (패널티 없음)
  /// - Normal: 0, Uncomfortable: -0.1, Danger: -0.2, Collapse: -0.3
  /// - 전투 시작 시 InventorySystem 스냅샷에서 설정됨
  /// - actualRegen = max(0, baseRegen + staminaRecoveryDelta)
  double staminaRecoveryDelta = 0.0;
  
  /// (legacy compatibility) 인컴버런스로 인한 스태미나 회복 배율 (곱셈 방식)
  /// - 새 코드에서는 staminaRecoveryDelta 사용 권장
  /// - getter: 1.0 + staminaRecoveryDelta로 변환
  double get staminaRegenMultiplier => 1.0 + staminaRecoveryDelta;
  set staminaRegenMultiplier(double value) {
    // legacy 호환: multiplier를 delta로 변환
    // multiplier=0.9 → delta=-0.1
    staminaRecoveryDelta = value - 1.0;
  }

  double _maxStamina;      // 최대 스태미나
  double _currentStamina;  // 현재 스태미나
  double _staminaRegenRate;  // 현재 스태미나 회복률
  double _staminaRegenTimer = 0.0;

  final TraitSystem traitSystem = TraitSystem();

  // 새 이벤트 시스템을 위한 dispatcher
  void Function(GEvent)? _dispatcher;

  /* ────────────────✨ 우선순위 기반 무기 자동 사용 시스템 ✨─────────────── */
  final List<_WeaponQueueItem> _weaponQueue = []; // 우선순위 큐
  
  CombatEntity({
    required this.stats,
    double? maxStamina,
    double? staminaRegenRate,
    List<Item>? items,
  }) : _maxStamina = maxStamina ?? DEFAULT_STAMINA,
       _currentStamina = DEFAULT_STAMINA,
       _staminaRegenRate = staminaRegenRate ?? BASE_STAMINA_REGEN,
       items = items ?? const [];

  // Dispatcher 설정 메서드
  void setEventDispatcher(void Function(GEvent) dispatcher) {
    _dispatcher = dispatcher;
  }

  // 이벤트 디스패치 헬퍼 메서드 (protected - mixin에서 사용 가능)
  void dispatchEvent(GEvent event) {
    _dispatcher?.call(event);
  }

  // 최종 전투 스탯 계산 (아이템 효과 포함)
  CombatStats get combatStats {
    return items.fold(
      stats,  // 기본 스탯으로 시작
      (total, item) => total + item.stats,
    );
  }

  // 체력 관련 getter들
  int get currentHealth => stats.currentHealth;
  bool get isDead => currentHealth <= 0;

  double get currentStamina => _currentStamina;
  set currentStamina(double value) =>
      _currentStamina = value.clamp(0, maxStamina);

  // Getter/Setter
  double get maxStamina => _maxStamina;
  double get staminaRegenRate => _staminaRegenRate;

  // 스태미나 최대치 수정 메서드
  void modifyMaxStamina(double amount) {
    _maxStamina += amount;
    // 현재 스태미나가 새로운 최대치를 초과하지 않도록 조정
    if (_currentStamina > _maxStamina) {
      _currentStamina = _maxStamina;
    }
  }

  // 스태미나 회복률 수정 메서드
  void modifyStaminaRegenRate(double amount) {
    _staminaRegenRate += amount;
  }

  /// 무기 사용 시도 (스태미너 부족 시 우선순위 큐에 추가)
  bool tryUseWeapon(Weapon weapon, CombatEntity target) {
    // 쿨다운 체크
    if (weapon.remainingCooldown > 0) return false;
    
    // 스태미너가 충분한 경우 즉시 사용
    if (currentStamina >= weapon.staminaCost) {
      return weapon.use(this, target);
    }
    
    // 스태미너 부족 시 우선순위 큐에 추가 (중복 방지)
    final existingIndex = _weaponQueue.indexWhere((item) => item.weapon == weapon);
    if (existingIndex == -1) {
      final queueItem = _WeaponQueueItem(
        weapon: weapon,
        target: target,
        queuedTime: DateTime.now().millisecondsSinceEpoch.toDouble(),
      );
      
      _weaponQueue.add(queueItem);
      // 쿨타임 초기화 순서로 정렬 (먼저 초기화된 순서)
      _sortWeaponQueue();
      
      // 새 이벤트 시스템 사용 ✅
      dispatchEvent(WeaponQueuedEvent(
        weaponName: weapon.name,
        user: this,
        target: target,
        currentStamina: currentStamina,
        requiredStamina: weapon.staminaCost,
      ));
    }
    return false;
  }

  /// 무기 큐 정렬 (쿨타임 초기화 순서 우선)
  void _sortWeaponQueue() {
    _weaponQueue.sort((a, b) {
      // 1. 쿨타임이 끝난 무기 우선
      final aReady = a.weapon.remainingCooldown <= 0;
      final bReady = b.weapon.remainingCooldown <= 0;
      
      if (aReady && !bReady) return -1;
      if (!aReady && bReady) return 1;
      
      // 2. 둘 다 준비된 경우 - 먼저 큐에 들어온 순서
      if (aReady && bReady) {
        return a.queuedTime.compareTo(b.queuedTime);
      }
      
      // 3. 둘 다 쿨타임 중인 경우 - 먼저 끝나는 순서
      return a.weapon.remainingCooldown.compareTo(b.weapon.remainingCooldown);
    });
  }

  // 스태미나 자연 회복 업데이트 (v6.2: 덧셈 방식)
  void update(double deltaTimeMs) {
    // 스태미나 자연 회복 (회복률 적용)
    _staminaRegenTimer += deltaTimeMs;
    if (_staminaRegenTimer >= 1000.0) { // 1초마다
      int regenTicks = (_staminaRegenTimer / 1000.0).floor();
      _staminaRegenTimer -= regenTicks * 1000.0;
      
      // v6.2: 덧셈 방식으로 회복률 계산
      // actualRegen = max(0, baseRegen + staminaRecoveryDelta)
      // - Normal: 1.0 + 0 = 1.0/s
      // - Uncomfortable: 1.0 + (-0.1) = 0.9/s
      // - Danger: 1.0 + (-0.2) = 0.8/s
      // - Collapse: 1.0 + (-0.3) = 0.7/s
      final adjustedRate = math.max(0.0, _staminaRegenRate + staminaRecoveryDelta);
      recoverStamina(regenTicks * adjustedRate);
    }
    
    // 쿨타임이 변경되었으므로 큐 재정렬
    if (_weaponQueue.isNotEmpty) {
      _sortWeaponQueue();
      
      // 쿨타임이 끝난 무기가 있다면 자동 사용 시도
      _processPendingWeapons();
    }
  }

  // 스태미나 회복 메서드
  void recoverStamina(double amount) {
    final oldStamina = _currentStamina;
    _currentStamina = (_currentStamina + amount).clamp(0, _maxStamina);
    final actualRecovered = _currentStamina - oldStamina;
    
    if (actualRecovered > 0) {
      // 새 이벤트 시스템 사용 ✅
      dispatchEvent(StaminaRecoveredEvent(
        entity: this,
        amount: actualRecovered,
        currentStamina: _currentStamina,
      ));
    }
  }

  /// 대기 중인 무기들을 우선순위에 따라 자동 사용
  void _processPendingWeapons() {
    if (_weaponQueue.isEmpty) return;
    
    // 큐 재정렬 (쿨타임 상태 변경을 반영)
    _sortWeaponQueue();
    
    final itemsToRemove = <_WeaponQueueItem>[];
    
    for (final item in _weaponQueue) {
      final weapon = item.weapon;
      
      // 쿨다운이 끝나고 스태미너가 충분한 무기만 사용
      if (weapon.remainingCooldown <= 0 && currentStamina >= weapon.staminaCost) {
        final success = weapon.use(this, item.target);
        
        if (success) {
          itemsToRemove.add(item);
          
          // 새 이벤트 시스템 사용 ✅
          dispatchEvent(WeaponAutoUsedEvent(
            weaponName: weapon.name,
            user: this,
            target: item.target,
          ));
          
          // 스태미너가 부족해지면 중단
          if (currentStamina < weapon.staminaCost) break;
        }
      } else {
        // 첫 번째 무기도 사용할 수 없다면 중단 (우선순위 순서이므로)
        break;
      }
    }
    
    // 사용된 무기들을 큐에서 제거
    for (final item in itemsToRemove) {
      _weaponQueue.remove(item);
    }
  }

  /* ────────────────✨ 스태미나 소비 메서드 추가 ✨─────────────── */
  /// 스태미나를 소비하고 성공 여부를 반환
  bool consumeStamina(double amount) {
    if (_currentStamina < amount) return false;

    final oldStamina = _currentStamina;
    _currentStamina -= amount;
    
    // 새 이벤트 시스템 사용 ✅
    dispatchEvent(StaminaConsumedEvent(
      entity: this,
      amount: amount,
      currentStamina: _currentStamina,
      source: 'weapon_use',
    ));
    
    return true;
  }

  /// 무기 사용 취소 (큐에서 제거)
  void cancelWeaponUsage(Weapon weapon) {
    final initialLen = _weaponQueue.length;
    _weaponQueue.removeWhere((item) => item.weapon == weapon);
    final removedCount = initialLen - _weaponQueue.length;

    if (removedCount > 0) {
      // 새 이벤트 시스템 사용 ✅
      dispatchEvent(WeaponCancelledEvent(
        weaponName: weapon.name,
        user: this,
        reason: 'manual_cancel',
      ));
    }
  }

  /// 대기 중인 무기 목록 반환 (우선순위 순서)
  List<Weapon> get pendingWeapons {
    _sortWeaponQueue();
    return _weaponQueue.map((item) => item.weapon).toList();
  }

  /// 무기 큐 상태 정보 반환
  List<Map<String, dynamic>> get weaponQueueStatus {
    _sortWeaponQueue();
    return _weaponQueue.map((item) => {
      'weapon': item.weapon,
      'target': item.target,
      'remainingCooldown': item.weapon.remainingCooldown,
      'requiredStamina': item.weapon.staminaCost,
      'queuedTime': item.queuedTime,
      'isReady': item.weapon.remainingCooldown <= 0,
    }).toList();
  }

  /// 데미지 처리
  /// 
  /// [isTrueDamage]: true면 방어율 무시
  /// [isDot]: true면 DoT(상태 효과) 피해 - 고정 데미지 감소 적용 안됨
  void takeDamage(int amount, {bool isTrueDamage = false, bool isDot = false}) {
    if (amount <= 0) return;
    
    int finalDamage;
    
    if (isTrueDamage) {
      // 고정 피해는 방어력 무시
      finalDamage = amount;
    } else {
      // 방어율 적용: 받는 피해 = 원본 피해 * (1 - 방어율)
      double defenseRate = stats.defenseRate.clamp(0.0, 0.75); // 최대 75% 제한
      double reducedDamage = amount * (1.0 - defenseRate);
      finalDamage = reducedDamage.round();  // 반올림
      
      // 최소 1의 데미지는 보장 (방어율이 높아도 최소 피해)
      finalDamage = math.max(1, finalDamage);
    }
    
    // 피격 시 고정 데미지 감소 적용 (무기/펫 공격에만 적용, DoT 제외)
    // - isDot == false: 무기/펫 공격
    // - isDot == true: 상태 효과(화상, 중독, 출혈 등) → 감소 적용 안됨
    if (!isDot && this is Character) {
      final character = this as Character;
      if (character.flatDamageReduction > 0) {
        finalDamage = math.max(1, finalDamage - character.flatDamageReduction);
      }
    }
    
    // 체력 감소
    int oldHealth = stats.currentHealth;
    stats.currentHealth = (stats.currentHealth - finalDamage).clamp(0, maxHealth);
    int actualDamage = oldHealth - stats.currentHealth;

    if (actualDamage > 0) {
      // 새 이벤트 시스템 사용 ✅
      dispatchEvent(DamageTakenEvent(
        entity: this,
        damage: actualDamage,
        source: isTrueDamage ? 'true_damage' : 'normal',
        rawDamage: amount,  // 원본 피해 (방어 적용 전)
        defenseReduced: amount - actualDamage,  // 방어로 막은 양
      ));
      
      traitSystem.onDamageTaken(this, actualDamage);
    }
  }

  /// 힐링 처리
  void heal(int amount) {
    if (amount <= 0) return;

    int oldHealth = stats.currentHealth;
    stats.currentHealth = (stats.currentHealth + amount).clamp(0, maxHealth);
    int actualHeal = stats.currentHealth - oldHealth;

    if (actualHeal > 0) {
      // 새 이벤트 시스템 사용 ✅
      dispatchEvent(HealEvent(
        entity: this,
        amount: actualHeal,
        source: 'heal',
      ));
    }
  }

  void useItem(Item item) {
    if (!items.contains(item)) {
      throw ArgumentError('Item not found in inventory');
    }
    item.use(this, this);  // 기본적으로 자신에게 사용
  }

  /// 상태 효과 추가
  void addStatusEffect(StatusEffect effect) {
    final existingEffect = statusEffects[effect.id];
    if (existingEffect != null) {
      existingEffect.addStacks(effect.stacks);
    } else {
      statusEffects[effect.id] = effect;
    }

    // 새 이벤트 시스템 사용 ✅
    dispatchEvent(EffectAppliedEvent(
      effect: effect,
      target: this,
      source: null,
    ));
  }

  /// 상태 효과 제거
  void removeStatusEffect(String effectId) {
    final effect = statusEffects.remove(effectId);
    if (effect != null) {
      // 새 이벤트 시스템 사용 ✅
      dispatchEvent(EffectRemovedEvent(
        effectId: effectId,
        target: this,
        amount: effect.stacks,
        effectType: effect.type.toString(),
      ));
    }
  }

  void dispose() {
    // 정리 작업이 필요한 경우 하위 클래스에서 구현
  }

  // 모든 장비 아이템의 치명타 확률 합산
  double get totalCriticalChance {
    double total = 0.0;
    for (final item in items) {
      if (item is EquipmentItem) {
        total += item.criticalChance;
      }
    }
    return total.clamp(0.0, 1.0);  // 0% ~ 100% 제한
  }

  // 모든 장비 아이템의 치명타 배율 합산
  double get totalCriticalMultiplier {
    double total = 1.0;  // 기본 100%부터 시작
    for (final item in items) {
      if (item is EquipmentItem && item.criticalMultiplier > 1.0) {
        total += (item.criticalMultiplier - 1.0);  // 추가 배율만 더함
      }
    }
    return total.clamp(1.0, 5.0);  // 100% ~ 500% 제한
  }

  // 치명타 확률 계산
  double get critChance {
    double base = totalCriticalChance;
    for (final effect in statusEffects.values) {
      base = effect.modifyCritChance(base);
    }
    return base;
  }

  // 치명타 배율 계산
  double get critMultiplier {
    double base = totalCriticalMultiplier;
    for (final effect in statusEffects.values) {
      base = effect.modifyCritMultiplier(base);
    }
    return base;
  }

  // 최대 체력 계산
  int get maxHealth {
    int base = combatStats.maxHealth;
    for (final effect in statusEffects.values) {
      base = effect.modifyMaxHealth(base);
    }
    return base;
  }
}

/// 무기 큐 아이템 (내부 사용)
class _WeaponQueueItem {
  final Weapon weapon;
  final CombatEntity target;
  final double queuedTime; // 큐에 추가된 시간

  _WeaponQueueItem({
    required this.weapon,
    required this.target,
    required this.queuedTime,
  });
} 