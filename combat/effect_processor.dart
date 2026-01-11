import 'dart:math' as math;
import 'combat_entity.dart';
import 'status_effect.dart';
import 'item.dart';
import 'character.dart';
import '../inventory/inventory_item.dart';

/// 패시브 효과 추적 정보
class PassiveEffectInfo {
  final Map<String, dynamic> effectData;
  final InventoryItem sourceItem;
  final double interval; // 초 단위
  double _elapsedTime = 0.0;
  
  PassiveEffectInfo({
    required this.effectData,
    required this.sourceItem,
    required this.interval,
  });
  
  /// 시간 업데이트 및 트리거 여부 반환
  bool update(double deltaTimeMs) {
    _elapsedTime += deltaTimeMs / 1000.0; // ms를 초로 변환
    if (_elapsedTime >= interval) {
      _elapsedTime -= interval; // 다음 주기를 위해 초과분 유지
      return true;
    }
    return false;
  }
  
  void reset() {
    _elapsedTime = 0.0;
  }
}

/// 무기/아이템의 properties['effects']를 읽어서 전투 효과를 적용하는 프로세서
/// 
/// 확장 가능한 파이프라인 방식으로 구현:
/// - effect.type에 따라 적절한 StatusEffect 인스턴스 생성
/// - trigger 타입에 따라 처리:
///   - on_hit: 무기 공격 명중 시 (기본적으로 항상 적용, chance 필드로 확률 제어 가능)
///   - on_combat_start: 전투 시작 시 한 번 적용
///   - passive: 지속 효과 (interval 필드로 주기 지정, 초 단위)
/// - target에게 효과 적용
class EffectProcessor {
  static final math.Random _random = math.Random();
  
  /// 패시브 효과 추적 목록
  static final List<PassiveEffectInfo> _passiveEffects = [];
  
  /// 패시브 효과가 적용될 대상 (전투 시작 시 설정)
  static Character? _passiveTarget;
  
  /// 무기 공격 시 properties['effects']를 처리
  /// 
  /// [weapon] 사용된 무기 (InventoryItem에서 변환된 Weapon)
  /// [attacker] 공격자
  /// [target] 피격자
  /// [sourceItem] 원본 InventoryItem (properties 접근용, null 가능)
  static void processWeaponEffects({
    required Weapon weapon,
    required CombatEntity attacker,
    required CombatEntity target,
    InventoryItem? sourceItem,
  }) {
    // sourceItem이 없으면 효과 처리 불가
    if (sourceItem == null) return;
    
    final effects = sourceItem.properties['effects'] as List<dynamic>?;
    if (effects == null || effects.isEmpty) return;
    
    for (final effectData in effects) {
      if (effectData is! Map<String, dynamic>) continue;
      
      // trigger 확인: 'on_hit'인 경우만 처리
      final trigger = effectData['trigger'] as String?;
      if (trigger != 'on_hit') continue;
      
      // chance 필드 확인: 명시적으로 설정되어 있고 1.0보다 작으면 확률 판정
      // - chance가 없거나 1.0이면 항상 적용 (기본 동작)
      // - chance가 0.0~0.99 사이면 확률 판정 수행
      final chance = effectData['chance'];
      if (chance != null) {
        final chanceValue = (chance as num).toDouble();
        if (chanceValue < 1.0 && chanceValue > 0.0) {
          // 확률 판정 수행
          final roll = _random.nextDouble();
          if (roll > chanceValue) {
            // 확률 실패 - 효과 미적용
            continue;
          }
        }
        // chance가 1.0이거나 0.0 이하면 항상 적용 (또는 미적용)
        if (chanceValue <= 0.0) {
          continue; // 0% 확률이면 미적용
        }
      }
      
      // 효과 적용 (chance가 없거나 1.0이면 항상 적용, 확률 판정 통과 시 적용)
      _applyEffect(
        effectData: effectData,
        attacker: attacker,
        target: target,
        weapon: weapon,
      );
    }
  }
  
  /// 전투 시작 시 장착된 아이템의 on_combat_start 효과 처리
  /// 
  /// [items] 장착된 아이템 목록
  /// [owner] 아이템 소유자 (플레이어)
  static void processCombatStartEffects({
    required List<InventoryItem> items,
    required Character owner,
  }) {
    print('[EffectProcessor] 🎮 전투 시작 효과 처리 중... (${items.length}개 아이템)');
    
    // 패시브 효과 대상 설정
    _passiveTarget = owner;
    
    for (final item in items) {
      final effects = item.properties['effects'] as List<dynamic>?;
      if (effects == null || effects.isEmpty) continue;
      
      for (final effectData in effects) {
        if (effectData is! Map<String, dynamic>) continue;
        
        final trigger = effectData['trigger'] as String?;
        
        if (trigger == 'on_combat_start') {
          // 전투 시작 효과 즉시 적용
          _applyEffectToTarget(
            effectData: effectData,
            target: owner,
            sourceName: item.name,
          );
        } else if (trigger == 'passive') {
          // 패시브 효과 등록
          final interval = (effectData['interval'] as num?)?.toDouble() ?? 1.0;
          _passiveEffects.add(PassiveEffectInfo(
            effectData: effectData,
            sourceItem: item,
            interval: interval,
          ));
          print('[EffectProcessor] 📝 패시브 효과 등록: ${effectData['type']} (${interval}초마다)');
        }
      }
    }
    
    print('[EffectProcessor] ✅ 전투 시작 효과 처리 완료 (패시브 ${_passiveEffects.length}개 등록)');
  }
  
  /// 전투 틱마다 패시브 효과 처리
  /// 
  /// [deltaTimeMs] 경과 시간 (밀리초)
  static void processPassiveTick(double deltaTimeMs) {
    if (_passiveTarget == null || _passiveEffects.isEmpty) return;
    
    for (final passive in _passiveEffects) {
      if (passive.update(deltaTimeMs)) {
        // 패시브 효과 발동
        _applyEffectToTarget(
          effectData: passive.effectData,
          target: _passiveTarget!,
          sourceName: passive.sourceItem.name,
        );
      }
    }
  }
  
  /// 개별 효과를 특정 대상에게 적용
  /// 
  /// [effectData] 효과 데이터
  /// [target] 효과 적용 대상
  /// [sourceName] 효과 발생 소스 이름 (로그용)
  static void _applyEffectToTarget({
    required Map<String, dynamic> effectData,
    required Character target,
    required String sourceName,
  }) {
    final effectType = effectData['type'] as String?;
    if (effectType == null) return;
    
    final stack = (effectData['stack'] as num?)?.toInt() ?? 1;
    
    // 효과 타입에 따라 처리
    StatusEffect? statusEffect = _createStatusEffect(effectType, target, stack);
    
    if (statusEffect != null) {
      // 마나 효과는 특별 처리: 기존 효과가 있으면 스택 추가
      if (effectType.toLowerCase() == 'mana') {
        final existingMana = target.statusEffects['mana'] as ManaEffect?;
        if (existingMana != null) {
          existingMana.addStacks(stack);
          print('[EffectProcessor] $sourceName → ${target.name}에게 마나 $stack 스택 추가 (총 ${existingMana.stacks})');
          return;
        }
        // 새 마나 효과 생성 시 스택 설정
        statusEffect.stacks = stack;
      }
      
      // 저항 효과도 특별 처리: 기존 효과가 있으면 스택 추가
      if (effectType.toLowerCase() == 'resistance') {
        final existingResist = target.statusEffects['resistance'] as ResistanceEffect?;
        if (existingResist != null) {
          existingResist.addStacks(stack);
          print('[EffectProcessor] $sourceName → ${target.name}에게 저항 $stack 스택 추가 (총 ${existingResist.stacks})');
          return;
        }
      }
      
      // 효과 적용
      target.addStatusEffect(statusEffect);
      print('[EffectProcessor] $sourceName → ${target.name}에게 ${statusEffect.name} $stack 스택 부여');
    }
  }
  
  /// 효과 타입에 따라 StatusEffect 인스턴스 생성
  static StatusEffect? _createStatusEffect(String effectType, Character target, int stack) {
    switch (effectType.toLowerCase()) {
      // 디버프
      case 'bleeding':
      case 'bleed':
        return BleedingEffect(target: target, initialStacks: stack);
      case 'burn':
        return BurnEffect(target: target, initialStacks: stack);
      case 'poison':
        return PoisonEffect(target: target, initialStacks: stack);
      case 'frost':
      case 'freeze':
        return FrostEffect(target: target, initialStacks: stack);
      case 'blind':
        return BlindEffect(target: target, initialStacks: stack);
      case 'weak':
      case 'weakness':
        return WeaknessEffect(target: target, initialStacks: stack);
      
      // 버프
      case 'haste':
        return HasteEffect(target: target, initialStacks: stack);
      case 'regeneration':
      case 'regen':
        return RegenerationEffect(target: target, initialStacks: stack);
      case 'lifesteal':
        return LifestealEffect(target: target, initialStacks: stack);
      case 'luck':
        return LuckEffect(target: target, initialStacks: stack);
      case 'thorns':
        return ThornsEffect(target: target, initialStacks: stack);
      case 'defense':
        return DefenseEffect(target: target, initialStacks: stack);
      case 'resistance':
        return ResistanceEffect(target: target, initialStacks: stack);
      case 'mana':
        return ManaEffect(target: target);
      
      default:
        print('[EffectProcessor] Unknown effect type: $effectType');
        return null;
    }
  }
  
  /// 개별 효과 적용 (on_hit 트리거용, 무기 공격 시)
  static void _applyEffect({
    required Map<String, dynamic> effectData,
    required CombatEntity attacker,
    required CombatEntity target,
    required Weapon weapon,
  }) {
    final effectType = effectData['type'] as String?;
    if (effectType == null) return;
    
    final stack = (effectData['stack'] as num?)?.toInt() ?? 1;
    final effectTarget = effectData['target'] as String? ?? 'enemy';
    
    // target 결정: 'self'면 공격자, 'enemy'면 피격자
    final CombatEntity actualTarget;
    if (effectTarget == 'self') {
      actualTarget = attacker;
    } else {
      actualTarget = target;
    }
    
    // Character 타입 체크
    if (actualTarget is! Character) {
      print('[EffectProcessor] Warning: 효과는 Character에만 적용 가능');
      return;
    }
    
    // 효과 생성 및 적용
    StatusEffect? statusEffect = _createStatusEffect(effectType, actualTarget, stack);
    
    if (statusEffect != null) {
      // 마나/저항 효과 특별 처리
      if (effectType.toLowerCase() == 'mana') {
        final existingMana = actualTarget.statusEffects['mana'] as ManaEffect?;
        if (existingMana != null) {
          existingMana.addStacks(stack);
          print('[EffectProcessor] ${weapon.name} → ${actualTarget.name}에게 마나 $stack 스택 추가');
          return;
        }
        statusEffect.stacks = stack;
      }
      
      if (effectType.toLowerCase() == 'resistance') {
        final existingResist = actualTarget.statusEffects['resistance'] as ResistanceEffect?;
        if (existingResist != null) {
          existingResist.addStacks(stack);
          print('[EffectProcessor] ${weapon.name} → ${actualTarget.name}에게 저항 $stack 스택 추가');
          return;
        }
      }
      
      // 효과 적용
      actualTarget.addStatusEffect(statusEffect);
      print('[EffectProcessor] ${weapon.name} → ${actualTarget.name}에게 ${statusEffect.name} $stack 스택 부여');
    }
  }
  
  /// InventoryItem에서 Weapon으로 변환 시 원본 참조 보존을 위한 래퍼
  /// 
  /// Weapon 클래스에 sourceItem 필드를 추가하는 대신,
  /// 별도 맵으로 관리하는 방식
  static final Map<Weapon, InventoryItem> _weaponSourceMap = {};
  
  /// Weapon과 원본 InventoryItem 연결
  static void registerWeaponSource(Weapon weapon, InventoryItem sourceItem) {
    _weaponSourceMap[weapon] = sourceItem;
  }
  
  /// Weapon의 원본 InventoryItem 조회
  static InventoryItem? getWeaponSource(Weapon weapon) {
    return _weaponSourceMap[weapon];
  }
  
  /// 전투 종료 시 정리
  static void clear() {
    _weaponSourceMap.clear();
    _passiveEffects.clear();
    _passiveTarget = null;
  }
}

