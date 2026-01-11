/// 분기 플러그인
/// 
/// 중요한 선택지를 분기점으로 기록하고 되돌아갈 수 있게 합니다.

import 'package:flutter/foundation.dart';
import '../core/dialogue_data.dart';
import 'dialogue_plugin.dart';

/// 분기점 정보
class BranchPoint {
  /// 씬 ID
  final String sceneId;
  
  /// 선택지 ID
  final String choiceId;
  
  /// 선택지 텍스트
  final String choiceText;
  
  /// 게임 상태 스냅샷
  final Map<String, dynamic> gameState;
  
  /// 분기 시간
  final DateTime timestamp;

  const BranchPoint({
    required this.sceneId,
    required this.choiceId,
    required this.choiceText,
    required this.gameState,
    required this.timestamp,
  });

  /// 직렬화
  Map<String, dynamic> toMap() {
    return {
      'sceneId': sceneId,
      'choiceId': choiceId,
      'choiceText': choiceText,
      'gameState': gameState,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// 역직렬화
  factory BranchPoint.fromMap(Map<String, dynamic> map) {
    return BranchPoint(
      sceneId: map['sceneId'] as String,
      choiceId: map['choiceId'] as String,
      choiceText: map['choiceText'] as String,
      gameState: Map<String, dynamic>.from(map['gameState'] as Map),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  @override
  String toString() => 'BranchPoint($sceneId -> $choiceText)';
}

/// 분기 플러그인
class BranchingPlugin extends SimpleDialoguePlugin {
  /// 분기 히스토리
  final List<BranchPoint> _branchHistory = [];
  
  /// 현재 분기 인덱스
  int _currentIndex = -1;
  
  /// 로깅 활성화
  bool enableLogging = kDebugMode;

  BranchingPlugin()
      : super(
          id: 'branching',
          name: 'Branching Plugin',
          priority: 80, // 선택 후 실행
        );

  /// 분기 히스토리
  List<BranchPoint> get branchHistory => List.unmodifiable(_branchHistory);
  
  /// 현재 분기점
  BranchPoint? get currentBranch {
    if (_currentIndex >= 0 && _currentIndex < _branchHistory.length) {
      return _branchHistory[_currentIndex];
    }
    return null;
  }
  
  /// 이전 분기점이 있는지
  bool get hasPreviousBranch => _currentIndex > 0;
  
  /// 다음 분기점이 있는지
  bool get hasNextBranch => _currentIndex < _branchHistory.length - 1;

  @override
  Future<void> onChoiceSelected(
    DialoguePluginContext context,
    DialogueChoice choice,
  ) async {
    // 분기점으로 표시된 선택지만 기록
    if (!choice.isBranchPoint) return;

    final runtime = context.runtime;
    if (runtime == null) return;

    // 게임 상태 스냅샷
    final gameStateSnapshot = <String, dynamic>{
      // runtime 상태
      'sceneId': runtime.currentSceneId,
      'nodeIndex': runtime.currentNodeIndex,
      
      // 게임 상태 (엔진을 통해 접근)
      // Note: IGameState를 직접 접근할 수 없으므로 엔진에서 제공해야 함
      // 일단 runtime의 스냅샷만 저장
      'runtime': runtime.createSnapshot(),
    };

    final branchPoint = BranchPoint(
      sceneId: runtime.currentSceneId,
      choiceId: choice.id,
      choiceText: choice.text,
      gameState: gameStateSnapshot,
      timestamp: DateTime.now(),
    );

    // 현재 위치 이후의 분기는 제거 (새 타임라인)
    if (_currentIndex < _branchHistory.length - 1) {
      _branchHistory.removeRange(_currentIndex + 1, _branchHistory.length);
      if (enableLogging) {
        debugPrint('[BranchingPlugin] Pruned future branches');
      }
    }

    _branchHistory.add(branchPoint);
    _currentIndex = _branchHistory.length - 1;

    if (enableLogging) {
      debugPrint('[BranchingPlugin] Branch point saved: $branchPoint');
      debugPrint('[BranchingPlugin] Total branches: ${_branchHistory.length}');
    }
  }

  /// 이전 분기로 이동
  BranchPoint? goToPreviousBranch() {
    if (!hasPreviousBranch) return null;

    _currentIndex--;
    final branch = currentBranch;

    if (enableLogging) {
      debugPrint('[BranchingPlugin] Moved to previous branch: $branch');
    }

    return branch;
  }

  /// 다음 분기로 이동
  BranchPoint? goToNextBranch() {
    if (!hasNextBranch) return null;

    _currentIndex++;
    final branch = currentBranch;

    if (enableLogging) {
      debugPrint('[BranchingPlugin] Moved to next branch: $branch');
    }

    return branch;
  }

  /// 특정 분기로 이동
  BranchPoint? goToBranch(int index) {
    if (index < 0 || index >= _branchHistory.length) return null;

    _currentIndex = index;
    final branch = currentBranch;

    if (enableLogging) {
      debugPrint('[BranchingPlugin] Moved to branch #$index: $branch');
    }

    return branch;
  }

  /// 히스토리 클리어
  void clearHistory() {
    final count = _branchHistory.length;
    _branchHistory.clear();
    _currentIndex = -1;

    if (enableLogging) {
      debugPrint('[BranchingPlugin] Cleared $count branch points');
    }
  }

  @override
  Future<Map<String, dynamic>> beforeSave(
    DialoguePluginContext context,
    Map<String, dynamic> state,
  ) async {
    // 분기 히스토리를 저장 데이터에 추가
    state['branching_plugin'] = {
      'branchHistory': _branchHistory.map((b) => b.toMap()).toList(),
      'currentIndex': _currentIndex,
    };

    return state;
  }

  @override
  Future<void> onLoaded(
    DialoguePluginContext context,
    Map<String, dynamic> state,
  ) async {
    // 분기 히스토리 복원
    if (state.containsKey('branching_plugin')) {
      final data = state['branching_plugin'] as Map<String, dynamic>;
      
      _branchHistory.clear();
      final historyData = data['branchHistory'] as List?;
      if (historyData != null) {
        for (final item in historyData) {
          _branchHistory.add(BranchPoint.fromMap(item as Map<String, dynamic>));
        }
      }

      _currentIndex = data['currentIndex'] as int? ?? -1;

      if (enableLogging) {
        debugPrint('[BranchingPlugin] Loaded ${_branchHistory.length} branch points');
      }
    }
  }

  /// 통계 조회
  Map<String, dynamic> getStatistics() {
    return {
      'totalBranches': _branchHistory.length,
      'currentIndex': _currentIndex,
      'hasPrevious': hasPreviousBranch,
      'hasNext': hasNextBranch,
    };
  }

  /// 디버그 정보
  String getDebugInfo() {
    final buffer = StringBuffer();
    buffer.writeln('BranchingPlugin:');
    buffer.writeln('  Total Branches: ${_branchHistory.length}');
    buffer.writeln('  Current Index: $_currentIndex');
    buffer.writeln('  Has Previous: $hasPreviousBranch');
    buffer.writeln('  Has Next: $hasNextBranch');
    buffer.writeln();

    if (_branchHistory.isNotEmpty) {
      buffer.writeln('Branch History:');
      for (var i = 0; i < _branchHistory.length; i++) {
        final branch = _branchHistory[i];
        final marker = i == _currentIndex ? ' <<< CURRENT' : '';
        buffer.writeln('  [$i] $branch$marker');
      }
    }

    return buffer.toString();
  }
}

