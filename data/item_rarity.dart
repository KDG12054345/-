/// 아이템 희귀도(Rarity) 열거형 및 정규화 유틸리티.
///
/// ## 사용법
/// ```dart
/// final rarity = resolveItemRarity('epic', 'sword_01');
/// // => ItemRarity.epic
///
/// // InventoryItem에서 사용
/// final item = InventoryItem(...);
/// final rarity = resolveItemRarity(item.properties['rarity'], item.id);
/// ```
///
/// ## 정규화 규칙
/// - 입력은 대소문자 무시 (case-insensitive)
/// - 앞뒤 공백은 trim 처리
/// - 누락 또는 잘못된 값은 [ItemRarity.common]으로 fallback
/// - dev/profile 빌드에서는 잘못된 입력 시 경고 로그 출력
library;

import 'package:flutter/foundation.dart';

/// 아이템 희귀도 열거형
///
/// 정의된 4종류: COMMON, RARE, EPIC, LEGENDARY
enum ItemRarity {
  /// 일반 아이템 (기본값)
  common,

  /// 레어 아이템
  rare,

  /// 에픽 아이템
  epic,

  /// 전설 아이템
  legendary;

  /// 내부 정규화된 문자열 (대문자)
  ///
  /// JSON 직렬화나 비교에 사용할 수 있습니다.
  String get normalized => name.toUpperCase();

  /// 표시용 이름 (첫 글자 대문자)
  String get displayName {
    switch (this) {
      case ItemRarity.common:
        return 'Common';
      case ItemRarity.rare:
        return 'Rare';
      case ItemRarity.epic:
        return 'Epic';
      case ItemRarity.legendary:
        return 'Legendary';
    }
  }

  /// 문자열에서 ItemRarity로 변환 (case-insensitive)
  ///
  /// 유효하지 않은 값이면 null 반환
  static ItemRarity? tryParse(String? value) {
    if (value == null) return null;

    final normalized = value.trim().toUpperCase();
    switch (normalized) {
      case 'COMMON':
        return ItemRarity.common;
      case 'RARE':
        return ItemRarity.rare;
      case 'EPIC':
        return ItemRarity.epic;
      case 'LEGENDARY':
        return ItemRarity.legendary;
      default:
        return null;
    }
  }
}

/// 아이템의 rarity를 정규화하여 [ItemRarity] enum으로 반환합니다.
///
/// ## 해석 규칙
/// 1. `rawRarity`가 문자열이면 대소문자 무시하고 정규화
/// 2. 앞뒤 공백은 자동으로 trim
/// 3. 허용 값: 'COMMON', 'RARE', 'EPIC', 'LEGENDARY' (대소문자 무관)
/// 4. 누락/null이면 [ItemRarity.common] 반환
/// 5. 잘못된 값이면 경고 로그 후 [ItemRarity.common] 반환
///
/// ## 예시
/// ```dart
/// resolveItemRarity('epic', 'sword_01')        // => ItemRarity.epic
/// resolveItemRarity('EPIC', 'sword_01')        // => ItemRarity.epic
/// resolveItemRarity('  Epic  ', 'sword_01')    // => ItemRarity.epic
/// resolveItemRarity(null, 'sword_01')          // => ItemRarity.common
/// resolveItemRarity('invalid', 'sword_01')     // => ItemRarity.common (+ 경고)
/// ```
///
/// [rawRarity]: properties['rarity']에서 읽은 원본 값
/// [itemId]: 경고 로그에 포함할 아이템 ID (디버깅용)
ItemRarity resolveItemRarity(dynamic rawRarity, String itemId) {
  // null/누락: 기본값 COMMON
  if (rawRarity == null) {
    return ItemRarity.common;
  }

  // 문자열이 아닌 경우: 경고 + fallback
  if (rawRarity is! String) {
    if (kDebugMode) {
      debugPrint(
        '[ItemRarity] WARN: itemId="$itemId" has non-string rarity '
        '(type=${rawRarity.runtimeType}, value=$rawRarity). '
        'Defaulting to COMMON.',
      );
    }
    return ItemRarity.common;
  }

  // 공백 제거 후 파싱 시도
  final parsed = ItemRarity.tryParse(rawRarity);
  if (parsed != null) {
    return parsed;
  }

  // 잘못된 문자열: 경고 + fallback
  if (kDebugMode) {
    debugPrint(
      '[ItemRarity] WARN: itemId="$itemId" has invalid rarity="$rawRarity". '
      'Allowed values: COMMON, RARE, EPIC, LEGENDARY. '
      'Defaulting to COMMON.',
    );
  }
  return ItemRarity.common;
}

/// 아이템의 rarity를 정규화된 대문자 문자열로 반환합니다.
///
/// [resolveItemRarity]와 동일한 정규화 규칙을 적용하며,
/// 결과를 문자열로 반환합니다.
///
/// ## 예시
/// ```dart
/// resolveItemRarityString('epic', 'sword_01')  // => 'EPIC'
/// resolveItemRarityString(null, 'sword_01')    // => 'COMMON'
/// ```
String resolveItemRarityString(dynamic rawRarity, String itemId) {
  return resolveItemRarity(rawRarity, itemId).normalized;
}
