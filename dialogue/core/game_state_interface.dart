/// 게임 상태 인터페이스
/// 
/// 다이얼로그 시스템이 게임 상태와 상호작용하기 위한 추상 인터페이스입니다.
/// 의존성 역전 원칙(Dependency Inversion Principle)을 적용하여
/// 다이얼로그 시스템이 구체적인 게임 상태 구현에 의존하지 않도록 합니다.
import 'package:flutter/foundation.dart';

/// 게임 상태 읽기 인터페이스
abstract class IGameStateReader {
  /// 스탯 값 조회
  int? getStat(String statName);
  
  /// 모든 스탯 조회
  Map<String, int> getAllStats();
  
  /// 아이템 소유 여부 확인
  bool hasItem(String itemId);
  
  /// 모든 아이템 조회
  List<String> getAllItems();
  
  /// 플래그 값 조회
  bool? getFlag(String flagName);
  
  /// 모든 플래그 조회
  Map<String, bool> getAllFlags();
  
  /// 현재 씬 ID 조회
  String getCurrentScene();
  
  /// 커스텀 데이터 조회 (확장용)
  dynamic getCustomData(String key);
  
  /// 게임 상태를 Map으로 변환 (조건 평가용)
  Map<String, dynamic> toMap();
}

/// 게임 상태 쓰기 인터페이스
abstract class IGameStateWriter {
  /// 스탯 변경
  void changeStat(String statName, int delta);
  
  /// 스탯 설정 (절대값)
  void setStat(String statName, int value);
  
  /// 여러 스탯 한번에 변경
  void changeStats(Map<String, int> deltas);
  
  /// 아이템 추가
  void addItem(String itemId);
  
  /// 아이템 제거
  void removeItem(String itemId);
  
  /// 여러 아이템 한번에 추가
  void addItems(List<String> itemIds);
  
  /// 플래그 설정
  void setFlag(String flagName, bool value);
  
  /// 여러 플래그 한번에 설정
  void setFlags(Map<String, bool> flags);
  
  /// 현재 씬 변경
  void setCurrentScene(String sceneId);
  
  /// 커스텀 데이터 설정 (확장용)
  void setCustomData(String key, dynamic value);
}

/// 게임 상태 전체 인터페이스 (읽기 + 쓰기)
abstract class IGameState implements IGameStateReader, IGameStateWriter {
  /// 트레잇 목록
  ///
  /// - 트레잇은 문자열 ID의 집합이며, 포함 여부만 의미를 가집니다.
  /// - 정책2(레거시 SSOT)에서는 traits의 단일 진실이 레거시(EventSystem/GameState)이며,
  ///   신규 엔진은 traits를 읽기 전용으로만 사용해야 합니다.
  Set<String> get traits;

  /// 트레잇 보유 여부
  bool hasTrait(String id);

  /// 트레잇 추가
  void addTrait(String id);

  /// 트레잇 제거
  void removeTrait(String id);

  /// 상태 스냅샷 생성 (저장용)
  Map<String, dynamic> createSnapshot();
  
  /// 스냅샷에서 상태 복원 (불러오기용)
  void restoreFromSnapshot(Map<String, dynamic> snapshot);
  
  /// 상태 초기화
  void reset();
}

/// 조건 평가자 인터페이스
abstract class IConditionEvaluator {
  /// 조건 평가
  /// 
  /// [condition] - 조건 데이터
  /// [gameState] - 게임 상태
  /// 
  /// 반환: 조건 충족 여부
  bool evaluate(Map<String, dynamic> condition, IGameStateReader gameState);
}

/// 효과 적용자 인터페이스
abstract class IEffectApplier {
  /// 효과 적용
  /// 
  /// [effect] - 효과 데이터
  /// [gameState] - 게임 상태
  /// 
  /// 반환: 적용 성공 여부
  bool apply(Map<String, dynamic> effect, IGameStateWriter gameState);
}

/// 기본 게임 상태 구현 (간단한 in-memory 구현)
class BasicGameState implements IGameState {
  final Map<String, int> _stats = {};
  final List<String> _items = [];
  final Map<String, bool> _flags = {};
  final Set<String> _traits = {};
  String _currentScene = '';
  final Map<String, dynamic> _customData = {};

  BasicGameState({
    Map<String, int>? initialStats,
    List<String>? initialItems,
    Map<String, bool>? initialFlags,
    Set<String>? initialTraits,
    String initialScene = '',
  }) {
    if (initialStats != null) _stats.addAll(initialStats);
    if (initialItems != null) _items.addAll(initialItems);
    if (initialFlags != null) _flags.addAll(initialFlags);
    if (initialTraits != null) _traits.addAll(initialTraits);
    _currentScene = initialScene;
  }

  // ========== 읽기 ==========

  @override
  int? getStat(String statName) => _stats[statName];

  @override
  Map<String, int> getAllStats() => Map.unmodifiable(_stats);

  @override
  bool hasItem(String itemId) => _items.contains(itemId);

  @override
  List<String> getAllItems() => List.unmodifiable(_items);

  @override
  bool? getFlag(String flagName) => _flags[flagName];

  @override
  Map<String, bool> getAllFlags() => Map.unmodifiable(_flags);

  @override
  String getCurrentScene() => _currentScene;

  @override
  dynamic getCustomData(String key) => _customData[key];

  @override
  Map<String, dynamic> toMap() {
    return {
      'stats': Map<String, int>.from(_stats),
      'items': List<String>.from(_items),
      'flags': Map<String, bool>.from(_flags),
      // 조건 평가용: 단순 멤버십 체크를 위해 리스트로 제공
      'traits': List<String>.from(_traits),
      'currentScene': _currentScene,
      'custom': Map<String, dynamic>.from(_customData),
    };
  }

  // ========== 쓰기 ==========

  @override
  void changeStat(String statName, int delta) {
    _stats[statName] = (_stats[statName] ?? 0) + delta;
  }

  @override
  void setStat(String statName, int value) {
    _stats[statName] = value;
  }

  @override
  void changeStats(Map<String, int> deltas) {
    deltas.forEach((name, delta) {
      changeStat(name, delta);
    });
  }

  @override
  void addItem(String itemId) {
    if (!_items.contains(itemId)) {
      _items.add(itemId);
    }
  }

  @override
  void removeItem(String itemId) {
    _items.remove(itemId);
  }

  @override
  void addItems(List<String> itemIds) {
    for (final item in itemIds) {
      addItem(item);
    }
  }

  @override
  void setFlag(String flagName, bool value) {
    _flags[flagName] = value;
  }

  @override
  void setFlags(Map<String, bool> flags) {
    _flags.addAll(flags);
  }

  @override
  void setCurrentScene(String sceneId) {
    _currentScene = sceneId;
  }

  @override
  void setCustomData(String key, dynamic value) {
    _customData[key] = value;
  }

  // ========== 트레잇 ==========

  @override
  Set<String> get traits => Set.unmodifiable(_traits);

  @override
  bool hasTrait(String id) => _traits.contains(id);

  @override
  void addTrait(String id) {
    _traits.add(id);
  }

  @override
  void removeTrait(String id) {
    _traits.remove(id);
  }

  // ========== 스냅샷 ==========

  @override
  Map<String, dynamic> createSnapshot() {
    return toMap();
  }

  @override
  void restoreFromSnapshot(Map<String, dynamic> snapshot) {
    _stats.clear();
    _items.clear();
    _flags.clear();
    _traits.clear();
    _customData.clear();

    if (snapshot['stats'] is Map) {
      _stats.addAll(Map<String, int>.from(snapshot['stats'] as Map));
    }
    if (snapshot['items'] is List) {
      _items.addAll(List<String>.from(snapshot['items'] as List));
    }
    if (snapshot['flags'] is Map) {
      _flags.addAll(Map<String, bool>.from(snapshot['flags'] as Map));
    }
    // 하위 호환: 구버전 스냅샷에는 traits가 없을 수 있음 -> 기본값 빈 Set
    if (snapshot['traits'] is List) {
      _traits.addAll(List<String>.from(snapshot['traits'] as List));
    }
    if (snapshot['currentScene'] is String) {
      _currentScene = snapshot['currentScene'] as String;
    }
    if (snapshot['custom'] is Map) {
      _customData.addAll(Map<String, dynamic>.from(snapshot['custom'] as Map));
    }
  }

  @override
  void reset() {
    _stats.clear();
    _items.clear();
    _flags.clear();
    _traits.clear();
    _currentScene = '';
    _customData.clear();
  }
}

/// 레거시 EventSystem 어댑터 (기존 시스템과 호환)
/// 
/// 기존의 EventSystem.state를 IGameState 인터페이스로 감쌉니다.
class LegacyGameStateAdapter implements IGameState {
  final dynamic _legacyState; // EventSystem의 GameState

  LegacyGameStateAdapter(this._legacyState);

  @override
  int? getStat(String statName) {
    final stats = _legacyState.stats as Map?;
    return stats?[statName] as int?;
  }

  @override
  Map<String, int> getAllStats() {
    return Map<String, int>.from(_legacyState.stats as Map? ?? {});
  }

  @override
  bool hasItem(String itemId) {
    final items = _legacyState.items as List?;
    return items?.contains(itemId) ?? false;
  }

  @override
  List<String> getAllItems() {
    return List<String>.from(_legacyState.items as List? ?? []);
  }

  @override
  bool? getFlag(String flagName) {
    final flags = _legacyState.flags as Map?;
    return flags?[flagName] as bool?;
  }

  @override
  Map<String, bool> getAllFlags() {
    return Map<String, bool>.from(_legacyState.flags as Map? ?? {});
  }

  @override
  String getCurrentScene() {
    return _legacyState.currentScene as String? ?? '';
  }

  @override
  dynamic getCustomData(String key) {
    return null; // 레거시는 커스텀 데이터 미지원
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'stats': getAllStats(),
      'items': getAllItems(),
      'flags': getAllFlags(),
      // policy2: traits SSOT는 레거시 GameState.traits 입니다.
      'traits': _getLegacyTraitsList(),
      'currentScene': getCurrentScene(),
    };
  }

  // ========== 트레잇 ==========

  List<String> _getLegacyTraitsList() {
    final raw = _legacyState.traits;
    if (raw is List) {
      return raw.whereType<String>().toList();
    }
    return const <String>[];
  }

  /// policy2(레거시 SSOT):
  /// - 신규 엔진은 traits를 "읽기 전용"으로만 사용합니다.
  /// - traits의 단일 진실은 레거시 EventSystem/GameState 이므로, in-memory traits 저장소를 두지 않습니다.
  @override
  Set<String> get traits => Set.unmodifiable(_getLegacyTraitsList().toSet());

  @override
  bool hasTrait(String id) => _getLegacyTraitsList().contains(id);

  @override
  void addTrait(String id) {
    // 신규 엔진이 traits를 직접 수정하면 SSOT가 깨집니다.
    throw StateError(
      'policy2 violation: LegacyGameStateAdapter.addTrait("$id") is not allowed. '
      'Traits SSOT is legacy(EventSystem/GameState). '
      'Forward add_trait via a legacy event hook (e.g., customEvent {event_type:"add_trait", id}).',
    );
  }

  @override
  void removeTrait(String id) {
    // 신규 엔진이 traits를 직접 수정하면 SSOT가 깨집니다.
    throw StateError(
      'policy2 violation: LegacyGameStateAdapter.removeTrait("$id") is not allowed. '
      'Traits SSOT is legacy(EventSystem/GameState). '
      'Forward remove_trait via a legacy event hook (e.g., customEvent {event_type:"remove_trait", id}).',
    );
  }

  @override
  void changeStat(String statName, int delta) {
    // 레거시 시스템에서는 이벤트 발생으로 처리
    throw UnimplementedError('Use legacy EventSystem to modify state');
  }

  @override
  void setStat(String statName, int value) {
    throw UnimplementedError('Use legacy EventSystem to modify state');
  }

  @override
  void changeStats(Map<String, int> deltas) {
    throw UnimplementedError('Use legacy EventSystem to modify state');
  }

  @override
  void addItem(String itemId) {
    throw UnimplementedError('Use legacy EventSystem to modify state');
  }

  @override
  void removeItem(String itemId) {
    throw UnimplementedError('Use legacy EventSystem to modify state');
  }

  @override
  void addItems(List<String> itemIds) {
    throw UnimplementedError('Use legacy EventSystem to modify state');
  }

  @override
  void setFlag(String flagName, bool value) {
    throw UnimplementedError('Use legacy EventSystem to modify state');
  }

  @override
  void setFlags(Map<String, bool> flags) {
    throw UnimplementedError('Use legacy EventSystem to modify state');
  }

  @override
  void setCurrentScene(String sceneId) {
    throw UnimplementedError('Use legacy EventSystem to modify state');
  }

  @override
  void setCustomData(String key, dynamic value) {
    throw UnimplementedError('Use legacy EventSystem to modify state');
  }

  @override
  Map<String, dynamic> createSnapshot() => toMap();

  @override
  void restoreFromSnapshot(Map<String, dynamic> snapshot) {
    // policy2(레거시 SSOT): 스냅샷 복원은 레거시 시스템에서 수행되어야 합니다.
    // 이 어댑터는 레거시 상태를 "읽기"만 하므로, 여기서 어떠한 상태도 세팅하지 않습니다.
    // (신규 엔진 스냅샷/restore가 존재하더라도 traits를 in-memory로 주입하는 것을 금지)
    debugPrint(
      '[LegacyGameStateAdapter] restoreFromSnapshot ignored (policy2: legacy SSOT). '
      'Expected legacy state to be restored externally.',
    );
  }

  @override
  void reset() {
    throw UnimplementedError('Use legacy EventSystem to reset state');
  }
}








