/// 다이얼로그 시스템의 핵심 데이터 모델
/// 
/// 이 파일은 모든 다이얼로그 데이터의 타입 안전한 표현을 제공합니다.
/// 불변(immutable) 객체로 설계되어 예측 가능하고 안전한 상태 관리를 지원합니다.

/// 다이얼로그 파일 전체를 나타내는 최상위 컨테이너
class DialogueData {
  /// 다이얼로그 파일의 고유 식별자
  final String id;
  
  /// 시작 씬의 ID
  final String startSceneId;
  
  /// 모든 씬들의 맵 (sceneId -> DialogueScene)
  final Map<String, DialogueScene> scenes;
  
  /// 파일 레벨 메타데이터 (선택적)
  final Map<String, dynamic>? metadata;

  const DialogueData({
    required this.id,
    required this.startSceneId,
    required this.scenes,
    this.metadata,
  });

  /// 특정 씬 가져오기
  DialogueScene? getScene(String sceneId) => scenes[sceneId];

  /// 유효성 검증
  bool validate() {
    if (scenes.isEmpty) return false;
    if (!scenes.containsKey(startSceneId)) return false;
    
    // 모든 씬의 next 참조가 유효한지 확인
    for (final scene in scenes.values) {
      for (final node in scene.nodes) {
        for (final choice in node.choices) {
          if (choice.nextScene != null && 
              choice.nextScene != 'end' && 
              !scenes.containsKey(choice.nextScene)) {
            return false;
          }
        }
      }
    }
    
    return true;
  }

  @override
  String toString() => 'DialogueData(id: $id, scenes: ${scenes.length})';
}

/// 하나의 대화 씬 (여러 노드로 구성)
class DialogueScene {
  /// 씬의 고유 식별자
  final String id;
  
  /// 씬 내의 모든 노드들 (순서대로)
  final List<DialogueNode> nodes;
  
  /// 씬 진입 시 실행할 효과들
  final List<DialogueEffect> onEnterEffects;
  
  /// 씬 종료 시 실행할 효과들
  final List<DialogueEffect> onExitEffects;
  
  /// 씬 레벨 메타데이터
  final Map<String, dynamic>? metadata;

  const DialogueScene({
    required this.id,
    required this.nodes,
    this.onEnterEffects = const [],
    this.onExitEffects = const [],
    this.metadata,
  });

  /// 시작 노드 가져오기
  DialogueNode? get startNode => nodes.isNotEmpty ? nodes.first : null;

  @override
  String toString() => 'DialogueScene(id: $id, nodes: ${nodes.length})';
}

/// 대화의 개별 노드 (텍스트 + 선택지)
class DialogueNode {
  /// 노드의 고유 식별자 (씬 내에서)
  final String id;
  
  /// 표시할 텍스트 (null이면 선택지만 표시)
  final String? text;
  
  /// 화자 이름 (선택적)
  final String? speaker;
  
  /// 선택지 목록
  final List<DialogueChoice> choices;
  
  /// 노드 표시 시 실행할 효과들
  final List<DialogueEffect> effects;
  
  /// 노드 표시 조건들
  final List<DialogueCondition> conditions;
  
  /// 노드 타입 (say, choice, effect 등)
  final DialogueNodeType type;
  
  /// 추가 메타데이터
  final Map<String, dynamic>? metadata;

  const DialogueNode({
    required this.id,
    this.text,
    this.speaker,
    this.choices = const [],
    this.effects = const [],
    this.conditions = const [],
    this.type = DialogueNodeType.say,
    this.metadata,
  });

  /// 조건이 모두 충족되는지 확인
  bool meetsConditions(Map<String, dynamic> gameState) {
    if (conditions.isEmpty) return true;
    return conditions.every((condition) => condition.evaluate(gameState));
  }

  /// 이 노드가 텍스트를 표시하는가
  bool get hasText => text != null && text!.isNotEmpty;

  /// 이 노드가 선택지를 가지는가
  bool get hasChoices => choices.isNotEmpty;

  @override
  String toString() => 'DialogueNode(id: $id, type: $type, choices: ${choices.length})';
}

/// 노드의 타입
enum DialogueNodeType {
  /// 텍스트 표시
  say,
  
  /// 선택지 제시
  choice,
  
  /// 효과만 실행 (표시 없이)
  effect,
  
  /// 조건 분기
  conditional,
  
  /// 다른 파일/씬으로 점프
  jump,
  
  /// 대화 종료
  end,
}

/// 선택지
class DialogueChoice {
  /// 선택지의 고유 식별자
  final String id;
  
  /// 선택지에 표시될 텍스트
  final String text;
  
  /// 다음 씬 ID (null이면 같은 씬 내 다음 노드)
  final String? nextScene;
  
  /// 다음 노드 ID (씬 내 특정 노드로)
  final String? nextNode;
  
  /// 다른 파일로 점프
  final DialogueJump? jump;
  
  /// 선택 시 실행할 효과들
  final List<DialogueEffect> effects;
  
  /// 선택지 표시 조건들
  final List<DialogueCondition> conditions;
  
  /// 선택지가 활성화되어 있는가
  final bool enabled;
  
  /// 비활성화된 경우 표시할 이유
  final String? disabledReason;
  
  /// 이 선택지가 중요한 분기점인가
  final bool isBranchPoint;
  
  /// 선택지 메타데이터 (스킬 체크 정보 등)
  final Map<String, dynamic>? metadata;

  const DialogueChoice({
    required this.id,
    required this.text,
    this.nextScene,
    this.nextNode,
    this.jump,
    this.effects = const [],
    this.conditions = const [],
    this.enabled = true,
    this.disabledReason,
    this.isBranchPoint = false,
    this.metadata,
  });

  /// 조건이 모두 충족되는지 확인
  bool meetsConditions(Map<String, dynamic> gameState) {
    if (conditions.isEmpty) return true;
    return conditions.every((condition) => condition.evaluate(gameState));
  }

  /// 이 선택지가 실제로 선택 가능한가
  bool isSelectable(Map<String, dynamic> gameState) {
    return enabled && meetsConditions(gameState);
  }

  @override
  String toString() => 'DialogueChoice(id: $id, text: $text)';
}

/// 다른 파일/씬으로 점프
class DialogueJump {
  /// 대상 파일 경로 (null이면 현재 파일)
  final String? filePath;
  
  /// 대상 씬 ID
  final String sceneId;
  
  /// 대상 노드 ID (선택적)
  final String? nodeId;

  const DialogueJump({
    this.filePath,
    required this.sceneId,
    this.nodeId,
  });

  @override
  String toString() => 'DialogueJump(file: $filePath, scene: $sceneId)';
}

/// 효과 (게임 상태 변경)
class DialogueEffect {
  /// 효과 타입
  final DialogueEffectType type;
  
  /// 효과 데이터
  final Map<String, dynamic> data;
  
  /// 효과 설명 (로깅/디버깅용)
  final String? description;

  const DialogueEffect({
    required this.type,
    required this.data,
    this.description,
  });

  @override
  String toString() => 'DialogueEffect(type: $type, data: $data)';
}

/// 효과 타입
enum DialogueEffectType {
  /// 스탯 변경
  changeStat,
  
  /// 아이템 추가
  addItem,
  
  /// 아이템 제거
  removeItem,
  
  /// 플래그 설정
  setFlag,
  
  /// 씬 변경
  changeScene,
  
  /// 커스텀 이벤트 발생
  customEvent,
}

/// 조건 (표시/선택 가능 여부 결정)
class DialogueCondition {
  /// 조건 타입
  final DialogueConditionType type;
  
  /// 조건 데이터
  final Map<String, dynamic> data;
  
  /// 조건 설명
  final String? description;

  const DialogueCondition({
    required this.type,
    required this.data,
    this.description,
  });

  /// 조건 평가
  bool evaluate(Map<String, dynamic> gameState) {
    switch (type) {
      case DialogueConditionType.hasStat:
        final stat = data['stat'] as String?;
        final minValue = data['min'] as num?;
        final maxValue = data['max'] as num?;
        if (stat == null) return false;
        
        final stats = gameState['stats'] as Map<String, dynamic>?;
        if (stats == null) return false;
        
        final value = stats[stat] as num?;
        if (value == null) return false;
        
        if (minValue != null && value < minValue) return false;
        if (maxValue != null && value > maxValue) return false;
        
        return true;

      case DialogueConditionType.hasItem:
        final item = data['item'] as String?;
        if (item == null) return false;
        
        final items = gameState['items'] as List?;
        if (items == null) return false;
        
        return items.contains(item);

      case DialogueConditionType.hasFlag:
        final flag = data['flag'] as String?;
        final expectedValue = data['value'] as bool? ?? true;
        if (flag == null) return false;
        
        final flags = gameState['flags'] as Map<String, dynamic>?;
        if (flags == null) return false;
        
        return flags[flag] == expectedValue;

      case DialogueConditionType.custom:
        // 커스텀 조건은 외부에서 평가
        return data['result'] as bool? ?? false;

      case DialogueConditionType.and:
        final conditions = data['conditions'] as List<DialogueCondition>?;
        if (conditions == null || conditions.isEmpty) return true;
        return conditions.every((c) => c.evaluate(gameState));

      case DialogueConditionType.or:
        final conditions = data['conditions'] as List<DialogueCondition>?;
        if (conditions == null || conditions.isEmpty) return false;
        return conditions.any((c) => c.evaluate(gameState));

      case DialogueConditionType.not:
        final condition = data['condition'] as DialogueCondition?;
        if (condition == null) return true;
        return !condition.evaluate(gameState);
    }
  }

  @override
  String toString() => 'DialogueCondition(type: $type)';
}

/// 조건 타입
enum DialogueConditionType {
  /// 스탯 조건
  hasStat,
  
  /// 아이템 소유 조건
  hasItem,
  
  /// 플래그 조건
  hasFlag,
  
  /// 커스텀 조건
  custom,
  
  /// AND 조건
  and,
  
  /// OR 조건
  or,
  
  /// NOT 조건
  not,
}

