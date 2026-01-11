/// 다이얼로그 엔진
/// 
/// 모든 다이얼로그 기능을 통합하는 고수준 API를 제공합니다.
/// UI 개발자는 이 클래스만 사용하면 됩니다.

import 'package:flutter/foundation.dart';
import 'core/dialogue_data.dart';
import 'core/dialogue_runtime.dart';
import 'core/dialogue_interpreter.dart';
import 'core/game_state_interface.dart';
import 'loaders/dialogue_loader.dart';
import 'plugins/dialogue_plugin.dart';
import 'plugins/plugin_manager.dart';

/// 엔진 상태
enum DialogueEngineState {
  /// 초기화되지 않음
  uninitialized,
  
  /// 대화 로딩 중
  loading,
  
  /// 준비 완료
  ready,
  
  /// 실행 중
  running,
  
  /// 일시정지
  paused,
  
  /// 종료됨
  ended,
  
  /// 에러
  error,
}

/// 현재 표시할 내용
class DialogueView {
  /// 표시할 텍스트 (null이면 선택지만)
  final String? text;
  
  /// 화자 이름
  final String? speaker;
  
  /// 선택지 목록
  final List<DialogueChoice> choices;
  
  /// 대화가 끝났는지
  final bool isEnded;
  
  /// 현재 씬 ID
  final String sceneId;
  
  /// 현재 노드 인덱스
  final int nodeIndex;

  const DialogueView({
    this.text,
    this.speaker,
    this.choices = const [],
    this.isEnded = false,
    required this.sceneId,
    required this.nodeIndex,
  });

  /// 텍스트가 있는지
  bool get hasText => text != null && text!.isNotEmpty;
  
  /// 선택지가 있는지
  bool get hasChoices => choices.isNotEmpty;
  
  /// 계속 진행 가능한지 (텍스트만 있고 선택지 없음)
  bool get canContinue => hasText && !hasChoices;

  @override
  String toString() {
    final parts = <String>[];
    if (speaker != null) parts.add('Speaker: $speaker');
    if (hasText) parts.add('Text: ${text!.substring(0, text!.length > 30 ? 30 : text!.length)}...');
    parts.add('Choices: ${choices.length}');
    parts.add('Scene: $sceneId:$nodeIndex');
    return 'DialogueView(${parts.join(', ')})';
  }
}

/// 다이얼로그 엔진 이벤트
abstract class DialogueEngineEvent {
  const DialogueEngineEvent();
}

class DialogueLoadedEvent extends DialogueEngineEvent {
  final String dialogueId;
  const DialogueLoadedEvent(this.dialogueId);
}

class DialogueStartedEvent extends DialogueEngineEvent {
  final String sceneId;
  const DialogueStartedEvent(this.sceneId);
}

class SceneChangedEvent extends DialogueEngineEvent {
  final String fromScene;
  final String toScene;
  const SceneChangedEvent(this.fromScene, this.toScene);
}

class ChoiceSelectedEvent extends DialogueEngineEvent {
  final DialogueChoice choice;
  const ChoiceSelectedEvent(this.choice);
}

class DialogueEndedEvent extends DialogueEngineEvent {
  const DialogueEndedEvent();
}

class DialogueErrorEvent extends DialogueEngineEvent {
  final Object error;
  final StackTrace? stackTrace;
  const DialogueErrorEvent(this.error, this.stackTrace);
}

/// 다이얼로그 엔진 (메인 퍼사드)
class DialogueEngine extends ChangeNotifier {
  final DialogueLoader loader;
  final IGameState gameState;
  final DialoguePluginManager pluginManager;
  
  DialogueRuntime? _runtime;
  DialogueInterpreter? _interpreter;
  DialogueEngineState _state = DialogueEngineState.uninitialized;
  Object? _lastError;

  /// 이벤트 리스너들
  final List<void Function(DialogueEngineEvent)> _eventListeners = [];

  DialogueEngine({
    DialogueLoader? loader,
    IGameState? gameState,
    DialoguePluginManager? pluginManager,
  })  : loader = loader ?? DialogueLoader.instance,
        gameState = gameState ?? BasicGameState(),
        pluginManager = pluginManager ?? DialoguePluginManager() {
    // 엔진 초기화 훅 실행
    _initializePlugins();
  }
  
  void _initializePlugins() {
    final context = DialoguePluginContext(this);
    pluginManager.executeHook('onEngineInit', (plugin) => plugin.onEngineInit(context));
  }

  /// 테스트 전용 생성자 (DO NOT USE IN PRODUCTION)
  @visibleForTesting
  DialogueEngine.forTesting({
    required this.loader,
    required this.gameState,
    DialoguePluginManager? pluginManager,
    DialogueRuntime? runtime,
    DialogueInterpreter? interpreter,
    DialogueEngineState? initialState,
  }) : pluginManager = pluginManager ?? DialoguePluginManager(),
       _runtime = runtime,
       _interpreter = interpreter,
       _state = initialState ?? DialogueEngineState.uninitialized;

  /// 현재 상태
  DialogueEngineState get state => _state;
  
  /// 런타임 (읽기 전용)
  DialogueRuntime? get runtime => _runtime;
  
  /// 인터프리터 (읽기 전용)
  DialogueInterpreter? get interpreter => _interpreter;
  
  /// 마지막 에러
  Object? get lastError => _lastError;
  
  /// 대화가 로드되어 있는지
  bool get isLoaded => _runtime != null;
  
  /// 실행 중인지
  bool get isRunning => _state == DialogueEngineState.running;
  
  /// 일시정지 중인지
  bool get isPaused => _state == DialogueEngineState.paused;
  
  /// 종료되었는지
  bool get isEnded => _state == DialogueEngineState.ended;
  
  // ========== 커스텀 핸들러 ==========
  
  /// 커스텀 이벤트 핸들러 등록
  void registerCustomEventHandler(
    String eventType,
    void Function(Map<String, dynamic>) handler,
  ) {
    _interpreter?.registerEffectHandler(eventType, handler);
  }

  // ========== 라이프사이클 ==========

  /// 다이얼로그 로드
  Future<void> loadDialogue(String path, {String? fileId}) async {
    try {
      _setState(DialogueEngineState.loading);
      
      final data = await loader.loadDialogue(path, fileId: fileId);
      
      _runtime = DialogueRuntime(dialogueData: data);
      _interpreter = DialogueInterpreter(gameState: gameState);
      
      _setState(DialogueEngineState.ready);
      _fireEvent(DialogueLoadedEvent(data.id));
      
      // 플러그인 훅
      final context = DialoguePluginContext(this);
      await pluginManager.executeHook(
        'onDialogueLoaded',
        (plugin) => plugin.onDialogueLoaded(context, data),
      );
      
      debugPrint('[DialogueEngine] Loaded dialogue: ${data.id}');
    } catch (e, stackTrace) {
      _lastError = e;
      _setState(DialogueEngineState.error);
      _fireEvent(DialogueErrorEvent(e, stackTrace));
      debugPrint('[DialogueEngine] Load error: $e');
      rethrow;
    }
  }

  /// 대화 시작
  Future<void> start({String? fromScene}) async {
    if (_runtime == null || _interpreter == null) {
      throw StateError('Dialogue not loaded. Call loadDialogue() first.');
    }

    if (fromScene != null) {
      _runtime!.jumpToScene(fromScene);
    } else {
      _runtime!.jumpToScene(_runtime!.dialogueData.startSceneId);
    }

    // 씬 진입 처리
    final scene = _runtime!.getCurrentScene();
    if (scene != null) {
      _interpreter!.onSceneEnter(scene, _runtime!);
      
      // 플러그인 훅: 씬 진입
      final context = DialoguePluginContext(this);
      await pluginManager.executeHook(
        'onSceneEntered',
        (plugin) => plugin.onSceneEntered(context, scene),
      );
    }

    // 자동 진행 (effect 노드 등)
    _interpreter!.autoAdvance(_runtime!);
    
    // ✅ jump 노드 자동 처리
    await _processAutoJump();

    _setState(DialogueEngineState.running);
    _fireEvent(DialogueStartedEvent(_runtime!.currentSceneId));
    
    // 플러그인 훅: 다이얼로그 시작
    final context = DialoguePluginContext(this);
    await pluginManager.executeHook(
      'onDialogueStarted',
      (plugin) => plugin.onDialogueStarted(context, _runtime!.currentSceneId),
    );
    
    debugPrint('[DialogueEngine] Started from scene: ${_runtime!.currentSceneId}');
  }

  /// 대화 종료
  void end() {
    if (_runtime == null) return;

    _runtime!.end();
    _setState(DialogueEngineState.ended);
    _fireEvent(const DialogueEndedEvent());
    
    debugPrint('[DialogueEngine] Ended');
  }

  /// 일시정지
  void pause() {
    if (_runtime == null) return;
    
    _runtime!.pause();
    _setState(DialogueEngineState.paused);
    
    debugPrint('[DialogueEngine] Paused');
  }

  /// 재개
  void resume() {
    if (_runtime == null) return;
    
    _runtime!.resume();
    _setState(DialogueEngineState.running);
    
    debugPrint('[DialogueEngine] Resumed');
  }

  /// 리셋 (처음부터)
  void reset() {
    if (_runtime == null) return;
    
    _runtime!.reset();
    start();
    
    debugPrint('[DialogueEngine] Reset');
  }

  // ========== 진행 제어 ==========

  /// 현재 화면 가져오기
  DialogueView? getCurrentView() {
    if (_runtime == null || _interpreter == null) return null;
    if (_runtime!.isEnded) {
      return DialogueView(
        isEnded: true,
        sceneId: _runtime!.currentSceneId,
        nodeIndex: _runtime!.currentNodeIndex,
      );
    }

    final node = _runtime!.getCurrentNode();
    if (node == null) {
      return DialogueView(
        isEnded: true,
        sceneId: _runtime!.currentSceneId,
        nodeIndex: _runtime!.currentNodeIndex,
      );
    }

    // 조건 미충족 노드 스킵
    if (!_interpreter!.canShowNode(node)) {
      advance();
      return getCurrentView();
    }

    // 선택지 필터링
    var availableChoices = _interpreter!.filterAvailableChoices(node.choices);

    // 플러그인 훅: 선택지 표시 전 (동기 버전으로 근사)
    // Note: getCurrentView는 동기 메서드이므로 플러그인 훅을 비동기로 호출할 수 없음
    // 실제 앱에서는 선택지를 표시하기 전에 별도로 호출 필요

    return DialogueView(
      text: node.text,
      speaker: node.speaker,
      choices: availableChoices,
      isEnded: false,
      sceneId: _runtime!.currentSceneId,
      nodeIndex: _runtime!.currentNodeIndex,
    );
  }

  /// 다음으로 진행 (텍스트만 있을 때)
  bool advance() {
    if (_runtime == null || _interpreter == null) return false;
    if (_state != DialogueEngineState.running) return false;

    final node = _runtime!.getCurrentNode();
    if (node == null) {
      end();
      return false;
    }

    // 노드 진입 처리
    _interpreter!.onNodeEnter(node, _runtime!);

    // 다음 노드로
    if (_runtime!.advanceToNextNode()) {
      // 자동 진행
      _interpreter!.autoAdvance(_runtime!);
      
      // ✅ jump 노드 자동 처리
      _processAutoJump();
      
      notifyListeners();
      return true;
    } else {
      // 씬 끝
      end();
      return false;
    }
  }

  /// 선택지 선택
  Future<void> selectChoice(String choiceId) async {
    if (_runtime == null || _interpreter == null) {
      throw StateError('Dialogue not running');
    }

    final node = _runtime!.getCurrentNode();
    if (node == null) {
      throw StateError('No current node');
    }

    final choice = node.choices.firstWhere(
      (c) => c.id == choiceId,
      orElse: () => throw ArgumentError('Choice not found: $choiceId'),
    );

    // 플러그인 훅: 선택 전
    final context = DialoguePluginContext(this);
    final canProceed = await pluginManager.executeHookWithBoolResult(
      'beforeChoiceSelected',
      (plugin) => plugin.beforeChoiceSelected(context, choice),
    );

    if (!canProceed) {
      debugPrint('[DialogueEngine] Choice blocked by plugin: ${choice.id}');
      return;
    }

    _fireEvent(ChoiceSelectedEvent(choice));

    // 플러그인 훅: 선택 후
    await pluginManager.executeHook(
      'onChoiceSelected',
      (plugin) => plugin.onChoiceSelected(context, choice),
    );

    // 선택 처리
    final nextSceneId = _interpreter!.handleChoiceSelection(choice, _runtime!);

    // 씬 변경
    if (nextSceneId != null) {
      if (nextSceneId == 'end') {
        end();
        notifyListeners();
        return;
      }

      await _changeScene(nextSceneId);
    } else {
      // 같은 씬 내 진행
      _runtime!.advanceToNextNode();
      _interpreter!.autoAdvance(_runtime!);
    }

    notifyListeners();
  }

  /// 씬 변경
  Future<void> _changeScene(String toSceneId) async {
    if (_runtime == null || _interpreter == null) return;

    final fromSceneId = _runtime!.currentSceneId;
    
    // 현재 씬 종료 처리
    final oldScene = _runtime!.getCurrentScene();
    if (oldScene != null) {
      _interpreter!.onSceneExit(oldScene, _runtime!);
    }

    // 씬 이동
    _runtime!.jumpToScene(toSceneId);
    gameState.setCurrentScene(toSceneId);

    // 새 씬 진입 처리
    final newScene = _runtime!.getCurrentScene();
    if (newScene != null) {
      _interpreter!.onSceneEnter(newScene, _runtime!);
    }

    // 자동 진행
    _interpreter!.autoAdvance(_runtime!);
    
    // ✅ jump 노드 자동 처리
    _processAutoJump();

    _fireEvent(SceneChangedEvent(fromSceneId, toSceneId));
    
    debugPrint('[DialogueEngine] Scene changed: $fromSceneId -> $toSceneId');
  }
  
  /// jump 노드 자동 처리
  Future<void> _processAutoJump() async {
    if (_runtime == null || _interpreter == null) return;
    
    final node = _runtime!.getCurrentNode();
    if (node != null && node.type == DialogueNodeType.jump && node.hasChoices) {
      final jumpChoice = node.choices.first;
      if (jumpChoice.id == 'auto_jump' && jumpChoice.jump != null) {
        debugPrint('[DialogueEngine] Auto-processing jump node to: ${jumpChoice.jump!.sceneId}');
        // jump 선택지를 자동으로 처리
        await selectChoice('auto_jump');
      }
    }
  }

  // ========== 저장/불러오기 ==========

  /// 현재 상태 저장
  Map<String, dynamic> saveState() {
    if (_runtime == null) {
      throw StateError('No dialogue loaded');
    }

    return {
      'runtime': _runtime!.createSnapshot(),
      'gameState': gameState.createSnapshot(),
      'engineState': _state.toString(),
    };
  }

  /// 상태 복원
  Future<void> loadState(Map<String, dynamic> savedState) async {
    try {
      // 게임 상태 복원
      final gameStateData = savedState['gameState'] as Map<String, dynamic>?;
      if (gameStateData != null) {
        gameState.restoreFromSnapshot(gameStateData);
      }

      // 런타임 복원
      final runtimeData = savedState['runtime'] as Map<String, dynamic>?;
      if (runtimeData != null) {
        final dialogueId = runtimeData['dialogueId'] as String;
        
        // 다이얼로그 파일 경로 추정 (개선 필요)
        final path = 'assets/dialogue/$dialogueId.json';
        await loadDialogue(path, fileId: dialogueId);
        
        // 런타임 상태 복원
        _runtime = DialogueRuntime.fromSnapshot(
          runtimeData,
          _runtime!.dialogueData,
        );
      }

      _setState(DialogueEngineState.running);
      notifyListeners();
      
      debugPrint('[DialogueEngine] State loaded');
    } catch (e, stackTrace) {
      _lastError = e;
      _setState(DialogueEngineState.error);
      _fireEvent(DialogueErrorEvent(e, stackTrace));
      debugPrint('[DialogueEngine] Load state error: $e');
      rethrow;
    }
  }

  // ========== 이벤트 ==========

  /// 이벤트 리스너 등록
  void addEventListener(void Function(DialogueEngineEvent) listener) {
    _eventListeners.add(listener);
  }

  /// 이벤트 리스너 제거
  void removeEventListener(void Function(DialogueEngineEvent) listener) {
    _eventListeners.remove(listener);
  }

  void _fireEvent(DialogueEngineEvent event) {
    for (final listener in _eventListeners) {
      try {
        listener(event);
      } catch (e) {
        debugPrint('[DialogueEngine] Event listener error: $e');
      }
    }
  }

  // ========== 내부 ==========

  void _setState(DialogueEngineState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  // ========== 유틸리티 ==========

  /// 통계 조회
  Map<String, dynamic> getStatistics() {
    if (_runtime == null) return {};
    return _runtime!.getStatistics();
  }

  /// 디버그 정보
  String getDebugInfo() {
    final buffer = StringBuffer();
    buffer.writeln('DialogueEngine Debug Info:');
    buffer.writeln('  State: $_state');
    buffer.writeln('  Loaded: $isLoaded');
    if (_runtime != null) {
      buffer.writeln('  Runtime: $_runtime');
      buffer.writeln('  Statistics: ${_runtime!.getStatistics()}');
    }
    if (_interpreter != null) {
      buffer.writeln(_interpreter!.getDebugInfo());
    }
    return buffer.toString();
  }

  @override
  void dispose() {
    _eventListeners.clear();
    super.dispose();
  }
}

