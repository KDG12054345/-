/// 다이얼로그 런타임
/// 
/// 현재 다이얼로그의 실행 상태만을 관리합니다.
/// 로직 실행은 DialogueInterpreter가 담당하고,
/// 이 클래스는 순수하게 상태만 보관합니다.

import 'dialogue_data.dart';

/// 다이얼로그 런타임 상태
class DialogueRuntime {
  /// 현재 로드된 다이얼로그 데이터
  final DialogueData dialogueData;
  
  /// 현재 씬 ID
  String currentSceneId;
  
  /// 현재 씬 내 노드 인덱스
  int currentNodeIndex;
  
  /// 방문한 씬 기록 (sceneId -> 방문 횟수)
  final Map<String, int> visitedScenes;
  
  /// 방문한 노드 기록 (sceneId.nodeId -> 방문 횟수)
  final Map<String, int> visitedNodes;
  
  /// 선택한 선택지 기록 (순서대로)
  final List<DialogueChoiceRecord> choiceHistory;
  
  /// 대화 히스토리 (표시된 텍스트들)
  final List<DialogueHistoryEntry> textHistory;
  
  /// 로컬 변수 (씬 내에서만 유효한 임시 변수)
  final Map<String, dynamic> localVariables;
  
  /// 런타임이 시작된 시간
  final DateTime startTime;
  
  /// 마지막 업데이트 시간
  DateTime lastUpdateTime;
  
  /// 일시정지 여부
  bool isPaused;
  
  /// 종료 여부
  bool isEnded;

  DialogueRuntime({
    required this.dialogueData,
    String? initialSceneId,
    this.currentNodeIndex = 0,
    Map<String, int>? visitedScenes,
    Map<String, int>? visitedNodes,
    List<DialogueChoiceRecord>? choiceHistory,
    List<DialogueHistoryEntry>? textHistory,
    Map<String, dynamic>? localVariables,
    DateTime? startTime,
    DateTime? lastUpdateTime,
    this.isPaused = false,
    this.isEnded = false,
  })  : currentSceneId = initialSceneId ?? dialogueData.startSceneId,
        visitedScenes = visitedScenes ?? {},
        visitedNodes = visitedNodes ?? {},
        choiceHistory = choiceHistory ?? [],
        textHistory = textHistory ?? [],
        localVariables = localVariables ?? {},
        startTime = startTime ?? DateTime.now(),
        lastUpdateTime = lastUpdateTime ?? DateTime.now();

  /// 현재 씬 가져오기
  DialogueScene? getCurrentScene() {
    return dialogueData.getScene(currentSceneId);
  }

  /// 현재 노드 가져오기
  DialogueNode? getCurrentNode() {
    final scene = getCurrentScene();
    if (scene == null) return null;
    if (currentNodeIndex < 0 || currentNodeIndex >= scene.nodes.length) {
      return null;
    }
    return scene.nodes[currentNodeIndex];
  }

  /// 다음 노드로 진행
  bool advanceToNextNode() {
    final scene = getCurrentScene();
    if (scene == null) return false;

    if (currentNodeIndex + 1 < scene.nodes.length) {
      currentNodeIndex++;
      _markNodeVisited();
      lastUpdateTime = DateTime.now();
      return true;
    }

    return false;
  }

  /// 특정 씬으로 이동
  void jumpToScene(String sceneId, {int nodeIndex = 0}) {
    currentSceneId = sceneId;
    currentNodeIndex = nodeIndex;
    _markSceneVisited();
    _markNodeVisited();
    
    // 씬 변경 시 로컬 변수 초기화
    localVariables.clear();
    
    lastUpdateTime = DateTime.now();
  }

  /// 특정 노드로 이동 (같은 씬 내)
  void jumpToNode(int nodeIndex) {
    final scene = getCurrentScene();
    if (scene == null) return;
    
    if (nodeIndex >= 0 && nodeIndex < scene.nodes.length) {
      currentNodeIndex = nodeIndex;
      _markNodeVisited();
      lastUpdateTime = DateTime.now();
    }
  }

  /// 선택지 선택 기록
  void recordChoice(DialogueChoice choice, {String? sceneId, int? nodeIdx}) {
    final record = DialogueChoiceRecord(
      sceneId: sceneId ?? currentSceneId,
      nodeIndex: nodeIdx ?? currentNodeIndex,
      choiceId: choice.id,
      choiceText: choice.text,
      timestamp: DateTime.now(),
    );
    choiceHistory.add(record);
  }

  /// 텍스트 표시 기록
  void recordText(String text, {String? speaker, String? sceneId, int? nodeIdx}) {
    final entry = DialogueHistoryEntry(
      sceneId: sceneId ?? currentSceneId,
      nodeIndex: nodeIdx ?? currentNodeIndex,
      text: text,
      speaker: speaker,
      timestamp: DateTime.now(),
    );
    textHistory.add(entry);
  }

  /// 씬 방문 여부 확인
  bool hasVisitedScene(String sceneId) {
    return visitedScenes.containsKey(sceneId);
  }

  /// 노드 방문 여부 확인
  bool hasVisitedNode(String sceneId, String nodeId) {
    final key = '$sceneId.$nodeId';
    return visitedNodes.containsKey(key);
  }

  /// 씬 방문 횟수 조회
  int getSceneVisitCount(String sceneId) {
    return visitedScenes[sceneId] ?? 0;
  }

  /// 노드 방문 횟수 조회
  int getNodeVisitCount(String sceneId, String nodeId) {
    final key = '$sceneId.$nodeId';
    return visitedNodes[key] ?? 0;
  }

  /// 대화 종료
  void end() {
    isEnded = true;
    lastUpdateTime = DateTime.now();
  }

  /// 일시정지
  void pause() {
    isPaused = true;
  }

  /// 재개
  void resume() {
    isPaused = false;
    lastUpdateTime = DateTime.now();
  }

  /// 런타임 리셋 (같은 다이얼로그 처음부터)
  void reset() {
    currentSceneId = dialogueData.startSceneId;
    currentNodeIndex = 0;
    visitedScenes.clear();
    visitedNodes.clear();
    choiceHistory.clear();
    textHistory.clear();
    localVariables.clear();
    isPaused = false;
    isEnded = false;
    lastUpdateTime = DateTime.now();
  }

  /// 상태 스냅샷 생성 (저장용)
  Map<String, dynamic> createSnapshot() {
    return {
      'dialogueId': dialogueData.id,
      'currentSceneId': currentSceneId,
      'currentNodeIndex': currentNodeIndex,
      'visitedScenes': Map<String, int>.from(visitedScenes),
      'visitedNodes': Map<String, int>.from(visitedNodes),
      'choiceHistory': choiceHistory.map((r) => r.toMap()).toList(),
      'textHistory': textHistory.map((e) => e.toMap()).toList(),
      'localVariables': Map<String, dynamic>.from(localVariables),
      'startTime': startTime.toIso8601String(),
      'lastUpdateTime': lastUpdateTime.toIso8601String(),
      'isPaused': isPaused,
      'isEnded': isEnded,
    };
  }

  /// 스냅샷에서 복원 (불러오기용)
  /// 
  /// 주의: dialogueData는 별도로 로드해야 함
  static DialogueRuntime fromSnapshot(
    Map<String, dynamic> snapshot,
    DialogueData dialogueData,
  ) {
    return DialogueRuntime(
      dialogueData: dialogueData,
      initialSceneId: snapshot['currentSceneId'] as String?,
      currentNodeIndex: snapshot['currentNodeIndex'] as int? ?? 0,
      visitedScenes: Map<String, int>.from(snapshot['visitedScenes'] as Map? ?? {}),
      visitedNodes: Map<String, int>.from(snapshot['visitedNodes'] as Map? ?? {}),
      choiceHistory: (snapshot['choiceHistory'] as List?)
              ?.map((m) => DialogueChoiceRecord.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      textHistory: (snapshot['textHistory'] as List?)
              ?.map((m) => DialogueHistoryEntry.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      localVariables: Map<String, dynamic>.from(snapshot['localVariables'] as Map? ?? {}),
      startTime: snapshot['startTime'] != null
          ? DateTime.parse(snapshot['startTime'] as String)
          : null,
      lastUpdateTime: snapshot['lastUpdateTime'] != null
          ? DateTime.parse(snapshot['lastUpdateTime'] as String)
          : null,
      isPaused: snapshot['isPaused'] as bool? ?? false,
      isEnded: snapshot['isEnded'] as bool? ?? false,
    );
  }

  /// 경과 시간 계산
  Duration getElapsedTime() {
    return lastUpdateTime.difference(startTime);
  }

  /// 통계 조회
  Map<String, dynamic> getStatistics() {
    return {
      'totalScenes': visitedScenes.length,
      'totalNodes': visitedNodes.length,
      'totalChoices': choiceHistory.length,
      'totalTexts': textHistory.length,
      'elapsedTime': getElapsedTime().toString(),
      'currentScene': currentSceneId,
      'currentNode': currentNodeIndex,
    };
  }

  // ========== 내부 메서드 ==========

  void _markSceneVisited() {
    visitedScenes[currentSceneId] = (visitedScenes[currentSceneId] ?? 0) + 1;
  }

  void _markNodeVisited() {
    final node = getCurrentNode();
    if (node != null) {
      final key = '$currentSceneId.${node.id}';
      visitedNodes[key] = (visitedNodes[key] ?? 0) + 1;
    }
  }

  @override
  String toString() {
    return 'DialogueRuntime(dialogue: ${dialogueData.id}, scene: $currentSceneId, node: $currentNodeIndex, ended: $isEnded)';
  }
}

/// 선택지 선택 기록
class DialogueChoiceRecord {
  final String sceneId;
  final int nodeIndex;
  final String choiceId;
  final String choiceText;
  final DateTime timestamp;

  const DialogueChoiceRecord({
    required this.sceneId,
    required this.nodeIndex,
    required this.choiceId,
    required this.choiceText,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'sceneId': sceneId,
      'nodeIndex': nodeIndex,
      'choiceId': choiceId,
      'choiceText': choiceText,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory DialogueChoiceRecord.fromMap(Map<String, dynamic> map) {
    return DialogueChoiceRecord(
      sceneId: map['sceneId'] as String,
      nodeIndex: map['nodeIndex'] as int,
      choiceId: map['choiceId'] as String,
      choiceText: map['choiceText'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  @override
  String toString() => 'Choice($choiceText at $sceneId:$nodeIndex)';
}

/// 대화 히스토리 엔트리
class DialogueHistoryEntry {
  final String sceneId;
  final int nodeIndex;
  final String text;
  final String? speaker;
  final DateTime timestamp;

  const DialogueHistoryEntry({
    required this.sceneId,
    required this.nodeIndex,
    required this.text,
    this.speaker,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'sceneId': sceneId,
      'nodeIndex': nodeIndex,
      'text': text,
      'speaker': speaker,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory DialogueHistoryEntry.fromMap(Map<String, dynamic> map) {
    return DialogueHistoryEntry(
      sceneId: map['sceneId'] as String,
      nodeIndex: map['nodeIndex'] as int,
      text: map['text'] as String,
      speaker: map['speaker'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  @override
  String toString() {
    final speakerPart = speaker != null ? '$speaker: ' : '';
    return '$speakerPart$text';
  }
}

