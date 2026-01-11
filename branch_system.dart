import 'package:flutter/foundation.dart';
import 'event_system.dart';
import 'dart:math';
import 'core/character/character_models.dart'; // Trait만 import

// NOTE(maint): 2025-12-21 리팩터링
// - 왜: `dialogue_manager.dart`에도 `Choice`가 있어, 프로젝트 전역에서 `Choice` 타입이 중복 정의되어
//   import 충돌/혼란이 발생할 수 있었음.
// - 무엇: 이 파일 하단의 "콘텐츠 예시" 영역에 있던 `Choice`를 `ContentChoice`로 이름 변경해 충돌을 원천 차단.
// - 호환성: Branch/조건평가 로직(대사 분기/되돌리기/조건 판정)에는 영향 없음. 하단 예시용 타입명만 변경.

void _branchWarn(String message) {
  debugPrint('[BranchSystem] $message');
}

/// 분기점을 표현하는 클래스
class BranchPoint {
  final String sceneId;
  final String choiceId;
  final DateTime timestamp;
  final Map<String, dynamic> gameState;

  const BranchPoint({
    required this.sceneId,
    required this.choiceId,
    required this.timestamp,
    required this.gameState,
  });
}

/// 분기 조건을 평가하는 클래스
class BranchConditionEvaluator {
  /// 복합 조건 평가
  bool evaluateCondition(Map<String, dynamic> condition, GameState state) {
    // 조건이 없으면 true 반환
    if (condition.isEmpty) return true;

    // AND 조건 처리
    if (condition.containsKey('and')) {
      final raw = condition['and'];
      if (raw is List) {
        final list = raw.whereType<Map<String, dynamic>>().toList();
        if (list.length != raw.length) {
          _branchWarn('Invalid element inside AND condition: $raw');
        }
        if (list.isEmpty) return true; // 빈 리스트면 참으로 처리
        return list.every((c) => evaluateCondition(c, state));
      }
      _branchWarn('AND condition must be a List<Map<String,dynamic>>: $raw');
      return false;
    }

    // OR 조건 처리
    if (condition.containsKey('or')) {
      final raw = condition['or'];
      if (raw is List) {
        final list = raw.whereType<Map<String, dynamic>>().toList();
        if (list.length != raw.length) {
          _branchWarn('Invalid element inside OR condition: $raw');
        }
        if (list.isEmpty) return false; // 빈 리스트면 거짓으로 처리
        return list.any((c) => evaluateCondition(c, state));
      }
      _branchWarn('OR condition must be a List<Map<String,dynamic>>: $raw');
      return false;
    }

    // NOT 조건 처리
    if (condition.containsKey('not')) {
      final raw = condition['not'];
      if (raw is Map<String, dynamic>) {
        return !evaluateCondition(raw, state);
      }
      _branchWarn('NOT condition must be a Map<String,dynamic>: $raw');
      return false;
    }

    // 기본 조건 처리 (stats, items, flags)
    return _evaluateBasicCondition(condition, state);
  }

  /// 기본 조건 평가
  bool _evaluateBasicCondition(Map<String, dynamic> condition, GameState state) {
    // 스탯 조건
    if (condition.containsKey('stats')) {
      final stats = condition['stats'];
      if (stats is! Map<String, dynamic>) {
        _branchWarn('stats condition must be a Map<String,dynamic>: ${condition['stats']}');
        return false;
      }
      for (final entry in stats.entries) {
        final statValue = state.stats[entry.key] ?? 0;
        final requiredValue = entry.value;

        if (requiredValue is Map<String, dynamic>) {
          // 비교 연산자 처리
          if (!_evaluateComparison(statValue, requiredValue)) return false;
        } else if (requiredValue is num) {
          // 단순 비교 (이상치 보호)
          if (statValue < requiredValue) return false;
        } else {
          _branchWarn('Invalid stats required value for ${entry.key}: ${entry.value}');
          return false;
        }
      }
    }

    // 아이템 조건
    if (condition.containsKey('items')) {
      final items = condition['items'];
      if (items is! Map<String, dynamic>) {
        _branchWarn('items condition must be a Map<String,dynamic>: ${condition['items']}');
        return false;
      }

      // 필요 아이템
      final required = items['required'];
      if (required != null) {
        if (required is! List) {
          _branchWarn('items.required must be a List: $required');
          return false;
        }
        final requiredStrings = required.whereType<String>().toList();
        if (requiredStrings.length != required.length) {
          _branchWarn('items.required contains non-String elements: $required');
        }
        if (!requiredStrings.every((item) => state.items.contains(item))) return false;
      }

      // 금지 아이템
      final forbidden = items['forbidden'];
      if (forbidden != null) {
        if (forbidden is! List) {
          _branchWarn('items.forbidden must be a List: $forbidden');
          return false;
        }
        final forbiddenStrings = forbidden.whereType<String>().toList();
        if (forbiddenStrings.length != forbidden.length) {
          _branchWarn('items.forbidden contains non-String elements: $forbidden');
        }
        if (forbiddenStrings.any((item) => state.items.contains(item))) return false;
      }

      // 아이템 개수 조건
      final count = items['count'];
      if (count != null) {
        if (count is! Map<String, dynamic>) {
          _branchWarn('items.count must be a Map<String,dynamic>: $count');
          return false;
        }
        for (final entry in count.entries) {
          final itemCount = state.items.where((item) => item == entry.key).length;
          final comparison = entry.value;
          if (comparison is! Map<String, dynamic>) {
            _branchWarn('items.count for ${entry.key} must be a comparison map: ${entry.value}');
            return false;
          }
          if (!_evaluateComparison(itemCount, comparison)) return false;
        }
      }
    }

    // 플래그 조건
    if (condition.containsKey('flags')) {
      final flags = condition['flags'];
      if (flags is! Map<String, dynamic>) {
        _branchWarn('flags condition must be a Map<String,dynamic>: ${condition['flags']}');
        return false;
      }
      for (final entry in flags.entries) {
        final required = entry.value;
        if (required is! bool) {
          _branchWarn('Flag required value must be bool for ${entry.key}: ${entry.value}');
          return false;
        }
        if ((state.flags[entry.key] ?? false) != required) return false;
      }
    }

    // 특성 조건 추가
    if (condition.containsKey('traits')) {
      final requiredTraits = condition['traits'];
      if (requiredTraits is! List) {
        _branchWarn('traits must be a List: $requiredTraits');
        return false;
      }
      final traitStrings = requiredTraits.whereType<String>().toList();
      if (traitStrings.length != requiredTraits.length) {
        _branchWarn('traits contains non-String elements: $requiredTraits');
      }
      if (!traitStrings.every((trait) => state.traits.contains(trait))) return false;
    }
    // 또는
    if (condition.containsKey('has_trait')) {
      final trait = condition['has_trait'];
      if (trait is! String) {
        _branchWarn('has_trait must be a String: $trait');
        return false;
      }
      if (!state.traits.contains(trait)) return false;
    }

    return true;
  }

  /// 비교 연산 평가
  bool _evaluateComparison(num value, Map<String, dynamic> comparison) {
    if (comparison.containsKey('gt')) {
      final v = comparison['gt'];
      if (v is num) return value > v;
      _branchWarn('gt must be num: $v');
      return false;
    }
    if (comparison.containsKey('gte')) {
      final v = comparison['gte'];
      if (v is num) return value >= v;
      _branchWarn('gte must be num: $v');
      return false;
    }
    if (comparison.containsKey('lt')) {
      final v = comparison['lt'];
      if (v is num) return value < v;
      _branchWarn('lt must be num: $v');
      return false;
    }
    if (comparison.containsKey('lte')) {
      final v = comparison['lte'];
      if (v is num) return value <= v;
      _branchWarn('lte must be num: $v');
      return false;
    }
    if (comparison.containsKey('eq')) {
      final v = comparison['eq'];
      if (v is num) return value == v;
      _branchWarn('eq must be num: $v');
      return false;
    }
    if (comparison.containsKey('neq')) {
      final v = comparison['neq'];
      if (v is num) return value != v;
      _branchWarn('neq must be num: $v');
      return false;
    }
    return false;
  }
}

/// 분기 시스템 관리 클래스
class BranchSystem extends ChangeNotifier {
  final List<BranchPoint> _branchHistory = [];
  final BranchConditionEvaluator _evaluator;
  int _currentBranchIndex = -1;

  BranchSystem({BranchConditionEvaluator? evaluator})
      : _evaluator = evaluator ?? BranchConditionEvaluator();

  // 현재 분기점 getter
  BranchPoint? get currentBranch =>
      _currentBranchIndex >= 0 && _currentBranchIndex < _branchHistory.length
          ? _branchHistory[_currentBranchIndex]
          : null;

  // 분기 이력 getter
  List<BranchPoint> get branchHistory => List.unmodifiable(_branchHistory);

  // 새로운 분기점 추가
  void addBranch(String sceneId, String choiceId, Map<String, dynamic> gameState, {bool suppressNotify = false}) {
    // 현재 위치 이후의 분기 이력 제거
    if (_currentBranchIndex < _branchHistory.length - 1) {
      _branchHistory.removeRange(_currentBranchIndex + 1, _branchHistory.length);
    }

    // 새 분기점 추가
    _branchHistory.add(BranchPoint(
      sceneId: sceneId,
      choiceId: choiceId,
      timestamp: DateTime.now(),
      gameState: Map.from(gameState),
    ));
    _currentBranchIndex = _branchHistory.length - 1;
    if (!suppressNotify) notifyListeners();
  }

  // 이전 분기점으로 이동
  BranchPoint? goToPreviousBranch({bool suppressNotify = false}) {
    if (_currentBranchIndex > 0) {
      _currentBranchIndex--;
      if (!suppressNotify) notifyListeners();
      return currentBranch;
    }
    return null;
  }

  // 다음 분기점으로 이동
  BranchPoint? goToNextBranch({bool suppressNotify = false}) {
    if (_currentBranchIndex < _branchHistory.length - 1) {
      _currentBranchIndex++;
      if (!suppressNotify) notifyListeners();
      return currentBranch;
    }
    return null;
  }

  // 특정 분기점으로 이동
  BranchPoint? goToBranch(int index, {bool suppressNotify = false}) {
    if (index >= 0 && index < _branchHistory.length) {
      _currentBranchIndex = index;
      if (!suppressNotify) notifyListeners();
      return currentBranch;
    }
    return null;
  }

  // 조건 평가
  bool evaluateCondition(Map<String, dynamic> condition, GameState state) {
    return _evaluator.evaluateCondition(condition, state);
  }

  // 분기 이력 초기화
  void reset({bool suppressNotify = false}) {
    _branchHistory.clear();
    _currentBranchIndex = -1;
    if (!suppressNotify) notifyListeners();
  }
} 

// =========================
// 확장성 높은 런타임 동적 추가 시스템 예시
// =========================

/// 모든 게임 콘텐츠의 공통 인터페이스
abstract class GameContent {
  String get id;
}

/// 인카운터 예시
class Encounter implements GameContent {
  @override
  final String id;
  final String description;
  final Map<String, dynamic> conditions;
  Encounter({required this.id, required this.description, this.conditions = const {}});
}

/// 선택지 예시
class ContentChoice implements GameContent {
  @override
  final String id;
  final String text;
  final Map<String, dynamic> conditions;
  ContentChoice({required this.id, required this.text, this.conditions = const {}});
}

/// 아이템 예시
class Item implements GameContent {
  @override
  final String id;
  final String name;
  Item({required this.id, required this.name});
}

/// 공통 매니저 추상화
abstract class ContentManager<T extends GameContent> {
  final List<T> _contents = [];

  void add(T content) {
    if (_contents.any((c) => c.id == content.id)) return;
    _contents.add(content);
  }

  void remove(String id) {
    _contents.removeWhere((c) => c.id == id);
  }

  T? getById(String id) {
    for (final c in _contents) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<T> getAll() => List.unmodifiable(_contents);
}

/// 각 콘텐츠별 매니저
class TraitManager extends ContentManager<Trait> {}
class EncounterManager extends ContentManager<Encounter> {}
class ContentChoiceManager extends ContentManager<ContentChoice> {}
class ItemManager extends ContentManager<Item> {}

// ❌ Player 클래스 완전 제거 - character_models.dart의 Player 사용