import 'dart:convert';
import 'dart:collection';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'event_system.dart';
import 'branch_system.dart';
import 'save_system.dart';
import 'inventory/inventory_system.dart';
import 'inventory/inventory_serialization.dart';
import 'core/character/character_models.dart';

void _dmWarn(String message) {
  debugPrint('[DialogueManager] $message');
}

// NOTE(maint): 2025-12-21 리팩터링(레거시 대화/분기/이벤트 엔진 안정화)
// - (B) 로드/분기복원 시 stats/flags/items가 addAll(merge)로 누적되는 문제를 구조적으로 방지:
//   복원 경로에서는 EventSystem의 SET_* 이벤트(교체 semantics)만 사용.
// - (C) 씬 SSOT: 씬 ID의 단일 진실은 `EventSystem.state.currentScene`.
// - (D) traits 일관성: traits는 GameState에 포함 + 이벤트로 설정 가능 + Player(세이브/로드)와 동기화.
// - (E) 확장 포인트: `Choice.metadata`를 추가해 Enhanced가 텍스트 추정 없이 표기/확장 가능.

/// 선택지를 표현하는 클래스
class Choice {
  final String id;
  final String text;
  final bool isEnabled;
  final Map<String, dynamic>? conditions;
  /// 선택지 표기/확장용 메타데이터 (read-only로 취급)
  /// - 예: {'skill_check': {'stat': 'strength', 'visibility': 'exact', ...}}
  final Map<String, dynamic>? metadata;

  const Choice({
    required this.id,
    required this.text,
    required this.isEnabled,
    this.conditions,
    this.metadata,
  });
}

class DialogueManager extends ChangeNotifier {
  final EventSystem _eventSystem;
  final BranchSystem _branchSystem;
  final SaveSystem _saveSystem;
  late Map<String, dynamic> _dialogueData;
  
  // 🎒 인벤토리 시스템 참조 (외부에서 설정)
  InventorySystem? _inventorySystem;
  
  // 🎭 플레이어 캐릭터 정보 (저장/로드를 위한 참조)
  Player? _currentPlayer;

  // ===== Raw immutable cache (성능 최적화) =====
  // - "raw는 불변" 보장을 위해, 캐시는 _deepImmutable() 결과(이미 불변화된 객체)만 저장합니다.
  // - 씬 SSOT는 EventSystem.state.currentScene이므로, sceneId가 바뀌면 캐시를 무효화합니다.
  String? _cachedRawSceneId;
  Map<String, dynamic>? _cachedSceneRawImmutable;
  final Map<String, Map<String, dynamic>> _cachedChoiceRawImmutableById = <String, Map<String, dynamic>>{};

  DialogueManager({
    EventSystem? eventSystem,
    BranchSystem? branchSystem,
    SaveSystem? saveSystem,
    InventorySystem? inventorySystem,
  }) : _eventSystem = eventSystem ?? EventSystem(),
       _branchSystem = branchSystem ?? BranchSystem(),
       _saveSystem = saveSystem ?? SaveSystem(
         saveFilePath: 'saves/save.json',
       ),
       _inventorySystem = inventorySystem {
    _dialogueData = {};
  }
  
  // 🆕 인벤토리 시스템 설정 (생성 후 주입용)
  void setInventorySystem(InventorySystem inventory) {
    _inventorySystem = inventory;
  }
  
  // 🆕 현재 플레이어 설정 (저장 전 호출)
  void setCurrentPlayer(Player? player) {
    _currentPlayer = player;
    // NOTE(policy): traits SSOT는 GameState.traits 입니다.
    // 초기화/로드 시에만 Player.traits -> GameState.traits "단방향" 주입을 허용합니다.
    _syncTraitsFromPlayer(player);
  }
  
  // 🆕 현재 플레이어 가져오기 (로드 후 사용)
  Player? getCurrentPlayer() {
    return _currentPlayer;
  }

  // 게임 상태 getter들
  Map<String, int> get playerStats => _eventSystem.state.stats;
  List<String> get playerItems => _eventSystem.state.items;
  Map<String, bool> get flags => _eventSystem.state.flags;
  String get currentScene => _eventSystem.state.currentScene;
  List<String> get traits => _eventSystem.state.traits;

  /// Player.traits(Trait 객체) -> GameState.traits(String id 리스트) 동기화
  /// 분기 조건(traits/has_trait)의 단일 입력을 GameState로 고정하기 위함.
  void _syncTraitsFromPlayer(Player? player) {
    final ids = (player?.traits ?? const <Trait>[]).map((t) => t.id).toList();
    _eventSystem.handleEvent(
      GameEvent(type: GameEventType.SET_TRAITS, data: {'traits': ids}),
    );
  }

  // ===== Restore/Load/Rollback: replace-only structural guard =====
  // Returned raw is immutable; modify a copy if needed.
  // (Enhanced는 raw를 읽기만 해야 하며, raw 참조를 통해 엔진 상태를 변경할 수 없어야 합니다.)
  dynamic _deepImmutable(dynamic value) {
    if (value is Map) {
      final copied = <String, dynamic>{};
      value.forEach((k, v) {
        if (k is String) {
          copied[k] = _deepImmutable(v);
        }
      });
      return UnmodifiableMapView<String, dynamic>(copied);
    }
    if (value is List) {
      return List.unmodifiable(value.map(_deepImmutable).toList());
    }
    return value;
  }

  /// restore/load/rollback 경로에서만 사용: 스냅샷을 "교체(replace-only)" 이벤트로만 적용합니다.
  /// - 여기 밖(게임플레이)에서는 기존 MERGE 이벤트(CHANGE_STAT/ADD_ITEM/SET_FLAG 등)를 그대로 사용합니다.
  void _applySnapshotReplaceOnly({
    required Map<String, int> stats,
    required List<String> items,
    required Map<String, bool> flags,
    required List<String> traits,
    required String scene,
  }) {
    _eventSystem.runInBatch(() {
      _eventSystem.handleEvents([
        GameEvent(type: GameEventType.SET_STATS, data: {'stats': stats}),
        GameEvent(type: GameEventType.SET_ITEMS, data: {'items': items}),
        GameEvent(type: GameEventType.SET_FLAGS, data: {'flags': flags}),
        GameEvent(type: GameEventType.SET_TRAITS, data: {'traits': traits}),
        GameEvent(type: GameEventType.SET_SCENE, data: {'scene': scene}),
      ]);
    }, notifyAtEnd: false);
  }

  Map<String, dynamic> _coerceJsonMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  DateTime _coerceTimestamp(dynamic raw) {
    if (raw is String) {
      try {
        return DateTime.parse(raw);
      } catch (_) {
        // fall through
      }
    }
    return DateTime.now();
  }

  void _invalidateRawCache() {
    _cachedRawSceneId = null;
    _cachedSceneRawImmutable = null;
    _cachedChoiceRawImmutableById.clear();
  }

  void _ensureRawCacheFreshForCurrentScene() {
    final sceneId = currentScene;
    if (_cachedRawSceneId != sceneId) {
      _cachedRawSceneId = sceneId;
      _cachedSceneRawImmutable = null;
      _cachedChoiceRawImmutableById.clear();
    }
  }
  
  // 분기 관련 getter들
  List<BranchPoint> get branchHistory => _branchSystem.branchHistory;
  BranchPoint? get currentBranch => _branchSystem.currentBranch;

  Future<void> loadDialogue(String jsonPath) async {
    try {
      final String jsonString = await rootBundle.loadString(jsonPath);
      final decoded = json.decode(jsonString);
      if (decoded is Map<String, dynamic>) {
        _dialogueData = decoded;
      } else {
        _dmWarn('Decoded dialogue is not a Map<String,dynamic>: $decoded');
        _dialogueData = {};
      }
      // 대화 데이터가 교체되면 raw 캐시가 오래된 참조를 들고 있을 수 있으므로 무효화
      _invalidateRawCache();
      notifyListeners();
    } catch (e, s) {
      _dmWarn('Failed to load dialogue from "$jsonPath": $e');
      debugPrint('$s');
      _dialogueData = {};
      _invalidateRawCache();
      notifyListeners();
    }
  }

  // 게임 저장
  Future<void> saveGame() async {
    // 🛡️ 전투 중에는 저장 금지 (전투 락 확인)
    if (_inventorySystem != null && _inventorySystem!.lockSystem.isLocked) {
      debugPrint('[DialogueManager] ⚠️ Cannot save during combat');
      throw StateError('전투 중에는 저장할 수 없습니다');
    }
    
    // 🎒 인벤토리 직렬화
    Map<String, dynamic>? inventoryJson;
    if (_inventorySystem != null) {
      try {
        inventoryJson = InventorySerialization.inventoryToJson(_inventorySystem!);
        debugPrint('[DialogueManager] ✓ Inventory serialized (${_inventorySystem!.placedItems.length} items)');
      } catch (e) {
        debugPrint('[DialogueManager] ⚠️ Failed to serialize inventory: $e');
        // 인벤토리 직렬화 실패 시에도 게임 상태는 저장
      }
    }
    
    // 🎭 플레이어 직렬화
    Map<String, dynamic>? playerJson;
    if (_currentPlayer != null) {
      try {
        playerJson = SaveData.playerToJson(_currentPlayer!);
        debugPrint('[DialogueManager] ✓ Player serialized (vitality: ${_currentPlayer!.vitality}, sanity: ${_currentPlayer!.sanity})');
      } catch (e) {
        debugPrint('[DialogueManager] ⚠️ Failed to serialize player: $e');
        // 플레이어 직렬화 실패 시에도 게임 상태는 저장
      }
    } else {
      debugPrint('[DialogueManager] ⚠️ No player data to save');
    }
    
    // 저장 데이터 생성 (인벤토리 + 플레이어 포함)
    final saveData = SaveData(
      timestamp: DateTime.now(),
      // SSOT: 씬은 EventSystem.state.currentScene이 단일 진실
      currentScene: currentScene,
      stats: _eventSystem.state.stats,
      items: _eventSystem.state.items,
      flags: _eventSystem.state.flags,
      branchHistory: [..._branchSystem.branchHistory.map((branch) => branch.gameState)],
      inventory: inventoryJson,  // 🎒 인벤토리 데이터
      player: playerJson,        // 🎭 플레이어 데이터
    );
    
    final root = saveData.toJson();
    // Risk2: traits SSOT = GameState.traits (조건/스냅샷/복원 모두 이 값을 기준으로 함)
    root['traits'] = List<String>.from(_eventSystem.state.traits);
    await _saveSystem.writeSaveRoot(root);
    
    debugPrint('[DialogueManager] ✅ Game saved successfully');
  }

  // 게임 불러오기
  Future<void> loadGame() async {
    // 🛡️ 전투 중에는 불러오기 금지
    if (_inventorySystem != null && _inventorySystem!.lockSystem.isLocked) {
      debugPrint('[DialogueManager] ⚠️ Cannot load during combat');
      throw StateError('전투 중에는 불러올 수 없습니다');
    }
    
    // Save I/O/마이그레이션/정규화는 SaveSystem 단일 책임입니다.
    final root = await _saveSystem.loadGameNormalizedRoot();
    if (root == null) {
      debugPrint('[DialogueManager] No save file found');
      throw StateError('저장 파일이 없습니다');
    }

    // SaveData (필수 필드 채움: 내부 로직 호환용)
    final saveData = SaveData(
      timestamp: _coerceTimestamp(root['timestamp']),
      currentScene: (root['currentScene'] is String) ? (root['currentScene'] as String) : '',
      stats: _coerceStats(root['stats']),
      items: _coerceStringList(root['items']),
      flags: _coerceFlags(root['flags']),
      branchHistory: (root['branchHistory'] is List)
          ? List<Map<String, dynamic>>.from(
              (root['branchHistory'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
            )
          : <Map<String, dynamic>>[],
      inventory: (root['inventory'] is Map) ? Map<String, dynamic>.from(root['inventory'] as Map) : null,
      player: (root['player'] is Map) ? Map<String, dynamic>.from(root['player'] as Map) : null,
    );

    // Risk4 + Risk1: restore/load는 replace-only 경로로만 적용
    final traits = _coerceStringList(root['traits']);
    _applySnapshotReplaceOnly(
      stats: saveData.stats,
      items: saveData.items,
      flags: saveData.flags,
      traits: traits,
      scene: saveData.currentScene,
    );

    // 로드 시점에는 씬/대화 raw 참조가 바뀌었을 수 있으므로 캐시 무효화
    _invalidateRawCache();
    
    // 🎒 인벤토리 복원
    if (_inventorySystem != null && saveData.inventory != null) {
      try {
        InventorySerialization.inventoryFromJson(
          saveData.inventory!,
          _inventorySystem!,
          throwOnError: false,  // 실패한 아이템은 스킵
        );
        debugPrint('[DialogueManager] ✓ Inventory restored (${_inventorySystem!.placedItems.length} items)');
      } catch (e, stackTrace) {
        debugPrint('[DialogueManager] ⚠️ Failed to restore inventory: $e');
        debugPrint('$stackTrace');
        // 인벤토리 복원 실패 시에도 게임 상태는 유지
      }
    } else if (saveData.inventory == null) {
      debugPrint('[DialogueManager] No inventory data in save file');
    }
    
    // 🎭 플레이어 복원
    if (saveData.player != null) {
      try {
        _currentPlayer = SaveData.playerFromJson(saveData.player);
        if (_currentPlayer != null) {
          debugPrint('[DialogueManager] ✓ Player restored (vitality: ${_currentPlayer!.vitality}, sanity: ${_currentPlayer!.sanity})');
          // NOTE(policy): traits SSOT는 GameState.traits 이며, 로드 시에는 save root의 traits를 신뢰합니다.
        } else {
          debugPrint('[DialogueManager] ⚠️ Failed to parse player data');
        }
      } catch (e, stackTrace) {
        debugPrint('[DialogueManager] ⚠️ Failed to restore player: $e');
        debugPrint('$stackTrace');
        _currentPlayer = null;
        // 플레이어 복원 실패 시에도 게임 상태는 유지
      }
    } else {
      debugPrint('[DialogueManager] No player data in save file');
      _currentPlayer = null;
    }
    
    notifyListeners();
    debugPrint('[DialogueManager] ✅ Game loaded successfully');
  }

  // 저장 파일 삭제
  Future<void> deleteSave() async {
    await _saveSystem.deleteSave();
  }

  // 대화 데이터 안전 접근
  Map<String, dynamic>? get _safeDialogueData {
    try {
      return _dialogueData;
    } catch (e, s) {
      // 안전한 폴백: null 반환 + 오류 로깅
      debugPrint('DialogueManager._safeDialogueData 오류: $e');
      debugPrint('$s');
      return null;
    }
  }

  void setScene(String sceneId) {
    _setSceneInternal(sceneId);
    notifyListeners();
  }

  Map<String, dynamic>? showLine(String? choiceId) {
    final dialogueData = _safeDialogueData;
    if (dialogueData == null) return null;
    
    if (currentScene.isEmpty) {
      _dmWarn('currentSceneId is empty when showLine called');
      return null;
    }

    final scene = dialogueData[currentScene];
    if (scene == null) {
      _dmWarn('Scene not found for id=$currentScene');
      return null;
    }
    
    if (choiceId == null) {
      return scene['start'];
    } else {
      return scene['choices']?[choiceId];
    }
  }

  Map<String, dynamic>? _getCurrentNode() {
    final dialogueData = _safeDialogueData;
    if (dialogueData == null) return null;
    
    final scene = dialogueData[currentScene];
    if (scene == null) return null;
    return scene;
  }

  List<Choice> getChoices() {
    final currentNode = _getCurrentNode();
    if (currentNode == null || !currentNode.containsKey('choices')) {
      return [];
    }

    final choices = currentNode['choices'];
    if (choices is! Map<String, dynamic>) {
      _dmWarn('choices node is not a Map for scene=$currentScene: $choices');
      return [];
    }

    return [
      for (var entry in choices.entries)
        if (entry.value is Map<String, dynamic> &&
            entry.value['text'] is String &&
            (entry.value['conditions'] == null ||
             entry.value['conditions'] is Map<String, dynamic>))
          Choice(
            id: entry.key,
            text: entry.value['text'] as String,
            isEnabled: _evaluateConditions(
              (entry.value['conditions'] is Map<String, dynamic>)
                ? entry.value['conditions'] as Map<String, dynamic>
                : <String, dynamic>{}
            ),
            conditions: entry.value['conditions'] as Map<String, dynamic>?,
            metadata: _extractChoiceMetadata(entry.value as Map<String, dynamic>),
          ),
    ];
  }

  /// 선택지 노드에서 "표기/확장용" metadata를 추출합니다.
  /// - legacy JSON에서는 `skill_check`가 choice 최상위에 있을 수 있어 이를 metadata로 승격합니다.
  /// - 반환 값은 shallow copy + read-only view 입니다(중첩 map/list deep-freeze는 하지 않음).
  Map<String, dynamic>? _extractChoiceMetadata(Map<String, dynamic> rawChoice) {
    final base = <String, dynamic>{};

    final rawMeta = rawChoice['metadata'];
    if (rawMeta is Map) {
      base.addAll(Map<String, dynamic>.from(rawMeta as Map));
    }

    final rawSkill = rawChoice['skill_check'];
    if (rawSkill is Map && !base.containsKey('skill_check')) {
      base['skill_check'] = Map<String, dynamic>.from(rawSkill as Map);
    }

    if (base.isEmpty) return null;
    return UnmodifiableMapView<String, dynamic>(base);
  }

  // ===== Extension points for EnhancedDialogueManager (read-only) =====
  @protected
  Map<String, dynamic>? getCurrentSceneRaw() {
    final dialogueData = _safeDialogueData;
    if (dialogueData == null) return null;
    _ensureRawCacheFreshForCurrentScene();
    final cached = _cachedSceneRawImmutable;
    if (cached != null) return cached;

    final raw = dialogueData[currentScene];
    if (raw is Map<String, dynamic>) {
      final immutable = _deepImmutable(raw) as Map<String, dynamic>;
      _cachedSceneRawImmutable = immutable;
      return immutable;
    }
    return null;
  }

  @protected
  Map<String, dynamic>? getChoiceRaw(String choiceId) {
    final dialogueData = _safeDialogueData;
    if (dialogueData == null) return null;
    _ensureRawCacheFreshForCurrentScene();

    final cached = _cachedChoiceRawImmutableById[choiceId];
    if (cached != null) return cached;

    final rawScene = dialogueData[currentScene];
    if (rawScene is! Map) return null;
    final choices = rawScene['choices'];
    if (choices is! Map) return null;
    final rawChoice = choices[choiceId];
    if (rawChoice is Map) {
      final immutable = _deepImmutable(rawChoice) as Map<String, dynamic>;
      _cachedChoiceRawImmutableById[choiceId] = immutable;
      return immutable;
    }
    return null;
  }

  bool _evaluateConditions(Map<String, dynamic> conditions) {
    if (conditions.isEmpty) return true;
    return _branchSystem.evaluateCondition(conditions, _eventSystem.state);
  }

  void handleChoice(String choiceId) {
    _eventSystem.runInBatch(() {
      final dialogueData = _safeDialogueData;
      if (dialogueData == null) return;
      
      final sceneId = currentScene;
      final scene = dialogueData[sceneId];
      if (scene == null) {
        _dmWarn('handleChoice on missing scene id=$sceneId');
        return;
      }

      final choicesNode = scene['choices'];
      if (choicesNode is! Map<String, dynamic>) {
        _dmWarn('Scene has no valid choices map: $choicesNode');
        return;
      }
      final choice = choicesNode[choiceId];
      if (choice is! Map<String, dynamic>) {
        _dmWarn('Choice not found or invalid for id=$choiceId');
        return;
      }

      // 분기점 저장
      final isBranch = choice['branch'] == true; // only strict true
      if (isBranch) {
        _branchSystem.addBranch(
          sceneId,
          choiceId,
          {
            'stats': Map<String, int>.from(_eventSystem.state.stats),
            'items': List<String>.from(_eventSystem.state.items),
            'flags': Map<String, bool>.from(_eventSystem.state.flags),
            'traits': List<String>.from(_eventSystem.state.traits),
            'scene': sceneId,
            'choiceId': choiceId,
          },
          suppressNotify: true,
        );
      }

      // 선택지의 이벤트 처리
      final rawEvents = choice['events'];
      if (rawEvents != null) {
        if (rawEvents is List) {
          _processEvents(rawEvents);
        } else {
          _dmWarn('choice.events must be a List, got: $rawEvents');
        }
      }

      // 다음 씬으로 이동 (내부 처리로 묶고, 마지막에 한 번만 알림)
      final nextScene = choice['next_scene'];
      if (nextScene != null) {
        if (nextScene is String && nextScene.isNotEmpty) {
          _setSceneInternal(nextScene);
        } else {
          _dmWarn('next_scene must be non-empty String, got: $nextScene');
        }
      }
    }, notifyAtEnd: false);

    // 중요한 선택 후 자동 저장 제거 (SaveSystem에 없음)
    
    notifyListeners();
  }

  // 이전 분기점으로 되돌아가기
  void goToPreviousBranch() {
    final previousBranch = _branchSystem.goToPreviousBranch(suppressNotify: true);
    if (previousBranch != null) {
      // 이전 상태 복원 (내부 상태만 갱신하고 마지막에 한 번만 알림)
      _restoreGameStateFromMapInternal(previousBranch.gameState);
      notifyListeners();
    }
  }

  // 다음 분기점으로 이동
  void goToNextBranch() {
    final nextBranch = _branchSystem.goToNextBranch(suppressNotify: true);
    if (nextBranch != null) {
      // 다음 상태 복원 (내부 상태만 갱신하고 마지막에 한 번만 알림)
      _restoreGameStateFromMapInternal(nextBranch.gameState);
      notifyListeners();
    }
  }

  // 특정 분기점으로 이동
  void goToBranch(int index) {
    final targetBranch = _branchSystem.goToBranch(index, suppressNotify: true);
    if (targetBranch != null) {
      // 상태 복원 (내부 상태만 갱신하고 마지막에 한 번만 알림)
      _restoreGameStateFromMapInternal(targetBranch.gameState);
      notifyListeners();
    }
  }

  // 게임 상태 복원 (SaveData)
  void _restoreGameState(SaveData saveData) {
    // Deprecated: 로드 경로는 _applySnapshotReplaceOnly 를 통해서만 복원합니다.
    _applySnapshotReplaceOnly(
      stats: saveData.stats,
      items: saveData.items,
      flags: saveData.flags,
      traits: _eventSystem.state.traits,
      scene: saveData.currentScene,
    );
  }

  // 게임 상태 복원 (Map)
  void _restoreGameStateFromMap(Map<String, dynamic> state) {
    _applySnapshotReplaceOnly(
      stats: _coerceStats(state['stats']),
      items: _coerceStringList(state['items']),
      flags: _coerceFlags(state['flags']),
      traits: _coerceStringList(state['traits']),
      scene: (state['scene'] is String) ? (state['scene'] as String) : '',
    );
  }

  void _processEvents(List<dynamic> events) {
    final gameEvents = events.map((event) {
      if (event is! Map<String, dynamic>) {
        _dmWarn('Event entry is not a Map: $event');
        return null;
      }
      final type = event['type'];
      final data = event['data'];
      if (type is! String) {
        _dmWarn('Event.type must be String: $type');
        return null;
      }
      if (data is! Map<String, dynamic>) {
        _dmWarn('Event.data must be Map<String,dynamic>: $data');
        return null;
      }
      try {
        return GameEvent(
          type: _getEventType(type),
          data: data,
        );
      } catch (e) {
        _dmWarn('Unknown event type "$type" skipped: $e');
        return null;
      }
    }).whereType<GameEvent>().toList();

    if (gameEvents.isNotEmpty) {
      _eventSystem.handleEvents(gameEvents);
    }
  }

  GameEventType _getEventType(String type) {
    switch (type) {
      case 'ADD_ITEM':
        return GameEventType.ADD_ITEM;
      case 'REMOVE_ITEM':
        return GameEventType.REMOVE_ITEM;
      case 'CHANGE_STAT':
        return GameEventType.CHANGE_STAT;
      case 'SET_FLAG':
        return GameEventType.SET_FLAG;
      case 'CHANGE_SCENE':
        return GameEventType.CHANGE_SCENE;
      case 'ADD_TRAIT':
        return GameEventType.ADD_TRAIT;
      case 'REMOVE_TRAIT':
        return GameEventType.REMOVE_TRAIT;
      default:
        throw ArgumentError('Unknown event type: $type');
    }
  }

  // 게임 상태 설정
  void setGameState({
    required Map<String, int> stats,
    required List<String> items,
    required Map<String, bool> flags,
    required String currentScene,
  }) {
    _setGameStateInternal(
      stats: stats,
      items: items,
      flags: flags,
      currentScene: currentScene,
      traits: _eventSystem.state.traits,
    );
    notifyListeners();
  }

  // 내부 전용: 씬 변경을 배치 처리로 묶고 알림은 하지 않음
  void _setSceneInternal(String sceneId) {
    _eventSystem.runInBatch(() {
      _eventSystem.handleEvent(
        GameEvent(
          type: GameEventType.CHANGE_SCENE,
          data: {'scene': sceneId},
        ),
      );

      // 씬 시작 시 이벤트 처리
      final dialogueData = _safeDialogueData;
      if (dialogueData == null) return;
      final scene = dialogueData[sceneId];
      if (scene == null) {
        _dmWarn('Scene not found for id=$sceneId');
        return;
      }
      final start = scene['start'];
      final startEvents = (start is Map<String, dynamic>) ? start['events'] : null;
      if (startEvents is List) {
        _processEvents(startEvents);
      } else if (startEvents != null) {
        _dmWarn('start.events must be a List, got: $startEvents');
      }
    }, notifyAtEnd: false);
  }

  // 내부 전용: 게임 상태 복원(맵) - 알림 없음
  void _restoreGameStateFromMapInternal(Map<String, dynamic> state) {
    _applySnapshotReplaceOnly(
      stats: _coerceStats(state['stats']),
      items: _coerceStringList(state['items']),
      flags: _coerceFlags(state['flags']),
      traits: _coerceStringList(state['traits']),
      scene: (state['scene'] is String) ? (state['scene'] as String) : '',
    );
  }

  // 내부 전용: 게임 상태 설정을 배치로 처리하고 알림은 하지 않음
  void _setGameStateInternal({
    required Map<String, int> stats,
    required List<String> items,
    required Map<String, bool> flags,
    required String currentScene,
    required List<String> traits,
  }) {
    _applySnapshotReplaceOnly(
      stats: stats,
      items: items,
      flags: flags,
      traits: traits,
      scene: currentScene,
    );
  }

  // ===== Helper coercion methods with logging =====
  Map<String, int> _coerceStats(dynamic raw) {
    if (raw is Map) {
      final result = <String, int>{};
      raw.forEach((key, value) {
        if (key is String && value is num) {
          result[key] = value.toInt();
        } else {
          _dmWarn('Invalid stat entry: $key -> $value');
        }
      });
      return result;
    }
    if (raw != null) _dmWarn('stats must be a Map, got: $raw');
    return <String, int>{};
  }

  Map<String, bool> _coerceFlags(dynamic raw) {
    if (raw is Map) {
      final result = <String, bool>{};
      raw.forEach((key, value) {
        if (key is String && value is bool) {
          result[key] = value;
        } else {
          _dmWarn('Invalid flag entry: $key -> $value');
        }
      });
      return result;
    }
    if (raw != null) _dmWarn('flags must be a Map, got: $raw');
    return <String, bool>{};
  }

  List<String> _coerceStringList(dynamic raw) {
    if (raw is List) {
      final list = raw.whereType<String>().toList();
      if (list.length != raw.length) {
        _dmWarn('List contains non-string elements: $raw');
      }
      return list;
    }
    if (raw != null) _dmWarn('Expected List<String>, got: $raw');
    return <String>[];
  }
} 