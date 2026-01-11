/// 다이얼로그 프로바이더
/// 
/// DialogueEngine을 Flutter Provider로 통합하고
/// 편리한 상태 관리 API를 제공합니다.

import 'package:flutter/foundation.dart';
import '../dialogue_engine.dart';
import '../core/dialogue_data.dart';
import '../core/game_state_interface.dart';
import '../plugins/dialogue_plugin.dart';

/// 다이얼로그 프로바이더
/// 
/// Flutter의 ChangeNotifier를 사용하여 UI와 통합합니다.
class DialogueProvider extends ChangeNotifier {
  final DialogueEngine _engine;
  
  /// 현재 뷰
  DialogueView? _currentView;
  
  /// 로딩 상태
  bool _isLoading = false;
  
  /// 에러
  Object? _error;

  DialogueProvider({
    DialogueEngine? engine,
    IGameState? gameState,
  }) : _engine = engine ?? DialogueEngine(gameState: gameState) {
    // 엔진 이벤트 리스너 등록
    _engine.addEventListener(_handleEngineEvent);
  }

  /// 엔진 (읽기 전용)
  DialogueEngine get engine => _engine;

  /// 현재 뷰
  DialogueView? get currentView => _currentView;
  
  /// 로딩 중인지
  bool get isLoading => _isLoading;
  
  /// 에러
  Object? get error => _error;
  
  /// 엔진 상태
  DialogueEngineState get state => _engine.state;
  
  /// 준비 완료 여부
  bool get isReady => _engine.state == DialogueEngineState.ready;
  
  /// 실행 중인지
  bool get isRunning => _engine.state == DialogueEngineState.running;
  
  /// 종료되었는지
  bool get isEnded => _engine.state == DialogueEngineState.ended;
  
  /// 일시정지 중인지
  bool get isPaused => _engine.state == DialogueEngineState.paused;
  
  /// 현재 텍스트
  String? get currentText => _currentView?.text;
  
  /// 현재 화자
  String? get currentSpeaker => _currentView?.speaker;
  
  /// 현재 선택지
  List<DialogueChoice> get currentChoices => _currentView?.choices ?? [];
  
  /// 계속 진행 가능한지
  bool get canContinue => _currentView?.canContinue ?? false;
  
  /// 선택지가 있는지
  bool get hasChoices => _currentView?.hasChoices ?? false;

  // ========== 라이프사이클 ==========

  /// 다이얼로그 로드
  Future<void> loadDialogue(String path, {String? fileId}) async {
    try {
      _setLoading(true);
      _clearError();

      await _engine.loadDialogue(path, fileId: fileId);

      _setLoading(false);
    } catch (e) {
      _setError(e);
      _setLoading(false);
      rethrow;
    }
  }

  /// 다이얼로그 시작
  Future<void> start({String? fromScene}) async {
    try {
      _clearError();
      
      await _engine.start(fromScene: fromScene);
      
      _updateCurrentView();
    } catch (e) {
      _setError(e);
      rethrow;
    }
  }

  /// 다이얼로그 종료
  void end() {
    _engine.end();
    _currentView = null;
    notifyListeners();
  }

  /// 일시정지
  void pause() {
    _engine.pause();
    notifyListeners();
  }

  /// 재개
  void resume() {
    _engine.resume();
    notifyListeners();
  }

  /// 리셋
  void reset() {
    _engine.reset();
    _updateCurrentView();
  }

  // ========== 진행 제어 ==========

  /// 다음으로 진행
  void advance() {
    if (!canContinue) return;
    
    _engine.advance();
    _updateCurrentView();
  }

  /// 선택지 선택
  Future<void> selectChoice(String choiceId) async {
    try {
      _clearError();
      
      await _engine.selectChoice(choiceId);
      
      _updateCurrentView();
    } catch (e) {
      _setError(e);
      rethrow;
    }
  }

  /// 특정 씬으로 이동
  void jumpToScene(String sceneId) {
    try {
      _clearError();
      
      // Runtime을 통해 씬 이동
      if (_engine.runtime != null) {
        _engine.runtime!.jumpToScene(sceneId);
        _engine.gameState.setCurrentScene(sceneId);
        _updateCurrentView();
      }
    } catch (e) {
      _setError(e);
      rethrow;
    }
  }

  // ========== 플러그인 관리 ==========

  /// 플러그인 등록
  void registerPlugin(DialoguePlugin plugin) {
    _engine.pluginManager.registerPlugin(plugin);
  }

  /// 여러 플러그인 등록
  void registerPlugins(List<DialoguePlugin> plugins) {
    _engine.pluginManager.registerPlugins(plugins);
  }

  /// 플러그인 조회
  DialoguePlugin? getPlugin(String pluginId) {
    return _engine.pluginManager.getPlugin(pluginId);
  }

  /// 플러그인 제거
  bool unregisterPlugin(String pluginId) {
    return _engine.pluginManager.unregisterPlugin(pluginId);
  }

  // ========== 상태 관리 ==========

  /// 게임 상태 조회
  IGameState get gameState => _engine.gameState;

  /// 변수 설정
  void setVariable(String key, dynamic value) {
    _engine.gameState.setCustomData(key, value);
    notifyListeners();
  }

  /// 변수 조회
  dynamic getVariable(String key) {
    return _engine.gameState.getCustomData(key);
  }

  /// 플래그 설정
  void setFlag(String key, bool value) {
    _engine.gameState.setFlag(key, value);
    notifyListeners();
  }

  /// 플래그 조회
  bool getFlag(String key) {
    return _engine.gameState.getFlag(key) ?? false;
  }

  // ========== 저장/로드 ==========

  /// 상태 저장
  Map<String, dynamic> saveState() {
    return _engine.saveState();
  }

  /// 상태 로드
  Future<void> loadState(Map<String, dynamic> state) async {
    try {
      _clearError();
      
      await _engine.loadState(state);
      
      _updateCurrentView();
    } catch (e) {
      _setError(e);
      rethrow;
    }
  }

  // ========== 내부 메서드 ==========

  /// 엔진 이벤트 처리
  void _handleEngineEvent(DialogueEngineEvent event) {
    if (event is DialogueErrorEvent) {
      _setError(event.error);
    }
    
    // 뷰 업데이트
    _updateCurrentView();
  }

  /// 현재 뷰 업데이트
  void _updateCurrentView() {
    _currentView = _engine.getCurrentView();
    notifyListeners();
  }

  /// 로딩 상태 설정
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// 에러 설정
  void _setError(Object error) {
    _error = error;
    notifyListeners();
    
    if (kDebugMode) {
      debugPrint('[DialogueProvider] Error: $error');
    }
  }

  /// 에러 클리어
  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _engine.removeEventListener(_handleEngineEvent);
    super.dispose();
  }

  // ========== 편의 메서드 ==========

  /// 다이얼로그 로드 & 시작 (한 번에)
  Future<void> loadAndStart(String path, {String? fileId, String? fromScene}) async {
    await loadDialogue(path, fileId: fileId);
    await start(fromScene: fromScene);
  }

  /// 통계 조회
  Map<String, dynamic> getStatistics() {
    return {
      'engineState': state.toString(),
      'isLoading': isLoading,
      'hasError': error != null,
      'currentSceneId': _currentView?.sceneId,
      'currentNodeIndex': _currentView?.nodeIndex,
      'hasText': _currentView?.hasText,
      'choiceCount': currentChoices.length,
      'canContinue': canContinue,
    };
  }

  /// 디버그 정보
  String getDebugInfo() {
    final buffer = StringBuffer();
    buffer.writeln('DialogueProvider:');
    buffer.writeln('  State: $state');
    buffer.writeln('  Loading: $isLoading');
    buffer.writeln('  Error: ${error ?? "none"}');
    buffer.writeln('  Current View: ${_currentView?.toString() ?? "null"}');
    buffer.writeln('  Can Continue: $canContinue');
    buffer.writeln('  Choices: ${currentChoices.length}');
    return buffer.toString();
  }
}

