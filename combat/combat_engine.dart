import 'dart:math';
import 'character.dart';
import 'stats.dart';
import 'effect_type.dart';
import 'status_effect.dart';
import 'combat_entity.dart';   // ← CombatEntity 사용을 위해 추가

abstract class CombatEngine {
  void processTurn(Character attacker, Character defender);
  void applyDamage(Character attacker, Character defender, int damage);
  void applyHealing(Character target, int amount);
  void applyStatusEffect(Character target, StatusEffect effect);
  void updateEffects(Character character, double deltaTimeMs);
}

class DefaultCombatEngine extends CombatEngine {
  @override
  void processTurn(Character attacker, Character defender) {
    // 기본 공격 로직
    final damage = calculateDamage(attacker, defender);
    applyDamage(attacker, defender, damage);
  }

  @override
  void applyDamage(Character attacker, Character defender, int damage) {
    // 데미지 적용 로직
    defender.takeDamage(damage);
  }

  @override
  void applyHealing(Character target, int amount) {
    // 힐링 적용 로직
    target.heal(amount);
  }

  @override
  void applyStatusEffect(Character target, StatusEffect effect) {
    // 상태 효과 적용 로직
    target.addStatusEffect(effect);
  }

  @override
  void updateEffects(Character character, double deltaTimeMs) {
    // 상태 효과 업데이트 로직 (Character.update 메서드 사용)
    character.update(deltaTimeMs);
  }

  int calculateDamage(Character attacker, Character defender) {
    // 공격력 계산 로직: 공격자의 공격력 사용
    return attacker.stats.attackPower;  // baseStats를 stats로 변경
  }
}

/// 피해 유형(출처) 구분용 enum
enum DamageSourceType {
  physical,   // 물리
  magical,    // 마법
  dot,        // 지속피해(화상, 중독 등)
  pet,        // 펫
  trueDamage, // 방어 무시 고정 피해
  other,      // 기타
}

/// 전투 시스템 내 일원화된 피해 정보 구조체
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

class CombatLogEntry {
  final String sourceName;
  final String targetName;
  final int amount;
  final DamageSourceType sourceType;
  final bool isDot;
  final String? origin;
  final int timestamp; // ms 단위

  CombatLogEntry({
    required this.sourceName,
    required this.targetName,
    required this.amount,
    required this.sourceType,
    required this.isDot,
    required this.origin,
    required this.timestamp,
  });
}

class CombatLog {
  static final List<CombatLogEntry> _entries = [];

  static void record(CombatLogEntry entry) {
    _entries.add(entry);
    // 필요시 콘솔 출력 등 추가 가능
    // print('[CombatLog] ${entry.sourceName} -> ${entry.targetName}: ${entry.amount}');
  }

  static List<CombatLogEntry> get entries => List.unmodifiable(_entries);
  
  /// 전투 로그 초기화
  static void clear() {
    _entries.clear();
  }
}

// All combat-related classes are now properly organized in their own files:
// - Character: lib/combat/character.dart
// - Item & Weapon: lib/combat/item.dart
// - StatusEffect: lib/combat/status_effect.dart
// - CombatEntity: lib/combat/combat_entity.dart
// - Stats: lib/combat/stats.dart 