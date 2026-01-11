import 'package:flutter/foundation.dart';
import 'dart:async';
void _esWarn(String message) {
  debugPrint('[EventSystem] $message');
}

// NOTE(maint): 2025-12-21 리팩터링(레거시 대화/분기 엔진 안정화)
// - 왜: 로드/분기복원 시 stats/flags/items가 addAll(merge)로 누적될 수 있는 구조였음.
// - 무엇: SET_STATS/SET_FLAGS/SET_ITEMS/SET_TRAITS 등 "replace semantics" 이벤트를 추가하고,
//   로드/복원에서만 이를 사용하도록 설계 경계를 명확히 함.
// - 호환성: 기존 이벤트(ADD_ITEM/CHANGE_STAT/SET_FLAG/CHANGE_SCENE)는 기존 의미(증분/병합)를 유지.

/// 이벤트 관리자 클래스
@Deprecated('Use core/state/events.dart의 GEvent 시스템으로 마이그레이션하세요. '
    'LegacyEventAdapter를 통해 호환성을 유지할 수 있습니다.')
class EventManager {
  static final EventManager _instance = EventManager._internal();
  
  factory EventManager() {
    return _instance;
  }
  
  EventManager._internal();

  final List<Function(GameEvent)> _listeners = [];

  void addEventListener(Function(GameEvent) listener) {
    _listeners.add(listener);
  }

  void removeEventListener(Function(GameEvent) listener) {
    _listeners.remove(listener);
  }

  void dispatchEvent(GameEvent event) {
    for (var listener in _listeners) {
      listener(event);
    }
  }
}

// 전역 이벤트 매니저 인스턴스
@Deprecated('Use core/state/events.dart의 GEvent 디스패치 시스템을 사용하세요.')
final eventManager = EventManager();

/// 게임에서 발생할 수 있는 이벤트 타입 정의
@Deprecated('Use core/state/events.dart의 GEvent 하위 클래스를 사용하세요.')
enum GameEventType {
  // 시간 기반 이벤트
  TICK,                // 매 틱마다 발생
  EFFECT_DURATION,     // 효과 지속시간 관련
  
  // 전투 이벤트
  DAMAGE_DEALT,        // 데미지를 줌
  DAMAGE_TAKEN,        // 데미지를 받음
  HEAL,                // 힐링
  CRITICAL_HIT,        // 치명타 발생
  
  // 상태 효과 이벤트
  EFFECT_APPLIED,      // 효과 적용
  EFFECT_REMOVED,      // 효과 제거
  EFFECT_STACK_CHANGED,// 스택 변화
  
  // 자원 관련 이벤트
  MANA_CONSUME,        // 마나 소비
  MANA_GAIN,          // 마나 획득
  
  // 아이템 관련 이벤트
  ITEM_USE,           // 아이템 사용
  ITEM_COOLDOWN,      // 아이템 쿨다운
  
  // 기타 이벤트
  // ⚠️ MERGE events vs REPLACE events
  // - MERGE(게임플레이): ADD_ITEM/REMOVE_ITEM/CHANGE_STAT/SET_FLAG/CHANGE_SCENE 등 "증분/병합" 의미
  // - REPLACE(복원 전용): SET_* 는 load/restore/rollback 스냅샷을 "교체"할 때만 사용 (누적 방지)
  ADD_ITEM,      // 아이템 추가
  REMOVE_ITEM,   // 아이템 제거
  CHANGE_STAT,   // 스탯 변경
  SET_FLAG,      // 플래그(상태) 설정
  CHANGE_SCENE,  // 씬 변경
  STAMINA_CONSUMED,
  STAMINA_RECOVERED,

  /* ────────────────✨ 무기 자동-사용 관련 새 이벤트 ✨─────────────── */
  WEAPON_QUEUED,     // 스태미나 부족으로 대기열에 추가
  WEAPON_AUTO_USED,  // 회복 후 자동 사용됨
  WEAPON_CANCELLED,  // 대기열에서 취소됨

  /* 🩸 체력 변화 이벤트 추가 */
  HEALTH_CHANGED,   // ✅ 새 이벤트

  // ====== Legacy Dialogue/Branch Engine: Replace semantics (load/restore only) ======
  SET_ITEMS,        // items를 스냅샷으로 "교체"
  SET_STATS,        // stats를 스냅샷으로 "교체"
  SET_FLAGS,        // flags를 스냅샷으로 "교체"
  SET_TRAITS,       // traits를 스냅샷으로 "교체"
  SET_SCENE,        // currentScene을 스냅샷으로 "교체" (빈 문자열 포함)
  ADD_TRAIT,        // traits에 단일 trait 추가
  REMOVE_TRAIT,     // traits에서 단일 trait 제거
}

/// 게임 이벤트를 표현하는 클래스
@Deprecated('Use core/state/events.dart의 GEvent 하위 클래스를 사용하세요.')
class GameEvent {
  final GameEventType type;
  final Map<String, dynamic> data;
  final double timestamp;

  GameEvent({
    required this.type,
    required this.data,
  }) : timestamp = DateTime.now().millisecondsSinceEpoch / 1000.0;
}

/// 게임 상태를 관리하는 클래스
@Deprecated('Use core/state/game_state.dart의 GameVM을 사용하세요.')
class GameState {
  final Map<String, int> stats;
  final List<String> items;
  final Map<String, bool> flags;
  final String currentScene;
  /// 플레이어가 보유한 특성 ID 목록
  final List<String> traits;

  const GameState({
    required this.stats,
    required this.items,
    required this.flags,
    required this.currentScene,
    this.traits = const [],
  });

  // 새로운 상태를 생성하는 팩토리 메서드
  GameState copyWith({
    Map<String, int>? stats,
    List<String>? items,
    Map<String, bool>? flags,
    String? currentScene,
    List<String>? traits,
  }) {
    return GameState(
      stats: stats ?? this.stats,
      items: items ?? this.items,
      flags: flags ?? this.flags,
      currentScene: (currentScene == null || currentScene.isEmpty)
          ? this.currentScene
          : currentScene,
      traits: traits ?? this.traits,
    );
  }
}

/// 이벤트 처리를 담당하는 클래스
@Deprecated('Use core/state/reducer.dart의 reduce 함수를 사용하세요.')
class EventProcessor {
  // 이벤트를 처리하고 새로운 게임 상태를 반환
  GameState processEvent(GameEvent event, GameState currentState) {
    switch (event.type) {
      case GameEventType.ADD_ITEM:
        if (event.data.containsKey('item')) {
          final item = event.data['item'] as String;
          final newItems = List<String>.from(currentState.items)..add(item);
          return currentState.copyWith(items: newItems);
        } else if (event.data.containsKey('items')) {
          final items = event.data['items'] as List<String>;
          final newItems = List<String>.from(currentState.items)..addAll(items);
          return currentState.copyWith(items: newItems);
        }
        return currentState;

      case GameEventType.SET_ITEMS: {
        final raw = event.data['items'];
        if (raw is List) {
          final list = raw.whereType<String>().toList();
          if (list.length != raw.length) {
            _esWarn('SET_ITEMS.items contains non-String elements: $raw');
          }
          if (kDebugMode) {
            debugPrint('[EventSystem] SET_ITEMS replace=true count=${list.length}');
          }
          return currentState.copyWith(items: List<String>.from(list));
        }
        _esWarn('SET_ITEMS requires {items: List<String>}, got: ${event.data}');
        return currentState;
      }

      case GameEventType.REMOVE_ITEM:
        if (event.data.containsKey('item')) {
          final item = event.data['item'] as String;
          final newItems = List<String>.from(currentState.items)..remove(item);
          return currentState.copyWith(items: newItems);
        } else if (event.data.containsKey('items')) {
          final items = event.data['items'] as List<String>;
          final newItems = List<String>.from(currentState.items)
            ..removeWhere((item) => items.contains(item));
          return currentState.copyWith(items: newItems);
        }
        return currentState;

      case GameEventType.CHANGE_STAT:
        if (event.data.containsKey('stat') && event.data.containsKey('value')) {
          final stat = event.data['stat'];
          final value = event.data['value'];
          if (stat is String && value is int) {
            final newStats = Map<String, int>.from(currentState.stats);
            newStats[stat] = (newStats[stat] ?? 0) + value;
            return currentState.copyWith(stats: newStats);
          } else {
            _esWarn('CHANGE_STAT requires {stat:String, value:int}, got: ${event.data}');
            return currentState;
          }
        } else if (event.data.containsKey('stats')) {
          final stats = event.data['stats'];
          if (stats is Map) {
            final coerced = <String, int>{};
            stats.forEach((k, v) {
              if (k is String && v is num) {
                coerced[k] = v.toInt();
              } else {
                _esWarn('Invalid stats entry in CHANGE_STAT: $k -> $v');
              }
            });
            final newStats = Map<String, int>.from(currentState.stats)..addAll(coerced);
            return currentState.copyWith(stats: newStats);
          } else {
            _esWarn('CHANGE_STAT.stats must be Map, got: $stats');
          }
        }
        return currentState;

      case GameEventType.SET_STATS: {
        final raw = event.data['stats'];
        if (raw is Map) {
          final coerced = <String, int>{};
          raw.forEach((k, v) {
            if (k is String && v is num) {
              coerced[k] = v.toInt();
            } else {
              _esWarn('Invalid stats entry in SET_STATS: $k -> $v');
            }
          });
          if (kDebugMode) {
            debugPrint('[EventSystem] SET_STATS replace=true count=${coerced.length}');
          }
          return currentState.copyWith(stats: Map<String, int>.from(coerced));
        }
        _esWarn('SET_STATS requires {stats: Map<String,int>}, got: ${event.data}');
        return currentState;
      }

      case GameEventType.SET_FLAG:
        if (event.data.containsKey('flag') && event.data.containsKey('value')) {
          final flag = event.data['flag'];
          final value = event.data['value'];
          if (flag is String && value is bool) {
            final newFlags = Map<String, bool>.from(currentState.flags);
            newFlags[flag] = value;
            return currentState.copyWith(flags: newFlags);
          } else {
            _esWarn('SET_FLAG requires {flag:String, value:bool}, got: ${event.data}');
            return currentState;
          }
        } else if (event.data.containsKey('flags')) {
          final flags = event.data['flags'];
          if (flags is Map) {
            final coerced = <String, bool>{};
            flags.forEach((k, v) {
              if (k is String && v is bool) {
                coerced[k] = v;
              } else {
                _esWarn('Invalid flags entry in SET_FLAG: $k -> $v');
              }
            });
            final newFlags = Map<String, bool>.from(currentState.flags)..addAll(coerced);
            return currentState.copyWith(flags: newFlags);
          } else {
            _esWarn('SET_FLAG.flags must be Map, got: $flags');
          }
        }
        return currentState;

      case GameEventType.SET_FLAGS: {
        final raw = event.data['flags'];
        if (raw is Map) {
          final coerced = <String, bool>{};
          raw.forEach((k, v) {
            if (k is String && v is bool) {
              coerced[k] = v;
            } else {
              _esWarn('Invalid flags entry in SET_FLAGS: $k -> $v');
            }
          });
          if (kDebugMode) {
            debugPrint('[EventSystem] SET_FLAGS replace=true count=${coerced.length}');
          }
          return currentState.copyWith(flags: Map<String, bool>.from(coerced));
        }
        _esWarn('SET_FLAGS requires {flags: Map<String,bool>}, got: ${event.data}');
        return currentState;
      }

      case GameEventType.SET_TRAITS: {
        final raw = event.data['traits'];
        if (raw is List) {
          final list = raw.whereType<String>().toList();
          if (list.length != raw.length) {
            _esWarn('SET_TRAITS.traits contains non-String elements: $raw');
          }
          if (kDebugMode) {
            debugPrint('[EventSystem] SET_TRAITS replace=true count=${list.length}');
          }
          return currentState.copyWith(traits: List<String>.from(list));
        }
        _esWarn('SET_TRAITS requires {traits: List<String>}, got: ${event.data}');
        return currentState;
      }

      case GameEventType.SET_SCENE: {
        final raw = event.data['scene'];
        if (raw is String) {
          if (kDebugMode) {
            debugPrint('[EventSystem] SET_SCENE replace=true scene="${raw}"');
          }
          // GameState.copyWith는 빈 문자열을 무시하므로(가드), 명시적으로 새 인스턴스를 구성합니다.
          return GameState(
            stats: currentState.stats,
            items: currentState.items,
            flags: currentState.flags,
            currentScene: raw,
            traits: currentState.traits,
          );
        }
        _esWarn('SET_SCENE requires {scene: String}, got: ${event.data}');
        return currentState;
      }

      case GameEventType.ADD_TRAIT: {
        final raw = event.data['trait'];
        if (raw is String && raw.isNotEmpty) {
          final next = List<String>.from(currentState.traits);
          if (!next.contains(raw)) next.add(raw);
          return currentState.copyWith(traits: next);
        }
        _esWarn('ADD_TRAIT requires {trait: String}, got: ${event.data}');
        return currentState;
      }

      case GameEventType.REMOVE_TRAIT: {
        final raw = event.data['trait'];
        if (raw is String && raw.isNotEmpty) {
          final next = List<String>.from(currentState.traits)..removeWhere((t) => t == raw);
          return currentState.copyWith(traits: next);
        }
        _esWarn('REMOVE_TRAIT requires {trait: String}, got: ${event.data}');
        return currentState;
      }

      case GameEventType.CHANGE_SCENE:
        final scene = event.data['scene'];
        if (scene is String && scene.isNotEmpty) {
          return currentState.copyWith(currentScene: scene);
        } else {
          _esWarn('CHANGE_SCENE.scene must be non-empty String, got: $scene');
          return currentState;
        }

      case GameEventType.TICK:
      case GameEventType.EFFECT_DURATION:
      case GameEventType.DAMAGE_DEALT:
      case GameEventType.DAMAGE_TAKEN:
      case GameEventType.HEAL:
      case GameEventType.CRITICAL_HIT:
      case GameEventType.EFFECT_APPLIED:
      case GameEventType.EFFECT_REMOVED:
      case GameEventType.EFFECT_STACK_CHANGED:
      case GameEventType.MANA_CONSUME:
      case GameEventType.MANA_GAIN:
      case GameEventType.ITEM_USE:
      case GameEventType.ITEM_COOLDOWN:
      case GameEventType.STAMINA_CONSUMED:
      case GameEventType.STAMINA_RECOVERED:
      case GameEventType.HEALTH_CHANGED:        // ✅ switch 문에도 추가
        // 이러한 이벤트들은 상태를 직접 변경하지 않고, 이벤트 알림용으로만 사용됨
        return currentState;

      /* ────────────────✨ 새 이벤트는 상태 변경 없음 ✨─────────────── */
      case GameEventType.WEAPON_QUEUED:
      case GameEventType.WEAPON_AUTO_USED:
      case GameEventType.WEAPON_CANCELLED:
        return currentState; // 알림용 이벤트
    }
  }

  // 여러 이벤트를 순차적으로 처리
  GameState processEvents(List<GameEvent> events, GameState initialState) {
    return events.fold(
      initialState,
      (state, event) => processEvent(event, state),
    );
  }

  // 조건에 따라 이벤트 실행 여부 결정
  bool checkEventCondition(Map<String, dynamic> condition, GameState state) {
    // 스탯 조건 체크
    final stats = condition['stats'] as Map<String, dynamic>?;
    if (stats != null) {
      for (final entry in stats.entries) {
        final statValue = state.stats[entry.key] ?? 0;
        final requiredValue = entry.value as int;
        if (statValue < requiredValue) return false;  // 명시적 bool 비교
      }
    }

    // 아이템 조건 체크
    final items = condition['items'] as List<dynamic>?;
    if (items != null) {
      for (final item in items) {
        final hasItem = state.items.contains(item);  // 명시적 bool 할당
        if (!hasItem) return false;
      }
    }

    // 플래그 조건 체크
    final flags = condition['flags'] as Map<String, dynamic>?;
    if (flags != null) {
      for (final entry in flags.entries) {
        final flagValue = state.flags[entry.key] ?? false;  // 기본값 명시
        final requiredValue = entry.value as bool;  // bool로 명시적 캐스팅
        if (flagValue != requiredValue) return false;  // bool 비교
      }
    }

    return true;
  }
}

/// 이벤트 시스템 전체를 관리하는 클래스
@Deprecated('Use core/game_controller.dart의 GameController를 사용하세요.')
class EventSystem extends ChangeNotifier {
  GameState _state;
  final EventProcessor _processor;
  bool _isBatching = false;

  EventSystem({
    GameState? initialState,
    EventProcessor? processor,
  }) : _state = initialState ?? GameState(
         stats: {},
         items: [],
         flags: {},
         // NOTE: 레거시 DialogueManager는 "씬을 명시적으로 setScene()할 때까지 빈 값"을 기대합니다.
         //       (초기 상태에서 자동으로 'start'를 진행시키지 않기 위해)
         currentScene: '',
       ),
       _processor = processor ?? EventProcessor();

  // 현재 게임 상태 getter
  GameState get state => _state;

  void _notifyIfNeeded() {
    if (!_isBatching) {
      notifyListeners();
    }
  }

  /// 여러 상태 변경을 배치로 처리
  /// notifyAtEnd=true 이고 현재가 최상위 배치일 때만 마지막에 한 번 알림
  void runInBatch(void Function() action, {bool notifyAtEnd = true}) {
    final wasBatching = _isBatching;
    final isTopLevel = !_isBatching;
    _isBatching = true;
    try {
      action();
    } finally {
      _isBatching = wasBatching;
    }
    if (notifyAtEnd && isTopLevel) {
      notifyListeners();
    }
  }

  // 단일 이벤트 처리
  void handleEvent(GameEvent event) {
    _state = _processor.processEvent(event, _state);
    _notifyIfNeeded();
  }

  // 조건부 이벤트 처리
  void handleConditionalEvent(GameEvent event, Map<String, dynamic> condition) {
    if (_processor.checkEventCondition(condition, _state)) {
      handleEvent(event);
    }
  }

  // 여러 이벤트 순차 처리
  void handleEvents(List<GameEvent> events) {
    _state = _processor.processEvents(events, _state);
    _notifyIfNeeded();
  }
}

@Deprecated('Use core/game_controller.dart의 GameController를 사용하세요.')
class GameLoop {
  GameLoop._internal();
  static final GameLoop _instance = GameLoop._internal();
  factory GameLoop() => _instance;

  Timer? _timer;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final List<Timer> _auxTimers = [];
  Duration _interval = const Duration(milliseconds: 33); // 기본 30FPS 근사

  bool get isRunning => _timer != null;

  // 이미 실행 중이면 false 반환(가드), 새로 시작하면 true
  bool start({
    required EventSystem eventSystem,
    Duration? interval,
    void Function()? onTick,
  }) {
    if (isRunning) return false;
    _interval = interval ?? _interval;

    _timer = Timer.periodic(_interval, (_) {
      try {
        if (onTick != null) {
          onTick();
        } else {
          eventSystem.handleEvent(
            GameEvent(type: GameEventType.TICK, data: const {}),
          );
        }
      } catch (e, s) {
        debugPrint('[GameLoop] Tick error: $e');
        debugPrint('$s');
      }
    });

    return true;
  }

  // 실행 중이 아니면 false 반환(가드), 정상 중지 시 true
  bool stop() {
    if (!isRunning) return false;

    _timer?.cancel();
    _timer = null;

    // 등록된 타이머/스트림 모두 안전 종료
    for (final t in _auxTimers) {
      try { t.cancel(); } catch (_) {}
    }
    _auxTimers.clear();

    for (final sub in _subscriptions) {
      try { sub.cancel(); } catch (_) {}
    }
    _subscriptions.clear();

    return true;
  }

  // 향후 외부에서 생성한 스트림/타이머를 루프에 등록해 일괄 종료 가능
  T registerSubscription<T extends StreamSubscription<dynamic>>(T sub) {
    _subscriptions.add(sub);
    return sub;
  }

  T registerTimer<T extends Timer>(T timer) {
    _auxTimers.add(timer);
    return timer;
  }
}

/*
/// 상태 효과 기본 클래스
abstract class StatusEffect {
  final String id;
  final String name;
  final EffectType type;
  int stacks;

  StatusEffect({
    required this.id,
    required this.name,
    required this.type,
    this.stacks = 0,
  });

  /// 매 틱마다 호출되는 로직
  void tick(Character target, double deltaTimeMs) {
    // 기본적으로 시간에 따른 처리는 없음
  }

  /// 효과가 만료되었는지 확인
  bool isExpired() => stacks <= 0;

  /// 효과에 따른 스탯 수정 값 반환
  CombatStats getEffectModifiers() => CombatStats();

  /// 스택 추가
  void addStacks(int amount) {
    if (amount < 0) return;
    stacks = math.min(stacks + amount, 100); // 최대 100스택
  }

  /// 스택 제거
  void removeStacks(int amount) {
    if (amount < 0) return;
    stacks = math.max(0, stacks - amount);
  }
}

/// 흡혈 효과
class LifestealEffect extends StatusEffect {
  static const int MAX_STACKS = 100;  // 최대 100스택

  LifestealEffect() : super(
    id: 'lifesteal',
    name: '흡혈',
    type: EffectType.BUFF
  );

  @override
  void tick(Character target, double deltaTimeMs) {
    // 시간에 따른 처리 없음 (스택 기반 지속)
  }

  @override
  bool isExpired() => stacks <= 0;  // 스택이 0이면 효과 소멸

  @override
  CombatStats getEffectModifiers() => CombatStats();  // 스탯 수정 없음

  @override
  void addStacks(int amount) {
    if (amount < 0) return;
    stacks = math.min(stacks + amount, MAX_STACKS);
  }

  void removeStacks(int amount) {
    if (amount < 0) return;
    stacks = math.max(0, stacks - amount);
  }

  /// 공격 적중시 호출되는 흡혈 처리
  void onHit(Character attacker) {
    if (stacks > 0) {
      attacker.heal(stacks);  // 스택당 1의 체력 회복
    }
  }
}

/// 행운 효과
class LuckEffect extends StatusEffect {
  static const int MAX_STACKS = 100; // 최대 100스택

  LuckEffect({this.initialStacks = 0}) : super(
    id: 'luck',
    name: '행운',
    type: EffectType.BUFF
  );

  final int initialStacks;

  @override
  void tick(Character target, double deltaTimeMs) {
    // 시간에 따른 스택 감소 로직 구현
    // 이 효과는 시간이 지나도 스택이 감소하지 않으므로 비워둠
  }

  @override
  bool isExpired() => stacks <= 0;

  @override
  CombatStats getEffectModifiers() {
    // 스택당 3%의 정확도(정수)와 1%의 치명타 확률(소수) 증가
    final int accuracy = (stacks * 3);  // 정확도는 정수값 (스택당 3 증가)
    final double criticalChance = stacks * 0.01;  // 치명타 확률은 소수값 (스택당 1% = 0.01 증가)
    return CombatStats(accuracy: accuracy, criticalChance: criticalChance);
  }

  @override
  void addStacks(int amount) {
    if (amount < 0) return;
    stacks = math.min(stacks + amount, MAX_STACKS);
  }

  @override
  void removeStacks(int amount) {
    if (amount < 0) return;
    stacks = math.max(0, stacks - amount);
  }
}

/// 회복 효과
class RegenerationEffect extends StatusEffect {
  static const int MAX_STACKS = 100; // 최대 100스택
  static const int HEAL_INTERVAL_MS = 2000; // 2초마다 회복

  RegenerationEffect({this.initialStacks = 0}) : super(
    id: 'regeneration',
    name: '회복',
    type: EffectType.BUFF
  );

  final int initialStacks;
  double _timeSinceLastHeal = 0; // 마지막 회복 이후 경과 시간

  @override
  void tick(Character target, double deltaTimeMs) {
    _timeSinceLastHeal += deltaTimeMs;

    // 2초마다 회복 처리
    if (_timeSinceLastHeal >= HEAL_INTERVAL_MS) {
      target.heal(stacks); // 현재 스택 수만큼 회복
      _timeSinceLastHeal = 0; // 타이머 리셋
    }
  }

  @override
  bool isExpired() => stacks <= 0;

  @override
  CombatStats getEffectModifiers() => CombatStats();

  @override
  void addStacks(int amount) {
    if (amount < 0) return;
    stacks = math.min(stacks + amount, MAX_STACKS);
  }

  @override
  void removeStacks(int amount) {
    if (amount < 0) return;
    stacks = math.max(0, stacks - amount);
  }
}
*/

/*  // Duplicate CombatSystem class is now commented out.
/// 전투 시스템 클래스
class CombatSystem {
  Character player;
  Character enemy;

  CombatSystem({
    required this.player,
    required this.enemy,
  });

  /// 전투 시작
  void startCombat() {
    // 전투 로직 구현
    // 플레이어와 적의 체력이 0이 될 때까지 번갈아가며 공격
    while (player.health > 0 && enemy.health > 0) {
      // 플레이어가 적을 공격
      enemy.takeDamage(player.attack);
      
      // 적이 살아있다면 반격
      if (enemy.health > 0) {
        player.takeDamage(enemy.attack);
      }
    }

    // 전투 종료 후 결과 처리
    if (player.health > 0) {
      print('플레이어 승리!');
    } else {
      print('적 승리!');
    }
  }
} */ 
