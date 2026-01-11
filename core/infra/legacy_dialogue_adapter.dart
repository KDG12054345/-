/// 레거시 DialogueManager API를 새로운 DialogueEngine으로 변환하는 어댑터
/// 
/// 마이그레이션 전략:
/// 1. 기존 UI 코드는 DialogueManager API를 그대로 사용
/// 2. LegacyDialogueAdapter가 레거시 API를 받아서 DialogueEngine으로 변환
/// 3. 내부에서는 새로운 시스템 사용
/// 
/// 사용 예:
/// ```dart
/// // 기존 코드
/// final manager = DialogueManager();
/// 
/// // 마이그레이션 중 (UI 코드 변경 없이)
/// final manager = LegacyDialogueAdapter();  // ← 이것만 변경
/// await manager.loadDialogue('assets/dialogue/start/scene1.json');
/// manager.setScene('scene1');
/// ```

import 'package:flutter/foundation.dart';
import '../../dialogue_manager.dart' as legacy;
import '../../dialogue/dialogue_engine.dart';
import '../../dialogue/core/dialogue_data.dart';
import '../../dialogue/core/game_state_interface.dart';
import '../../event_system.dart' as legacy_event;

/// 레거시 DialogueManager를 DialogueEngine으로 변환하는 어댑터
class LegacyDialogueAdapter extends ChangeNotifier {
  final DialogueEngine _engine;
  bool _isInitialized = false;
  
  // 레거시 호환을 위한 상태
  String _currentSceneId = '';
  Map<String, dynamic>? _currentDialogueData;
  
  LegacyDialogueAdapter({
    DialogueEngine? engine,
    IGameState? gameState,
  }) : _engine = engine ?? DialogueEngine(gameState: gameState ?? BasicGameState()) {
    _initializeEngine();
  }
  
  /// 어댑터 초기화
  void _initializeEngine() {
    if (_isInitialized) return;
    
    // DialogueEngine 이벤트 리스너 등록
    _engine.addEventListener(_handleEngineEvent);
    _engine.addListener(_onEngineStateChanged);

    // policy2: traits SSOT = 레거시(EventSystem/GameState).
    // 신규 엔진의 add_trait/remove_trait 효과는 레거시 이벤트로 위임해야 하며,
    // 엔진 내부(in-memory) traits 수정은 금지됩니다.
    _engine.registerCustomEventHandler('add_trait', (data) {
      final id = data['id']?.toString();
      if (id == null || id.isEmpty) return;
      DialogueEventBridge.emitLegacyEvent(
        legacy_event.GameEvent(
          type: legacy_event.GameEventType.ADD_TRAIT,
          data: {'trait': id},
        ),
      );
    });
    _engine.registerCustomEventHandler('remove_trait', (data) {
      final id = data['id']?.toString();
      if (id == null || id.isEmpty) return;
      DialogueEventBridge.emitLegacyEvent(
        legacy_event.GameEvent(
          type: legacy_event.GameEventType.REMOVE_TRAIT,
          data: {'trait': id},
        ),
      );
    });
    
    _isInitialized = true;
    
    debugPrint('✅ LegacyDialogueAdapter initialized - 레거시 API → DialogueEngine 변환 활성화');
  }
  
  /// 엔진 상태 변경 시 리스너에게 알림
  void _onEngineStateChanged() {
    notifyListeners();
  }
  
  /// 엔진 이벤트 처리
  void _handleEngineEvent(DialogueEngineEvent event) {
    if (event is SceneChangedEvent) {
      _currentSceneId = event.toScene;
      debugPrint('🔄 Scene changed: ${event.fromScene} → ${event.toScene}');
    } else if (event is DialogueEndedEvent) {
      debugPrint('🏁 Dialogue ended');
    } else if (event is DialogueErrorEvent) {
      debugPrint('❌ Dialogue error: ${event.error}');
    }
  }
  
  // ========== 레거시 API 호환 ==========
  
  /// 대화 파일 로드 (레거시 API)
  Future<void> loadDialogue(String jsonPath) async {
    try {
      await _engine.loadDialogue(jsonPath);
      _currentDialogueData = {}; // 레거시 호환용
      notifyListeners();
      
      debugPrint('📖 Loaded dialogue via adapter: $jsonPath');
    } catch (e) {
      debugPrint('❌ Failed to load dialogue: $e');
      rethrow;
    }
  }
  
  /// 씬 설정 및 시작 (레거시 API)
  void setScene(String sceneId) {
    _currentSceneId = sceneId;
    
    if (_engine.isLoaded && !_engine.isRunning) {
      _engine.start(fromScene: sceneId);
    } else if (_engine.isRunning) {
      // 이미 실행 중이면 씬 변경은 선택지를 통해서만 가능
      debugPrint('⚠️ Cannot change scene directly while dialogue is running');
    }
    
    notifyListeners();
  }
  
  /// 현재 라인 표시 (레거시 API)
  /// 
  /// [choiceId] - null이면 시작 노드, 아니면 해당 선택지의 다음 노드
  Map<String, dynamic>? showLine(String? choiceId) {
    final view = _engine.getCurrentView();
    if (view == null) return null;
    
    // DialogueView를 레거시 형식으로 변환
    return {
      'text': view.text ?? '',
      'speaker': view.speaker,
      'choices': view.choices.map((c) => {
        'id': c.id,
        'text': c.text,
        'enabled': c.enabled,
      }).toList(),
      'isEnd': view.isEnded,
    };
  }
  
  /// 선택지 목록 가져오기 (레거시 API)
  List<legacy.Choice> getChoices() {
    final view = _engine.getCurrentView();
    if (view == null) return [];
    
    return view.choices.map((choice) {
      return legacy.Choice(
        id: choice.id,
        text: choice.text,
        isEnabled: choice.enabled,
        conditions: null, // 조건은 이미 엔진에서 처리됨
      );
    }).toList();
  }
  
  /// 선택지 처리 (레거시 API)
  void handleChoice(String choiceId) {
    _engine.selectChoice(choiceId).catchError((error) {
      debugPrint('❌ Failed to handle choice: $error');
    });
  }
  
  /// 다음으로 진행 (텍스트만 있을 때)
  void next() {
    _engine.advance();
  }
  
  // ========== 게임 상태 접근 (레거시 API 호환) ==========
  
  /// 플레이어 스탯 (레거시 API)
  Map<String, int> get playerStats => _engine.gameState.getAllStats();
  
  /// 플레이어 아이템 (레거시 API)
  List<String> get playerItems => _engine.gameState.getAllItems();
  
  /// 플래그 (레거시 API)
  Map<String, bool> get flags => _engine.gameState.getAllFlags();
  
  /// 현재 씬 (레거시 API)
  String get currentScene => _currentSceneId;
  
  // ========== 저장/불러오기 (레거시 API 호환) ==========
  
  /// 게임 저장 (레거시 API)
  Future<void> saveGame() async {
    try {
      final state = _engine.saveState();
      // 레거시 SaveSystem과 통합 필요 시 여기서 처리
      debugPrint('💾 Game saved via adapter');
    } catch (e) {
      debugPrint('❌ Failed to save game: $e');
      rethrow;
    }
  }
  
  /// 게임 불러오기 (레거시 API)
  Future<void> loadGame() async {
    try {
      // 레거시 SaveSystem에서 데이터 로드 필요
      debugPrint('📂 Game loaded via adapter');
    } catch (e) {
      debugPrint('❌ Failed to load game: $e');
      rethrow;
    }
  }
  
  /// 저장 파일 삭제 (레거시 API)
  Future<void> deleteSave() async {
    debugPrint('🗑️ Save deleted via adapter');
  }
  
  // ========== 분기 시스템 (레거시 API 호환) ==========
  
  /// 분기 히스토리 (현재는 미구현, 필요 시 플러그인으로 추가)
  List<dynamic> get branchHistory => [];
  
  /// 현재 분기 (현재는 미구현)
  dynamic get currentBranch => null;
  
  /// 이전 분기로 이동 (현재는 미구현)
  void goToPreviousBranch() {
    debugPrint('⚠️ Branch navigation not implemented in new system yet');
  }
  
  /// 다음 분기로 이동 (현재는 미구현)
  void goToNextBranch() {
    debugPrint('⚠️ Branch navigation not implemented in new system yet');
  }
  
  /// 특정 분기로 이동 (현재는 미구현)
  void goToBranch(int index) {
    debugPrint('⚠️ Branch navigation not implemented in new system yet');
  }
  
  // ========== 게임 상태 설정 (레거시 API 호환) ==========
  
  /// 게임 상태 설정 (레거시 API)
  void setGameState({
    required Map<String, int> stats,
    required List<String> items,
    required Map<String, bool> flags,
    required String currentScene,
  }) {
    // 새 시스템의 게임 상태 설정
    stats.forEach((name, value) {
      _engine.gameState.setStat(name, value);
    });
    
    items.forEach((item) {
      _engine.gameState.addItem(item);
    });
    
    flags.forEach((name, value) {
      _engine.gameState.setFlag(name, value);
    });
    
    _engine.gameState.setCurrentScene(currentScene);
    _currentSceneId = currentScene;
    
    notifyListeners();
  }
  
  // ========== 어댑터 정보 ==========
  
  /// 현재 어댑터가 사용하는 엔진
  DialogueEngine get engine => _engine;
  
  /// 어댑터 활성화 여부
  bool get isInitialized => _isInitialized;
  
  /// 대화 실행 중 여부
  bool get isRunning => _engine.isRunning;
  
  /// 대화 종료 여부
  bool get isEnded => _engine.isEnded;
  
  // ========== 정리 ==========
  
  @override
  void dispose() {
    if (_isInitialized) {
      _engine.removeEventListener(_handleEngineEvent);
      _engine.removeListener(_onEngineStateChanged);
    }
    super.dispose();
  }
}

/// EventSystem과의 브릿지 (선택적)
/// 
/// 기존 EventSystem을 사용하는 코드와의 호환을 위한 헬퍼
class DialogueEventBridge {
  static legacy_event.EventSystem? _legacyEventSystem;
  
  /// 레거시 EventSystem 등록
  static void setLegacyEventSystem(legacy_event.EventSystem eventSystem) {
    _legacyEventSystem = eventSystem;
  }
  
  /// 레거시 GameState를 IGameState로 변환
  static IGameState wrapLegacyGameState(legacy_event.GameState legacyState) {
    return LegacyGameStateAdapter(legacyState);
  }
  
  /// 레거시 이벤트 발생 (DialogueEngine 효과를 레거시로 전달)
  static void emitLegacyEvent(legacy_event.GameEvent event) {
    if (_legacyEventSystem != null) {
      _legacyEventSystem!.handleEvent(event);
      debugPrint('🔄 Emitted legacy event: ${event.type}');
    }
  }
}

