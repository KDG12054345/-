/// 인벤토리 시스템을 전투 시스템으로 변환하는 어댑터
/// 
/// ## 📦 인벤토리 → 전투 스탯 연동 핵심 로직
/// 
/// ### 작동 방식
/// 1. **"그리드 배치 = 장착"**: 
///    - `inventory.placedItems`만 스탯 계산에 포함
///    - `inventory.unplacedItems`는 스탯에 영향 없음
/// 
/// 2. **스탯 추출**:
///    - InventoryItem.properties['combat'] → CombatStats
///    - 시너지 효과도 자동 합산
/// 
/// 3. **전투 캐릭터 생성**:
///    - baseStats + inventoryBonus = finalStats
///    - 무기 자동 추출 및 Character.weapons에 등록
/// 
/// ### 사용 시점
/// - **전투 시작 시**: CombatModule에서 호출하여 스냅샷 생성
/// - **전투 중**: 인벤토리 잠금으로 변경 불가 → 동적 갱신 불필요
/// 
/// ### 주의사항
/// - Player의 RPG 스탯(strength, agility)은 전투에 영향 없음
/// - 이들은 선택지 확률/인카운터 조건에만 사용
/// 
/// InventoryItem의 properties를 CombatStats로 변환하고,
/// 시너지 효과도 계산하여 최종 전투 스탯을 생성합니다.
library;

import '../../inventory/inventory_system.dart';
import '../../inventory/inventory_item.dart';
import '../../inventory/synergy_system.dart';
import '../../combat/stats.dart';
import '../../combat/character.dart';
import '../../combat/item.dart';
import '../../combat/combat_rng.dart';  // DamageRange
import '../../combat/effect_processor.dart';

/// 인벤토리 → 전투 스탯 어댑터
class InventoryAdapter {
  /// InventoryItem의 properties에서 전투 스탯 추출
  /// 
  /// properties 예시:
  /// {
  ///   'combat': {
  ///     'maxHealth': 20,
  ///     'accuracy': 5,
  ///     'defenseRate': 0.1,  // 10% 방어
  ///   }
  /// }
  /// 
  /// 주의: attackPower는 세트 효과(시너지)에서만 적용됩니다.
  /// 아이템의 combat.attackPower는 무시됩니다.
  static CombatStats extractCombatStats(InventoryItem item) {
    final properties = item.properties;
    final combatProps = properties['combat'] as Map<String, dynamic>?;
    
    if (combatProps == null) {
      // 전투 속성이 없는 아이템은 빈 스탯 반환
      return CombatStats.empty;
    }
    
    return CombatStats(
      maxHealth: combatProps['maxHealth'] as int? ?? 0,
      attackPower: 0,  // attackPower는 세트 효과에서만 적용
      accuracy: combatProps['accuracy'] as int? ?? 0,
      defenseRate: (combatProps['defenseRate'] as num?)?.toDouble() ?? 0.0,
    );
  }
  
  /// 시너지 효과에서 전투 스탯 추출
  /// 
  /// synergy.effects 예시:
  /// {
  ///   'attackPower': 15,
  ///   'maxHealth': 30,
  ///   'defenseRate': 0.05,  // 시너지로 5% 방어 추가
  /// }
  static CombatStats extractSynergyStats(SynergyInfo synergy) {
    final effects = synergy.effects;
    
    return CombatStats(
      maxHealth: effects['maxHealth'] as int? ?? 0,
      attackPower: effects['attackPower'] as int? ?? 0,
      accuracy: effects['accuracy'] as int? ?? 0,
      defenseRate: (effects['defenseRate'] as num?)?.toDouble() ?? 0.0,
    );
  }
  
  /// 인벤토리 전체에서 전투 스탯 합산 (아이템 + 시너지)
  /// 
  /// 배치된 아이템만 계산에 포함됩니다.
  static CombatStats calculateTotalStats(InventorySystem inventory) {
    print('[InventoryAdapter] Calculating total combat stats...');
    
    // 1. 배치된 아이템들의 스탯 합산
    CombatStats totalStats = CombatStats.empty;
    
    for (final item in inventory.placedItems) {
      final itemStats = extractCombatStats(item);
      totalStats = totalStats + itemStats;
      
      if (itemStats.maxHealth > 0 || itemStats.attackPower > 0 || itemStats.accuracy > 0 || itemStats.defenseRate > 0) {
        print('[InventoryAdapter]   ${item.name}: HP+${itemStats.maxHealth}, ATK+${itemStats.attackPower}, ACC+${itemStats.accuracy}, DEF+${(itemStats.defenseRate * 100).toStringAsFixed(1)}%');
      }
    }
    
    // 2. 시너지 효과 합산
    final activeSynergies = inventory.synergySystem.getActiveSynergies(inventory.placedItems);
    
    for (final synergy in activeSynergies) {
      final synergyStats = extractSynergyStats(synergy);
      totalStats = totalStats + synergyStats;
      
      if (synergyStats.maxHealth > 0 || synergyStats.attackPower > 0 || synergyStats.accuracy > 0 || synergyStats.defenseRate > 0) {
        print('[InventoryAdapter]   🔗 ${synergy.name}: HP+${synergyStats.maxHealth}, ATK+${synergyStats.attackPower}, ACC+${synergyStats.accuracy}, DEF+${(synergyStats.defenseRate * 100).toStringAsFixed(1)}%');
      }
    }
    
    print('[InventoryAdapter] Total: HP+${totalStats.maxHealth}, ATK+${totalStats.attackPower}, ACC+${totalStats.accuracy}, DEF+${(totalStats.defenseRate * 100).toStringAsFixed(1)}%');
    
    return totalStats;
  }
  
  /// 인벤토리를 전투 캐릭터의 스탯에 적용
  /// 
  /// 기존 baseStats에 인벤토리 보너스를 더합니다.
  static CombatStats applyInventoryToStats(
    CombatStats baseStats, 
    InventorySystem inventory,
  ) {
    final inventoryBonus = calculateTotalStats(inventory);
    return baseStats + inventoryBonus;
  }
  
  /// 인벤토리에서 무기 아이템들을 추출하여 Combat Weapon으로 변환
  /// 
  /// ### 데미지 파싱 우선순위
  /// 1. `damageRange: { min, max }` 가 있으면 범위 데미지
  /// 2. `damageRange`가 없으면 `baseDamage` 단일값 (레거시 호환)
  /// 
  /// ### 예시 JSON
  /// ```json
  /// "weapon": {
  ///   "type": "melee",
  ///   "baseDamage": 3,           // 레거시 (단일값)
  ///   "damageRange": { "min": 4, "max": 5 },  // 범위 데미지 (우선)
  ///   ...
  /// }
  /// ```
  static List<Weapon> extractWeapons(InventorySystem inventory) {
    final weapons = <Weapon>[];
    
    for (final item in inventory.placedItems) {
      final weaponData = item.properties['weapon'] as Map<String, dynamic>?;
      
      if (weaponData != null) {
        // 무기 타입 확인
        final weaponType = weaponData['type'] as String? ?? 'melee';
        
        // ═══════════════════════════════════════════════════════════════════════════
        // 데미지 범위 파싱 (v2.0)
        // ═══════════════════════════════════════════════════════════════════════════
        // 우선순위:
        // 1. damageRange: { min, max } → DamageRange 생성
        // 2. damageRange 없음 → null (baseDamage fallback)
        // ═══════════════════════════════════════════════════════════════════════════
        DamageRange? damageRange;
        final damageRangeData = weaponData['damageRange'] as Map<String, dynamic>?;
        
        if (damageRangeData != null) {
          damageRange = DamageRange.fromJson(damageRangeData);
          
          // 유효성 검증
          if (!damageRange.isValid) {
            print('[InventoryAdapter] WARNING: Invalid damageRange for ${item.name}: $damageRange, using baseDamage fallback');
            damageRange = null;  // fallback to baseDamage
          }
        }
        
        final weapon = weaponType == 'ranged'
            ? RangedWeapon(
                id: item.id,
                name: item.name,
                baseDamage: (weaponData['baseDamage'] as num?)?.toDouble() ?? 10.0,
                staminaCost: (weaponData['staminaCost'] as num?)?.toDouble() ?? 5.0,
                baseCooldown: (weaponData['cooldown'] as num?)?.toDouble() ?? 1.0,
                accuracy: (weaponData['accuracy'] as num?)?.toDouble() ?? 0.75,
                criticalChance: (weaponData['criticalChance'] as num?)?.toDouble() ?? 0.1,
                criticalMultiplier: (weaponData['criticalMultiplier'] as num?)?.toDouble() ?? 1.5,
                damageRange: damageRange,
              )
            : MeleeWeapon(
                id: item.id,
                name: item.name,
                baseDamage: (weaponData['baseDamage'] as num?)?.toDouble() ?? 10.0,
                staminaCost: (weaponData['staminaCost'] as num?)?.toDouble() ?? 5.0,
                baseCooldown: (weaponData['cooldown'] as num?)?.toDouble() ?? 1.0,
                accuracy: (weaponData['accuracy'] as num?)?.toDouble() ?? 0.75,
                criticalChance: (weaponData['criticalChance'] as num?)?.toDouble() ?? 0.1,
                criticalMultiplier: (weaponData['criticalMultiplier'] as num?)?.toDouble() ?? 1.5,
                damageRange: damageRange,
              );
        
        weapons.add(weapon);
        
        // Weapon과 원본 InventoryItem 연결 (properties['effects'] 접근용)
        EffectProcessor.registerWeaponSource(weapon, item);
        
        // 로그 출력 (데미지 범위 포함)
        final damageStr = damageRange != null 
            ? damageRange.toDisplayString() 
            : '${weapon.baseDamage.round()}';
        print('[InventoryAdapter] Extracted weapon: ${weapon.name} ($weaponType, damage: $damageStr)');
      }
    }
    
    return weapons;
  }
  
  /// 플레이어 인벤토리 → 전투 캐릭터 생성 헬퍼
  /// 
  /// 예시 사용:
  /// ```dart
  /// final playerChar = InventoryAdapter.createPlayerCharacter(
  ///   name: '모험가',
  ///   baseStats: CombatStats(maxHealth: 100, attackPower: 15, accuracy: 75),
  ///   inventory: playerInventory,
  /// );
  /// ```
  static Character createPlayerCharacter({
    required String name,
    required CombatStats baseStats,
    required InventorySystem inventory,
  }) {
    print('[InventoryAdapter] Creating player character with inventory...');
    
    // 인벤토리 보너스 적용
    final finalStats = applyInventoryToStats(baseStats, inventory);
    
    // 캐릭터 생성 (Character는 자체 인벤토리를 가지고 있음)
    final character = Character(
      name: name,
      stats: finalStats,
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 🧳 인컴버런스(무게 초과) 페널티를 전투 캐릭터에 스냅샷으로 반영 (v6.2)
    // ══════════════════════════════════════════════════════════════════════════
    // - 전투 시작 시 인벤토리는 잠금되므로, 전투 중 동적으로 변할 필요가 없다.
    // - E (쿨타임 계수): Normal/Uncomfortable=1.0, Danger=0.8, Collapse=0.6
    // - 스태미나 델타: Normal=0, Uncomfortable=-0.1, Danger=-0.2, Collapse=-0.3
    character.cooldownTickRateMultiplier = inventory.cooldownTickRateMultiplier;
    character.staminaRecoveryDelta = inventory.staminaRecoveryDelta;
    
    // 고정 데미지 감소 합산 (여러 아이템 장착 시 중첩)
    character.flatDamageReduction = _calculateFlatDamageReduction(inventory);
    
    print('[InventoryAdapter]   Encumbrance: ${inventory.encumbranceTier.displayName}');
    print('[InventoryAdapter]   E (cooldown): ${inventory.cooldownTickRateMultiplier}');
    print('[InventoryAdapter]   Stamina delta: ${inventory.staminaRecoveryDelta}/s');
    if (character.flatDamageReduction > 0) {
      print('[InventoryAdapter]   Flat Damage Reduction: ${character.flatDamageReduction}');
    }
    
    // ❌ character.inventorySystem은 late final이라 재할당 불가
    // 대신 원본 인벤토리의 아이템들을 복사
    for (final item in inventory.placedItems) {
      character.inventorySystem.tryAddItem(item);
    }
    
    // 무기 추출 및 장착
    final weapons = extractWeapons(inventory);
    for (final weapon in weapons) {
      character.addWeapon(weapon);
    }
    
    print('[InventoryAdapter] Player character created: ${character.name}');
    print('[InventoryAdapter]   HP: ${finalStats.maxHealth}, ATK: ${finalStats.attackPower}, ACC: ${finalStats.accuracy}, DEF: ${(finalStats.defenseRate * 100).toStringAsFixed(1)}%');
    print('[InventoryAdapter]   Weapons: ${weapons.length}');
    
    return character;
  }
  
  /// 인벤토리에서 고정 데미지 감소 합산 (중첩 적용)
  static int _calculateFlatDamageReduction(InventorySystem inventory) {
    int total = 0;
    for (final item in inventory.placedItems) {
      final combatProps = item.properties['combat'] as Map<String, dynamic>?;
      final reduction = combatProps?['flatDamageReduction'] as int? ?? 0;
      total += reduction;
    }
    return total;
  }
  
  /// 적 인벤토리 → 스탯 보너스 계산
  /// 
  /// 예시 사용:
  /// ```dart
  /// final enemyInventory = EnemyInventoryLoader.loadFromEncounter(payload);
  /// final statsBonus = InventoryAdapter.calculateEnemyStatsBonus(enemyInventory);
  /// final finalStats = baseEnemyStats + statsBonus;
  /// ```
  static CombatStats calculateEnemyStatsBonus(InventorySystem enemyInventory) {
    print('[InventoryAdapter] Calculating enemy stats bonus...');
    return calculateTotalStats(enemyInventory);
  }
  
  /// 적 인벤토리 → 전투 캐릭터 생성 헬퍼
  static Character createEnemyCharacter({
    required String name,
    required CombatStats baseStats,
    required InventorySystem inventory,
  }) {
    print('[InventoryAdapter] Creating enemy character with inventory...');
    
    // 인벤토리 보너스 적용
    final finalStats = applyInventoryToStats(baseStats, inventory);
    
    // 캐릭터 생성 (Character는 자체 인벤토리를 가지고 있음)
    final character = Character(
      name: name,
      stats: finalStats,
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 적도 동일하게 무게 페널티 스냅샷 적용 (v6.2)
    // ══════════════════════════════════════════════════════════════════════════
    character.cooldownTickRateMultiplier = inventory.cooldownTickRateMultiplier;
    character.staminaRecoveryDelta = inventory.staminaRecoveryDelta;
    
    // 고정 데미지 감소 합산 (여러 아이템 장착 시 중첩)
    character.flatDamageReduction = _calculateFlatDamageReduction(inventory);
    
    print('[InventoryAdapter]   Encumbrance: ${inventory.encumbranceTier.displayName}');
    print('[InventoryAdapter]   E (cooldown): ${inventory.cooldownTickRateMultiplier}');
    print('[InventoryAdapter]   Stamina delta: ${inventory.staminaRecoveryDelta}/s');
    if (character.flatDamageReduction > 0) {
      print('[InventoryAdapter]   Flat Damage Reduction: ${character.flatDamageReduction}');
    }
    
    // ❌ character.inventorySystem은 late final이라 재할당 불가
    // 대신 원본 인벤토리의 아이템들을 복사 (전투 화면 표시용)
    for (final item in inventory.placedItems) {
      character.inventorySystem.tryAddItem(item);
    }
    
    // 무기 추출 및 장착
    final weapons = extractWeapons(inventory);
    for (final weapon in weapons) {
      character.addWeapon(weapon);
    }
    
    print('[InventoryAdapter] Enemy character created: ${character.name}');
    print('[InventoryAdapter]   HP: ${finalStats.maxHealth}, ATK: ${finalStats.attackPower}, ACC: ${finalStats.accuracy}, DEF: ${(finalStats.defenseRate * 100).toStringAsFixed(1)}%');
    print('[InventoryAdapter]   Weapons: ${weapons.length}');
    
    return character;
  }
}


