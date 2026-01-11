/// 다이얼로그 인터프리터
/// 
/// 다이얼로그 로직을 실제로 실행합니다:
/// - 조건 평가
/// - 효과 적용
/// - 씬 진행 제어
/// - 선택지 처리

import 'package:flutter/foundation.dart';
import 'dialogue_data.dart';
import 'dialogue_runtime.dart';
import 'game_state_interface.dart';

/// 인터프리터 에러
class InterpreterError implements Exception {
  final String message;
  final String? context;

  InterpreterError(this.message, {this.context});

  @override
  String toString() {
    final buffer = StringBuffer('InterpreterError: $message');
    if (context != null) buffer.write(' ($context)');
    return buffer.toString();
  }
}

/// 다이얼로그 인터프리터
class DialogueInterpreter {
  final IGameState gameState;
  
  /// 커스텀 조건 평가자 (확장용)
  final Map<String, bool Function(Map<String, dynamic>)> _customConditionEvaluators = {};
  
  /// 커스텀 효과 핸들러 (확장용)
  final Map<String, void Function(Map<String, dynamic>)> _customEffectHandlers = {};

  DialogueInterpreter({
    required this.gameState,
  });

  /// 커스텀 조건 평가자 등록
  void registerConditionEvaluator(
    String conditionType,
    bool Function(Map<String, dynamic>) evaluator,
  ) {
    _customConditionEvaluators[conditionType] = evaluator;
  }

  /// 커스텀 효과 핸들러 등록
  void registerEffectHandler(
    String effectType,
    void Function(Map<String, dynamic>) handler,
  ) {
    _customEffectHandlers[effectType] = handler;
  }

  // ========== 조건 평가 ==========

  /// 조건들이 모두 충족되는지 확인
  bool evaluateConditions(List<DialogueCondition> conditions) {
    if (conditions.isEmpty) return true;

    for (final condition in conditions) {
      if (!evaluateCondition(condition)) {
        return false;
      }
    }

    return true;
  }

  /// 개별 조건 평가
  bool evaluateCondition(DialogueCondition condition) {
    try {
      // 트레잇/커스텀 조건은 인터프리터 레벨에서 먼저 처리
      // (기존 DialogueCondition.evaluate 경로는 그대로 유지)
      if (condition.type == DialogueConditionType.custom) {
        final type = condition.data['type'] as String?;

        // built-in: has_trait
        if (type == 'has_trait') {
          final id = condition.data['id'] as String?;
          if (id == null) return false;
          return gameState.hasTrait(id);
        }

        // 확장 포인트: 외부에서 등록한 커스텀 평가자 사용
        if (type != null) {
          final evaluator = _customConditionEvaluators[type];
          if (evaluator != null) {
            return evaluator(condition.data);
          }
        }
      }

      // 기본: DialogueCondition이 자체적으로 evaluate를 가지고 있음
      return condition.evaluate(gameState.toMap());
    } catch (e) {
      debugPrint('[DialogueInterpreter] Condition evaluation error: $e');
      debugPrint('[DialogueInterpreter] Condition: $condition');
      return false;
    }
  }

  /// 노드가 표시 가능한지 확인
  bool canShowNode(DialogueNode node) {
    return evaluateConditions(node.conditions);
  }

  /// 선택지가 선택 가능한지 확인
  bool canSelectChoice(DialogueChoice choice) {
    if (!choice.enabled) return false;
    return evaluateConditions(choice.conditions);
  }

  /// 선택지 목록을 필터링 (조건 충족하는 것만)
  List<DialogueChoice> filterAvailableChoices(List<DialogueChoice> choices) {
    return choices.where((choice) => canSelectChoice(choice)).toList();
  }

  // ========== 효과 적용 ==========

  /// 효과들 적용
  void applyEffects(List<DialogueEffect> effects) {
    for (final effect in effects) {
      applyEffect(effect);
    }
  }

  /// 개별 효과 적용
  void applyEffect(DialogueEffect effect) {
    try {
      switch (effect.type) {
        case DialogueEffectType.changeStat:
          _applyStatChange(effect.data);
          break;

        case DialogueEffectType.addItem:
          _applyAddItem(effect.data);
          break;

        case DialogueEffectType.removeItem:
          _applyRemoveItem(effect.data);
          break;

        case DialogueEffectType.setFlag:
          _applySetFlag(effect.data);
          break;

        case DialogueEffectType.changeScene:
          _applyChangeScene(effect.data);
          break;

        case DialogueEffectType.customEvent:
          _applyCustomEvent(effect.data);
          break;
      }

      if (effect.description != null) {
        debugPrint('[DialogueInterpreter] Applied effect: ${effect.description}');
      }
    } catch (e) {
      debugPrint('[DialogueInterpreter] Effect application error: $e');
      debugPrint('[DialogueInterpreter] Effect: $effect');
    }
  }

  void _applyStatChange(Map<String, dynamic> data) {
    // 여러 스탯 변경: {'stats': {'hp': -5, 'xp': 10}}
    if (data.containsKey('stats')) {
      final stats = data['stats'] as Map<String, dynamic>;
      for (final entry in stats.entries) {
        final delta = entry.value is num ? (entry.value as num).toInt() : 0;
        gameState.changeStat(entry.key, delta);
      }
    }
    // 단일 스탯 변경: {'stat': 'hp', 'delta': -5}
    else if (data.containsKey('stat') && data.containsKey('delta')) {
      final stat = data['stat'] as String;
      final delta = (data['delta'] as num).toInt();
      gameState.changeStat(stat, delta);
    }
    // 절대값 설정: {'stat': 'hp', 'value': 100}
    else if (data.containsKey('stat') && data.containsKey('value')) {
      final stat = data['stat'] as String;
      final value = (data['value'] as num).toInt();
      gameState.setStat(stat, value);
    }
  }

  void _applyAddItem(Map<String, dynamic> data) {
    // 단일 아이템: {'item': 'key'}
    if (data.containsKey('item')) {
      final item = data['item'] as String;
      gameState.addItem(item);
    }
    // 여러 아이템: {'items': ['key', 'sword']}
    else if (data.containsKey('items')) {
      final items = data['items'] as List;
      for (final item in items) {
        gameState.addItem(item.toString());
      }
    }
  }

  void _applyRemoveItem(Map<String, dynamic> data) {
    // 단일 아이템: {'item': 'key'}
    if (data.containsKey('item')) {
      final item = data['item'] as String;
      gameState.removeItem(item);
    }
    // 여러 아이템: {'items': ['key', 'sword']}
    else if (data.containsKey('items')) {
      final items = data['items'] as List;
      for (final item in items) {
        gameState.removeItem(item.toString());
      }
    }
  }

  void _applySetFlag(Map<String, dynamic> data) {
    // 여러 플래그: {'flags': {'met_guard': true, 'door_open': false}}
    if (data.containsKey('flags')) {
      final flags = data['flags'] as Map<String, dynamic>;
      for (final entry in flags.entries) {
        final value = entry.value is bool ? entry.value as bool : true;
        gameState.setFlag(entry.key, value);
      }
    }
    // 단일 플래그: {'flag': 'met_guard', 'value': true}
    else if (data.containsKey('flag')) {
      final flag = data['flag'] as String;
      final value = data['value'] as bool? ?? true;
      gameState.setFlag(flag, value);
    }
  }

  void _applyChangeScene(Map<String, dynamic> data) {
    if (data.containsKey('scene')) {
      final scene = data['scene'] as String;
      gameState.setCurrentScene(scene);
    }
  }

  void _applyCustomEvent(Map<String, dynamic> data) {
    final eventType = data['event_type'] as String?;
    if (eventType == null) return;

    // policy2: traits SSOT는 레거시(EventSystem/GameState)입니다.
    // 신규 엔진은 traits를 읽기 전용(has_trait)으로만 사용하며,
    // add_trait/remove_trait은 "엔진 내부 적용"이 아니라 레거시 이벤트로 위임해야 합니다.
    //
    // 따라서 built-in trait mutation은 금지하고, 반드시 외부(레거시 브릿지) 핸들러로 전달합니다.
    if (eventType == 'add_trait' || eventType == 'remove_trait') {
      final handler = _customEffectHandlers[eventType];
      if (handler != null) {
        handler(data);
      } else {
        debugPrint(
          '[DialogueInterpreter] Missing legacy forward handler for "$eventType". '
          'Traits are read-only in new engine (policy2).',
        );
      }
      return;
    }

    final handler = _customEffectHandlers[eventType];
    if (handler != null) {
      handler(data);
    } else {
      debugPrint('[DialogueInterpreter] No handler for custom event: $eventType');
    }
  }

  // ========== 선택지 처리 ==========

  /// 선택지 선택 처리
  /// 
  /// [choice] - 선택된 선택지
  /// [runtime] - 런타임 상태
  /// 
  /// 반환: 다음 씬 ID (null이면 같은 씬 계속)
  String? handleChoiceSelection(DialogueChoice choice, DialogueRuntime runtime) {
    // 1. 선택 가능한지 확인
    if (!canSelectChoice(choice)) {
      throw InterpreterError(
        'Choice is not selectable',
        context: 'Choice: ${choice.id}',
      );
    }

    // 2. 선택 기록
    runtime.recordChoice(choice);

    // 3. 선택지의 효과 적용
    applyEffects(choice.effects);

    // 4. 다음 씬 결정
    String? nextSceneId;

    if (choice.jump != null) {
      // 다른 파일로 점프하는 경우는 별도 처리 필요
      if (choice.jump!.filePath != null) {
        // 파일 점프는 엔진 레벨에서 처리
        return null;
      }
      nextSceneId = choice.jump!.sceneId;
    } else if (choice.nextScene != null) {
      nextSceneId = choice.nextScene;
    } else if (choice.nextNode != null) {
      // 같은 씬 내 다른 노드로
      final nodeId = choice.nextNode!;
      final scene = runtime.getCurrentScene();
      if (scene != null) {
        final nodeIndex = scene.nodes.indexWhere((n) => n.id == nodeId);
        if (nodeIndex >= 0) {
          runtime.jumpToNode(nodeIndex);
        }
      }
      return null; // 같은 씬 유지
    }

    return nextSceneId;
  }

  // ========== 노드 실행 ==========

  /// 노드 진입 시 처리
  void onNodeEnter(DialogueNode node, DialogueRuntime runtime) {
    // 1. 노드 효과 적용
    applyEffects(node.effects);

    // 2. 텍스트 기록
    if (node.hasText) {
      runtime.recordText(
        node.text!,
        speaker: node.speaker,
      );
    }
  }

  /// 씬 진입 시 처리
  void onSceneEnter(DialogueScene scene, DialogueRuntime runtime) {
    // 씬 진입 효과 적용
    applyEffects(scene.onEnterEffects);
  }

  /// 씬 종료 시 처리
  void onSceneExit(DialogueScene scene, DialogueRuntime runtime) {
    // 씬 종료 효과 적용
    applyEffects(scene.onExitEffects);
  }

  // ========== 자동 진행 ==========

  /// 현재 노드를 자동으로 진행할 수 있는지 확인
  /// 
  /// 텍스트만 있고 선택지가 없으면 자동 진행 가능
  bool canAutoAdvance(DialogueNode node) {
    return node.hasText && !node.hasChoices && node.type == DialogueNodeType.say;
  }

  /// 자동 진행 (effect 노드 등 처리)
  /// 
  /// [runtime] - 런타임 상태
  /// 
  /// 반환: 진행된 노드 수
  int autoAdvance(DialogueRuntime runtime) {
    int advancedCount = 0;
    
    while (true) {
      final node = runtime.getCurrentNode();
      if (node == null) break;

      // 표시 조건 확인
      if (!canShowNode(node)) {
        // 조건 미충족이면 다음 노드로
        if (!runtime.advanceToNextNode()) break;
        advancedCount++;
        continue;
      }

      // effect 노드는 자동 실행
      if (node.type == DialogueNodeType.effect) {
        onNodeEnter(node, runtime);
        if (!runtime.advanceToNextNode()) break;
        advancedCount++;
        continue;
      }

      // ✅ jump 노드는 자동으로 첫 번째 선택지(jump) 실행
      // (DialogueEngine에서 자동 처리하도록 플래그 설정)
      if (node.type == DialogueNodeType.jump && node.hasChoices) {
        onNodeEnter(node, runtime);
        // jump 노드는 DialogueEngine에서 자동으로 처리
        // 여기서는 멈추지 않고 다음 노드로 진행하지 않음 (DialogueEngine이 처리)
        break;
      }

      // 텍스트나 선택지가 있으면 멈춤
      if (node.hasText || node.hasChoices) {
        break;
      }

      // 그 외는 스킵
      if (!runtime.advanceToNextNode()) break;
      advancedCount++;
    }

    return advancedCount;
  }

  // ========== 유틸리티 ==========

  /// 현재 표시 가능한 노드 찾기
  /// 
  /// [runtime] - 런타임 상태
  /// 
  /// 반환: 표시 가능한 첫 노드 (null이면 종료)
  DialogueNode? findDisplayableNode(DialogueRuntime runtime) {
    final scene = runtime.getCurrentScene();
    if (scene == null) return null;

    for (var i = runtime.currentNodeIndex; i < scene.nodes.length; i++) {
      final node = scene.nodes[i];
      if (canShowNode(node)) {
        return node;
      }
    }

    return null;
  }

  /// 씬의 모든 선택지 가져오기 (조건 평가 포함)
  List<DialogueChoice> getAvailableChoicesForScene(DialogueRuntime runtime) {
    final node = runtime.getCurrentNode();
    if (node == null) return [];

    return filterAvailableChoices(node.choices);
  }

  /// 디버그 정보
  String getDebugInfo() {
    return '''
DialogueInterpreter Debug Info:
  Game State:
    Stats: ${gameState.getAllStats()}
    Items: ${gameState.getAllItems()}
    Flags: ${gameState.getAllFlags()}
    Traits: ${gameState.traits.toList()}
    Current Scene: ${gameState.getCurrentScene()}
  Custom Evaluators: ${_customConditionEvaluators.keys.toList()}
  Custom Handlers: ${_customEffectHandlers.keys.toList()}
''';
  }
}








