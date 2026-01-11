import 'dart:math' as math;
import 'dart:async';
import 'stats.dart';
import 'effect_type.dart';
import 'status_effect.dart';
import 'combat_entity.dart';
import 'item.dart';
import 'combat_rng.dart';  // 시드 기반 RNG
import '../inventory/inventory_system.dart';

class Character extends CombatEntity {
  final String name;
  // statusEffects와 관련 메서드들은 CombatEntity로 이동했으므로 제거
  List<Item> items = const [];

  final List<Weapon> weapons = []; // 보유 무기 목록

  /// 인컴버런스(무게 초과)로 인한 쿨다운 진행 속도 배율.
  /// - 기본값 1.0 (패널티 없음)
  /// - 0.8 이면 쿨다운이 20% 느리게 감소(= 쿨다운 +25% 체감)처럼 동작
  double cooldownTickRateMultiplier = 1.0;
  
  /// 고정 데미지 감소 (피격 시 받는 데미지 감소)
  /// - 기본값 0 (감소 없음)
  /// - 무기/펫 공격에만 적용 (DoT/상태 효과 피해는 감소 불가)
  /// - 여러 아이템 장착 시 중첩됨 (예: 방패 3개 = 3 감소)
  int flatDamageReduction = 0;
  
  // 인벤토리 시스템 (전투 화면 시각화용)
  late final InventorySystem inventorySystem;

  /// 무기 추가
  void addWeapon(Weapon weapon) {
    if (!weapons.contains(weapon)) {
      weapons.add(weapon);
    }
  }

  /// 무기 제거
  void removeWeapon(Weapon weapon) {
    weapons.remove(weapon);
    cancelWeaponUsage(weapon); // 대기 중이던 무기도 취소
  }

  /// 사용 가능한 무기 목록 (쿨타임 순서)
  List<Weapon> get availableWeapons {
    final available = weapons.where((w) => w.isReady).toList();
    available.sort((a, b) => a.remainingCooldown.compareTo(b.remainingCooldown));
    return available;
  }

  /// 모든 사용 가능한 무기를 큐에 추가
  void queueAllWeapons({CombatEntity? target}) {
    final actualTarget = target ?? this;
    for (final weapon in availableWeapons) {
      tryUseWeapon(weapon, actualTarget);
    }
  }

  Character({
    required this.name,
    required super.stats,
    super.items,
    int inventoryWidth = 9,
    int inventoryHeight = 6,
  }) {
    // 인벤토리 시스템 초기화
    inventorySystem = InventorySystem(
      width: inventoryWidth,
      height: inventoryHeight,
    );
  }

  @override
  void dispose() {
    super.dispose();
    // 추가적인 정리 작업이 필요한 경우 여기에 구현
  }

  @override
  void update(double deltaTimeMs) {
    super.update(deltaTimeMs);
    
    // ══════════════════════════════════════════════════════════════════════════
    // 쿨타임 진행 속도 계산 (v6.2 설계안)
    // ══════════════════════════════════════════════════════════════════════════
    // 
    // [공식]
    // finalTickRate = clamp(0.1, E × (hasteFactor / frostFactor), 3.0)
    // 
    // [구성 요소]
    // - E: 인컴버런스 계수 (cooldownTickRateMultiplier)
    //      Normal/Uncomfortable = 1.0, Danger = 0.8, Collapse = 0.6
    // - hasteFactor = 1 + 0.01 × hasteStacks (분자, 쿨타임 가속)
    // - frostFactor = max(1.0, 1 + 0.01 × frostStacks) (분모, 쿨타임 둔화)
    // 
    // [안전장치]
    // - frostFactor ≥ 1.0: 쿨타임이 0이 되는 것 방지 (Brawl-style)
    // - 0.1 ≤ finalTickRate ≤ 3.0: 극단적 상황 방지
    // 
    // [예시] (baseCooldown = 2s, E = 1.0):
    //   haste=50, frost=0  => tickRate=1.5  => time=2/1.5=1.333s
    //   haste=0,  frost=50 => tickRate=0.66 => time=2/0.66=3.0s
    //   haste=50, frost=50 => tickRate=1.0  => time=2.0s
    // With E=0.6 (Collapse), haste=0, frost=200:
    //   rawTickRate=0.6×(1/3)=0.2 => clamped=0.2 => time=10.0s
    // ══════════════════════════════════════════════════════════════════════════
    
    final encumbranceFactor = cooldownTickRateMultiplier;
    
    // Get haste factor: 1 + k * stacks (default 1.0 if no effect)
    final hasteEffect = statusEffects['haste'] as HasteEffect?;
    final hasteFactor = hasteEffect?.getCooldownModifier() ?? 1.0;
    
    // Get frost factor: 1 + k * stacks (default 1.0 if no effect)
    // Safety clamp: frostFactor >= 1.0 to ensure cooldown never stops
    final frostEffect = statusEffects['frost'] as FrostEffect?;
    final frostFactor = math.max(1.0, frostEffect?.getCooldownModifier() ?? 1.0);
    
    // Unified formula: E * (hasteFactor / frostFactor)
    final rawTickRate = encumbranceFactor * (hasteFactor / frostFactor);
    
    // v6.2: 안전장치 - finalTickRate를 [0.1, 3.0] 범위로 클램프
    // - 0.1 = 쿨타임 최대 10배까지만 느려짐 (사실상 행동 불가 방지)
    // - 3.0 = 쿨타임 최대 3배까지만 빨라짐 (극단적 Haste 방지)
    final finalTickRate = rawTickRate.clamp(0.1, 3.0);
    
    // 모든 무기의 쿨타임 업데이트 (pass pre-computed finalTickRate, no re-apply inside)
    for (final weapon in weapons) {
      weapon.updateCooldown(deltaTimeMs * finalTickRate);
    }
  }
}

/// 전투 엔진 - 플레이어와 적의 전투를 관리하고 업데이트
class CombatEngine {
  final Character player;
  final Character enemy;
  final int? randomSeed;  // 재현성을 위한 seed (디버그용)
  double _elapsed = 0;  // 경과 시간 (초)
  bool _running = false;
  double _overtimeElapsed = 0;  // 오버타임 경과 시간 (초)
  bool _overtimeStarted = false;
  
  /// 전투용 시드 기반 RNG
  /// 
  /// - randomSeed가 설정되면 재현 가능한 전투
  /// - randomSeed가 null이면 시간 기반 랜덤
  late final CombatRng _combatRng;
  
  static const double OVERTIME_START = 90.0;  // 90초 후 오버타임
  static const double OVERTIME_INTERVAL = 1.0;  // 1초마다 오버타임 피해

  CombatEngine({
    required this.player, 
    required this.enemy,
    this.randomSeed,
  }) {
    // 시드 기반 RNG 생성
    _combatRng = CombatRng(seed: randomSeed);
    
    // 플레이어와 적에게 동일한 RNG 주입 (재현성 보장)
    player.combatRng = _combatRng;
    enemy.combatRng = _combatRng;
  }
  
  /// 전투 RNG 접근자 (테스트/디버그용)
  CombatRng get combatRng => _combatRng;

  bool get isRunning => _running;
  double get elapsedSeconds => _elapsed;
  double get elapsedMs => _elapsed * 1000.0;  // 밀리초 단위 (UI 샘플링용)
  bool get isOvertimeActive => _overtimeStarted;
  
  /// 전투 시작
  void start() {
    _running = true;
    _elapsed = 0;
    _overtimeElapsed = 0;
    _overtimeStarted = false;
  }
  
  /// 전투 중지
  void stop() {
    _running = false;
  }

  /// 전투 업데이트 (매 프레임 호출)
  void update(double deltaMs) {
    if (!_running) return;

    // 경과 시간 업데이트
    _elapsed += deltaMs / 1000.0;

    // 플레이어와 적 업데이트 (상태 효과 틱, 쿨다운 감소, 스태미나 회복)
    player.update(deltaMs);
    enemy.update(deltaMs);
    
    // 플레이어와 적의 상태 효과 틱 처리
    _updateStatusEffects(player, deltaMs);
    _updateStatusEffects(enemy, deltaMs);
    
    // 무기 자동 사용 시도 (플레이어는 적 공격, 적은 플레이어 공격)
    player.queueAllWeapons(target: enemy);
    enemy.queueAllWeapons(target: player);

    // 오버타임 체크 (90초 경과)
    if (_elapsed >= OVERTIME_START) {
      if (!_overtimeStarted) {
        _overtimeStarted = true;
        print('[Combat] 오버타임 시작! 양측 모두에게 지속 피해 발생');
      }
      
      _overtimeElapsed += deltaMs / 1000.0;
      
      // 1초마다 오버타임 피해 적용
      if (_overtimeElapsed >= OVERTIME_INTERVAL) {
        final overtimeTicks = (_overtimeElapsed / OVERTIME_INTERVAL).floor();
        _overtimeElapsed -= overtimeTicks * OVERTIME_INTERVAL;
        
        // 오버타임 시간에 비례한 피해 (90초 후 1초당 1 데미지씩 증가)
        final overtimeDamage = ((_elapsed - OVERTIME_START) / OVERTIME_INTERVAL).floor();
        
        if (overtimeDamage > 0) {
          player.takeDamage(overtimeDamage);
          enemy.takeDamage(overtimeDamage);
          print('[Combat] 오버타임 피해: $overtimeDamage');
        }
      }
    }

    // 전투 종료 체크
    if (player.isDead || enemy.isDead) {
      stop();
    }
  }
  
  /// 상태 효과 틱 처리
  void _updateStatusEffects(Character character, double deltaMs) {
    final expiredEffects = <String>[];
    
    // 모든 상태 효과 업데이트
    for (final entry in character.statusEffects.entries) {
      final effect = entry.value;
      
      // 틱 실행
      effect.tick(deltaMs);
      
      // 만료된 효과 수집
      if (effect.isExpired()) {
        expiredEffects.add(entry.key);
      }
    }
    
    // 만료된 효과 제거
    for (final effectId in expiredEffects) {
      character.statusEffects.remove(effectId);
    }
  }
  
  /// 전투 상태 요약 반환
  Map<String, dynamic> getStatus() {
    return {
      'running': _running,
      'elapsed': _elapsed,
      'overtime': _overtimeStarted,
      'player': {
        'health': player.currentHealth,
        'stamina': player.currentStamina,
        'isDead': player.isDead,
        'statusEffects': player.statusEffects.keys.toList(),
      },
      'enemy': {
        'health': enemy.currentHealth,
        'stamina': enemy.currentStamina,
        'isDead': enemy.isDead,
        'statusEffects': enemy.statusEffects.keys.toList(),
      },
    };
  }
}
