import 'dart:io';
import 'package:flutter/foundation.dart';
import '../dialogue_manager.dart';
import '../branch_system.dart';
import 'autosave_system.dart';
import 'deterministic_rng.dart';

class AutosaveDialogueManager extends DialogueManager {
  final AutosaveSystem _autosave;

  String _runId;
  int _commitIndex = 0;
  String _lastEventId = 'init';
  DateTime _lastSaveAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _commitsSinceLastSave = 0;

  bool _pendingCommit = false;
  String? _pendingChoiceId;
  String? _pendingSceneId;
  bool _isRestoring = false;

  static const Duration _debounce = Duration(milliseconds: 200);
  static const Duration _failsafeInterval = Duration(minutes: 5);

  AutosaveDialogueManager({
    AutosaveSystem? autosave,
    String? runId,
  })  : _autosave = autosave ?? AutosaveSystem(),
        _runId = runId ?? _genRunId() {
    Future<void>(() async {
      while (true) {
        await Future<void>.delayed(_failsafeInterval);
        try {
          if (_isRestoring) continue;
          if (_commitsSinceLastSave >= 10 ||
              DateTime.now().difference(_lastSaveAt) >= _failsafeInterval) {
            _saveNowSync(lastEventId: 'failsafe');
          }
        } catch (e, s) {
          debugPrint('[AutosaveDM] failsafe save error: $e');
          debugPrint('$s');
        }
      }
    });

    _pendingCommit = true;
    _pendingSceneId = currentScene;
  }

  static String _genRunId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final pid = Platform.numberOfProcessors;
    return 'run_${now}_$pid';
  }

  @override
  void handleChoice(String choiceId) {
    _pendingCommit = true;
    _pendingChoiceId = choiceId;
    _pendingSceneId = currentScene;
    super.handleChoice(choiceId);
  }

  @override
  void setScene(String sceneId) {
    _pendingCommit = true;
    _pendingChoiceId = null;
    _pendingSceneId = sceneId;
    super.setScene(sceneId);
  }

  @override
  void setGameState({
    required Map<String, int> stats,
    required List<String> items,
    required Map<String, bool> flags,
    required String currentScene,
  }) {
    _runId = _genRunId();
    _pendingCommit = true;
    _pendingChoiceId = null;
    _pendingSceneId = currentScene;
    super.setGameState(
      stats: stats,
      items: items,
      flags: flags,
      currentScene: currentScene,
    );
  }

  @override
  Future<void> saveGame() async {
    debugPrint('[AutosaveDM] manual save disabled (autosave only).');
  }

  @override
  Future<void> deleteSave() async {
    _autosave.deleteAll();
  }

  @override
  Future<void> loadGame() async {
    final loaded = _autosave.loadLatest();
    if (loaded == null) return;
    _isRestoring = true;
    try {
      final data = loaded.data;
      final stats = Map<String, int>.from(data['stats'] ?? const <String, int>{});
      final items = List<String>.from(data['items'] ?? const <String>[]);
      final flags = Map<String, bool>.from(data['flags'] ?? const <String, bool>{});
      final scene = (data['currentScene'] as String?) ?? 'start';
      super.setGameState(stats: stats, items: items, flags: flags, currentScene: scene);
      super.setScene(scene);

      _runId = loaded.meta.runId;
      _commitIndex = loaded.meta.commitIndex;
      _lastEventId = loaded.meta.lastEventId;
      _lastSaveAt = loaded.meta.timestamp;
      _commitsSinceLastSave = 0;
    } finally {
      _isRestoring = false;
    }
  }

  Map<String, dynamic> _snapshot() {
    return {
      'stats': Map<String, int>.from(playerStats),
      'items': List<String>.from(playerItems),
      'flags': Map<String, bool>.from(flags),
      'currentScene': currentScene,
      'branchHistory': [
        for (final b in branchHistory)
          {
            'sceneId': b.sceneId,
            'choiceId': b.choiceId,
            'gameState': b.gameState,
          }
      ],
    };
  }

  int _seedForCurrent() {
    final chapterId = _pendingSceneId ?? currentScene;
    final choiceId = _pendingChoiceId ?? '';
    return DeterministicRNG.fromContext(
      runId: _runId,
      chapterId: chapterId,
      choiceId: choiceId,
      commitIndex: _commitIndex,
    ).nextInt(0x7FFFFFFF);
  }

  void _saveNowSync({required String lastEventId}) {
    final now = DateTime.now();
    final since = now.difference(_lastSaveAt);
    if (since < _debounce) {
      sleep(_debounce - since);
    }
    final data = _snapshot();
    final meta = AutosaveMeta(
      runId: _runId,
      commitIndex: _commitIndex,
      lastEventId: lastEventId,
      seed: _seedForCurrent(),
      timestamp: DateTime.now(),
    );
    _autosave.saveSync(data: data, meta: meta);
    _lastSaveAt = DateTime.now();
    _commitsSinceLastSave = 0;
  }

  @override
  void notifyListeners() {
    if (_isRestoring) {
      super.notifyListeners();
      return;
    }
    if (_pendingCommit) {
      _commitIndex += 1;
      _commitsSinceLastSave += 1;
      final scene = _pendingSceneId ?? currentScene;
      if (_pendingChoiceId != null) {
        _lastEventId = 'dialogue:$scene>${_pendingChoiceId}';
      } else if (scene.isNotEmpty) {
        _lastEventId = 'scene:$scene';
      } else {
        _lastEventId = 'commit';
      }
      _saveNowSync(lastEventId: _lastEventId);
      _pendingCommit = false;
      _pendingChoiceId = null;
      _pendingSceneId = null;
    }
    super.notifyListeners();
  }
  
  /// 새 회차 시작을 위한 초기화
  /// 
  /// RunState 초기화의 일부로, 이전 회차의 대화 상태를 모두 제거합니다.
  void resetForNewRun() {
    debugPrint('[AutosaveDM] 🔄 Resetting for new run...');
    
    // 1. DialogueManager 기본 상태 초기화
    super.setGameState(
      stats: {},
      items: [],
      flags: {},
      currentScene: '',
    );
    setCurrentPlayer(null);  // Player 초기화
    
    // 2. AutosaveDialogueManager 고유 필드 초기화
    _runId = _genRunId();  // 새 runId 생성
    _commitIndex = 0;
    _lastEventId = 'init';
    _lastSaveAt = DateTime.fromMillisecondsSinceEpoch(0);
    _commitsSinceLastSave = 0;
    
    _pendingCommit = false;
    _pendingChoiceId = null;
    _pendingSceneId = null;
    _isRestoring = false;
    
    // 3. 저장 파일 삭제 (새 회차 시작이므로 이전 저장 불필요)
    _autosave.deleteAll();
    
    debugPrint('[AutosaveDM] ✅ Reset complete (new runId: $_runId)');
  }
}
