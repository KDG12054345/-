/// Inventory item weight table (0.5 단위 = 1 unit).
///
/// - **1 unit = 0.5 weight**
/// - Unknown IDs fall back to [_defaultWeightUnits].
///
/// This is intentionally kept as a data-layer mapping (`itemId -> weightUnits`)
/// to minimize invasive changes across legacy inventory/item systems.
///
/// ## Weight Resolution Priority (v2)
/// 1. `properties['weightUnits']` (JSON 정의, 권장)
/// 2. `properties['weight']` (호환용, 경고 출력)
/// 3. `kInventoryItemWeightUnitsById[itemId]` (레거시 Dart 맵)
/// 4. 0 (기본값, dev 빌드에서 경고)
library;

import 'package:flutter/foundation.dart';

/// 기본 무게(알 수 없는 아이템 ID용): 0 units = 0.0
/// 
/// 주의: JSON이나 맵에 정의되지 않은 경우 0을 반환하고 경고를 출력합니다.
const int _fallbackWeightUnits = 0;

/// 아이템 ID → weightUnits (0.5 단위 정수)
///
/// NOTE:
/// - 여기의 키는 "아이템 정의 ID"로 취급합니다(인스턴스 ID/타임스탬프 포함 ID는 지양).
/// - 밸런싱은 이후에 조정 가능하며, 값이 없으면 기본값을 사용합니다.
const Map<String, int> kInventoryItemWeightUnitsById = {
  // ── Reward / common demo items ────────────────────────────────
  'steel_sword': 6, // 3.0
  'wooden_shield': 8, // 4.0
  'health_potion': 2, // 1.0

  // ── Enemy inventory generator pool (examples) ─────────────────
  'rusty_dagger': 4,
  'torn_cloth': 3,
  'iron_sword': 6,
  'leather_armor': 10,
  'healing_potion': 2,
  'chain_armor': 14,
  'mana_potion': 2,
  'magic_ring': 1,
  'legendary_weapon': 10,
  'dragon_armor': 20,
  'elixir': 2,
  'artifact': 2,

  // bandit
  'dagger': 2,
  'bow': 6,
  'poison_vial': 2,

  // monster / undead / mage (rough defaults)
  'claw': 2,
  'fang': 2,
  'hide': 6,
  'cursed_blade': 8,
  'bone_armor': 12,
  'soul_gem': 2,
  'staff': 6,
  'spell_book': 4,
  'wand': 4,
  'robe': 6,
};

/// 아이템 ID의 weightUnits를 반환합니다.
/// 
/// **레거시 함수** - 새 코드에서는 [resolveWeightUnits]를 사용하세요.
/// 이 함수는 Dart 맵에서만 조회하며, JSON properties를 확인하지 않습니다.
int weightUnitsForInventoryItemId(String itemId) {
  return kInventoryItemWeightUnitsById[itemId] ?? _fallbackWeightUnits;
}

/// 아이템의 weightUnits를 해석합니다 (우선순위 기반).
///
/// ## 해석 우선순위
/// 1. `properties['weightUnits']` - JSON에 정의된 값 (권장)
/// 2. `properties['weight']` - 호환용 (사용 시 경고)
/// 3. `kInventoryItemWeightUnitsById[itemId]` - 레거시 Dart 맵
/// 4. 0 - 기본값 (dev/profile 빌드에서 경고)
///
/// ### 사용 예시
/// ```dart
/// final units = resolveWeightUnits('dagger', {'weightUnits': 4});
/// // returns 4
/// ```
int resolveWeightUnits(String itemId, Map<String, dynamic>? properties) {
  // 1순위: properties['weightUnits']
  if (properties != null) {
    final weightUnits = properties['weightUnits'];
    if (weightUnits != null) {
      if (weightUnits is int) return weightUnits;
      if (weightUnits is num) return weightUnits.toInt();
    }
    
    // 2순위: properties['weight'] (호환용, 경고)
    final weight = properties['weight'];
    if (weight != null) {
      if (kDebugMode) {
        debugPrint(
          '[WeightResolver] WARN: itemId="$itemId" uses deprecated "weight" key. '
          'Please migrate to "weightUnits".',
        );
      }
      if (weight is int) return weight;
      if (weight is num) return weight.toInt();
    }
  }
  
  // 3순위: 레거시 Dart 맵에서 조회
  final legacyValue = kInventoryItemWeightUnitsById[itemId];
  if (legacyValue != null) {
    return legacyValue;
  }
  
  // 4순위: 기본값 0 + 경고
  if (kDebugMode) {
    debugPrint(
      '[WeightResolver] WARN: weightUnits missing for itemId="$itemId". '
      'Defaulting to 0. Add "weightUnits" to JSON or update the legacy map.',
    );
  }
  return _fallbackWeightUnits;
}

/// weightUnits가 명시적으로 정의되어 있는지 확인합니다.
/// 
/// JSON properties나 레거시 맵에 정의가 있으면 true를 반환합니다.
bool hasExplicitWeightUnits(String itemId, Map<String, dynamic>? properties) {
  if (properties != null) {
    if (properties['weightUnits'] != null) return true;
    if (properties['weight'] != null) return true;
  }
  return kInventoryItemWeightUnitsById.containsKey(itemId);
}





