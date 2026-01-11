/// 아이템 타입(Type) 열거형 및 정규화 유틸리티.
///
/// ## 사용법
/// ```dart
/// final type = resolveItemType('weapon', 'sword_01');
/// // => ItemType.weapon
///
/// // InventoryItem에서 사용
/// final item = InventoryItem(...);
/// final type = resolveItemType(item.properties['type'], item.id);
/// ```
///
/// ## 정규화 규칙
/// - 입력은 대소문자 무시 (case-insensitive)
/// - 앞뒤 공백은 trim 처리
/// - alias 매핑 적용 (예: potion → misc)
/// - 누락 또는 잘못된 값은 [ItemType.misc]로 fallback
/// - dev/profile 빌드에서는 잘못된 입력 시 경고 로그 출력
library;

import 'package:flutter/foundation.dart';

/// 아이템 타입 열거형
///
/// ## 허용 타입 (SSOT - Single Source of Truth)
/// - weapon: 무기
/// - armor: 방어구
/// - accessory: 장신구
/// - bag: 가방
/// - misc: 기타/알 수 없음 (fallback용)
///
/// ## 미구현/예약 타입 (향후 추가 예정)
/// - pet: 펫 (현재 미구현, alias로 misc 처리)
/// - potion: 물약 (현재 미구현, alias로 misc 처리)
/// - food: 음식 (현재 미구현, alias로 misc 처리)
enum ItemType {
  /// 무기
  weapon,

  /// 방어구
  armor,

  /// 장신구
  accessory,

  /// 가방
  bag,

  /// 기타/알 수 없음 (fallback)
  misc;

  /// 내부 정규화된 문자열 (소문자)
  ///
  /// JSON 직렬화나 비교에 사용할 수 있습니다.
  String get normalized => name.toLowerCase();

  /// 표시용 이름 (첫 글자 대문자)
  String get displayName {
    switch (this) {
      case ItemType.weapon:
        return 'Weapon';
      case ItemType.armor:
        return 'Armor';
      case ItemType.accessory:
        return 'Accessory';
      case ItemType.bag:
        return 'Bag';
      case ItemType.misc:
        return 'Misc';
    }
  }

  /// 한국어 표시용 이름
  String get displayNameKo {
    switch (this) {
      case ItemType.weapon:
        return '무기';
      case ItemType.armor:
        return '방어구';
      case ItemType.accessory:
        return '장신구';
      case ItemType.bag:
        return '가방';
      case ItemType.misc:
        return '기타';
    }
  }

  /// 가방 타입인지 확인
  bool get isBag => this == ItemType.bag;

  /// 장비 타입인지 확인 (weapon, armor, accessory)
  bool get isEquipment =>
      this == ItemType.weapon ||
      this == ItemType.armor ||
      this == ItemType.accessory;
}

/// 허용된 타입 목록 (정규화된 소문자)
///
/// 이 목록에 없는 타입은 경고 로그 후 [ItemType.misc]로 fallback됩니다.
const Set<String> _allowedTypes = {
  'weapon',
  'armor',
  'accessory',
  'bag',
  'misc',
};

/// 타입 별칭(alias) 매핑
///
/// 레거시 호환 및 문서 불일치 대응용.
/// key: 원본 타입 (정규화된 소문자)
/// value: 매핑될 공식 타입 (정규화된 소문자)
const Map<String, String> _typeAliases = {
  // 축약형
  'acc': 'accessory', // 축약형

  // 미구현 타입 (향후 구현 시 제거)
  'potion': 'misc', // 물약은 아직 미구현
  'food': 'misc', // 음식은 아직 미구현
  'pet': 'misc', // 펫은 아직 미구현
  'consumable': 'misc', // 소비품은 더 이상 사용하지 않음
};

/// 문자열에서 ItemType으로 변환 (정규화 + alias 적용)
///
/// 유효하지 않은 값이면 null 반환
ItemType? _tryParseItemType(String value) {
  // 1. 정규화 (trim + lowercase)
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return null;

  // 2. alias 적용
  final resolvedType = _typeAliases[normalized] ?? normalized;

  // 3. 허용 목록 확인 및 enum 변환
  switch (resolvedType) {
    case 'weapon':
      return ItemType.weapon;
    case 'armor':
      return ItemType.armor;
    case 'accessory':
      return ItemType.accessory;
    case 'bag':
      return ItemType.bag;
    case 'misc':
      return ItemType.misc;
    default:
      return null;
  }
}

/// 아이템의 type을 정규화하여 [ItemType] enum으로 반환합니다.
///
/// ## 해석 규칙
/// 1. `rawType`이 문자열이면 trim 후 lowercase로 정규화
/// 2. alias 매핑 적용 (예: potion → misc)
/// 3. 허용 타입 목록에서 확인
/// 4. 누락/null이면 [ItemType.misc] 반환
/// 5. 잘못된 값이면 경고 로그 후 [ItemType.misc] 반환
///
/// ## 예시
/// ```dart
/// resolveItemType('weapon', 'sword_01')       // => ItemType.weapon
/// resolveItemType('WEAPON', 'sword_01')       // => ItemType.weapon
/// resolveItemType('  Weapon  ', 'sword_01')   // => ItemType.weapon
/// resolveItemType('potion', 'health_potion')  // => ItemType.misc (alias)
/// resolveItemType('consumable', 'item')       // => ItemType.misc (alias)
/// resolveItemType(null, 'sword_01')           // => ItemType.misc
/// resolveItemType('invalid', 'sword_01')      // => ItemType.misc (+ 경고)
/// ```
///
/// [rawType]: properties['type']에서 읽은 원본 값
/// [itemId]: 경고 로그에 포함할 아이템 ID (디버깅용)
ItemType resolveItemType(dynamic rawType, String itemId) {
  // null/누락: 기본값 misc
  if (rawType == null) {
    return ItemType.misc;
  }

  // 문자열이 아닌 경우: 경고 + fallback
  if (rawType is! String) {
    if (kDebugMode) {
      debugPrint(
        '[ItemType] WARN: itemId="$itemId" has non-string type '
        '(type=${rawType.runtimeType}, value=$rawType). '
        'Defaulting to misc.',
      );
    }
    return ItemType.misc;
  }

  // alias 적용 여부 추적 (경고 로그용)
  final normalized = rawType.trim().toLowerCase();
  final aliasApplied = _typeAliases.containsKey(normalized);
  final resolvedType = _typeAliases[normalized] ?? normalized;

  // 파싱 시도
  final parsed = _tryParseItemType(rawType);
  if (parsed != null) {
    // alias가 적용된 경우 dev에서 알림 (경고가 아닌 정보)
    if (aliasApplied && kDebugMode) {
      debugPrint(
        '[ItemType] INFO: itemId="$itemId" type="$rawType" '
        '→ aliased to "${parsed.normalized}". '
        'Consider updating JSON to use "$resolvedType" directly.',
      );
    }
    return parsed;
  }

  // 잘못된 문자열: 경고 + fallback
  if (kDebugMode) {
    debugPrint(
      '[ItemType] WARN: itemId="$itemId" has invalid type="$rawType". '
      'Allowed values: ${_allowedTypes.join(", ")}. '
      'Aliases: ${_typeAliases.keys.join(", ")}. '
      'Defaulting to misc.',
    );
  }
  return ItemType.misc;
}

/// 아이템의 type을 정규화된 소문자 문자열로 반환합니다.
///
/// [resolveItemType]와 동일한 정규화 규칙을 적용하며,
/// 결과를 문자열로 반환합니다.
///
/// ## 예시
/// ```dart
/// resolveItemTypeString('weapon', 'sword_01')  // => 'weapon'
/// resolveItemTypeString('potion', 'health_potion')  // => 'misc'
/// resolveItemTypeString('consumable', 'item')  // => 'misc'
/// resolveItemTypeString(null, 'sword_01')      // => 'misc'
/// ```
String resolveItemTypeString(dynamic rawType, String itemId) {
  return resolveItemType(rawType, itemId).normalized;
}

/// 주어진 타입 문자열이 유효한지 검사합니다 (alias 포함).
///
/// 정규화 후 허용 목록 또는 alias에 있으면 true.
bool isValidItemType(String? rawType) {
  if (rawType == null) return false;
  final normalized = rawType.trim().toLowerCase();
  return _allowedTypes.contains(normalized) ||
      _typeAliases.containsKey(normalized);
}

/// 허용된 타입 목록을 반환합니다 (읽기 전용).
Set<String> get allowedItemTypes => Set.unmodifiable(_allowedTypes);

/// 타입 별칭 매핑을 반환합니다 (읽기 전용).
Map<String, String> get itemTypeAliases => Map.unmodifiable(_typeAliases);
