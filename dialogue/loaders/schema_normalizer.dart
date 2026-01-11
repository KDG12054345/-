/// JSON 스키마 정규화 시스템
/// 
/// 다양한 형식의 JSON 다이얼로그 파일을 하나의 표준 형식으로 변환합니다.
/// 이를 통해 하위 호환성을 보장하면서 내부 로직은 단순하게 유지할 수 있습니다.

import 'package:flutter/foundation.dart';
import '../core/dialogue_data.dart';

/// 정규화 에러
class NormalizationError implements Exception {
  final String message;
  final String? path;

  NormalizationError(this.message, {this.path});

  @override
  String toString() {
    final buffer = StringBuffer('NormalizationError: $message');
    if (path != null) buffer.write(' at $path');
    return buffer.toString();
  }
}

/// 감지된 스키마 형식
enum SchemaFormat {
  /// 단순 텍스트 형식: {"text": "..."}
  simpleText,
  
  /// 노드 기반 형식: {"startNode": "...", "nodes": {...}}
  nodeBased,
  
  /// 씬 기반 형식: {"scene_1": {"start": {...}, "choices": {...}}}
  sceneBased,
  
  /// 오퍼레이션 기반 형식: {"scene_1": {"ops": [...]}}
  operationBased,
  
  /// 씬 배열 형식: {"scenes": [{"id": "...", ...}]}
  sceneArray,
  
  /// 알 수 없는 형식
  unknown,
}

/// 스키마 정규화기
class SchemaNormalizer {
  /// JSON 데이터를 DialogueData로 변환
  /// 
  /// [data] - 원본 JSON 데이터
  /// [fileId] - 파일 식별자
  /// [filePath] - 파일 경로 (에러 메시지용)
  DialogueData normalize(
    Map<String, dynamic> data,
    String fileId,
    String filePath,
  ) {
    // 1. 형식 감지
    final format = detectFormat(data);
    debugPrint('[SchemaNormalizer] Detected format: $format for $filePath');

    // 2. 형식에 맞는 변환 수행
    final Map<String, DialogueScene> scenes;
    final String startSceneId;

    switch (format) {
      case SchemaFormat.simpleText:
        final result = _normalizeSimpleText(data, filePath);
        scenes = result.scenes;
        startSceneId = result.startSceneId;
        break;

      case SchemaFormat.nodeBased:
        final result = _normalizeNodeBased(data, filePath);
        scenes = result.scenes;
        startSceneId = result.startSceneId;
        break;

      case SchemaFormat.sceneBased:
        final result = _normalizeSceneBased(data, filePath);
        scenes = result.scenes;
        startSceneId = result.startSceneId;
        break;

      case SchemaFormat.operationBased:
        final result = _normalizeOperationBased(data, filePath);
        scenes = result.scenes;
        startSceneId = result.startSceneId;
        break;

      case SchemaFormat.sceneArray:
        final result = _normalizeSceneArray(data, filePath);
        scenes = result.scenes;
        startSceneId = result.startSceneId;
        break;

      case SchemaFormat.unknown:
        throw NormalizationError(
          'Unable to determine dialogue format',
          path: filePath,
        );
    }

    return DialogueData(
      id: fileId,
      startSceneId: startSceneId,
      scenes: scenes,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// 형식 감지
  SchemaFormat detectFormat(Map<String, dynamic> data) {
    // 1. 단순 텍스트 형식
    if (data.containsKey('text') && data['text'] is String) {
      return SchemaFormat.simpleText;
    }

    // 2. 노드 기반 형식
    if (data.containsKey('startNode') && data.containsKey('nodes')) {
      return SchemaFormat.nodeBased;
    }

    // 3. 씬 배열 형식
    if (data.containsKey('scenes') && data['scenes'] is List) {
      return SchemaFormat.sceneArray;
    }

    // 4. 오퍼레이션 vs 씬 기반 형식 구분
    // 최소한 하나의 씬이 있어야 함
    // ✅ metadata 키 제외
    final sceneKeys = data.keys
        .where((key) => key != 'metadata' && data[key] is Map)
        .toList();
    
    if (sceneKeys.isEmpty) {
      return SchemaFormat.unknown;
    }

    // 첫 번째 씬 확인
    final firstScene = data[sceneKeys.first] as Map;
    
    if (firstScene.containsKey('ops')) {
      return SchemaFormat.operationBased;
    } else if (firstScene.containsKey('start') || 
               firstScene.containsKey('line') || 
               firstScene.containsKey('choices')) {
      return SchemaFormat.sceneBased;
    }

    return SchemaFormat.unknown;
  }

  /// 단순 텍스트 형식 정규화
  _NormalizeResult _normalizeSimpleText(Map<String, dynamic> data, String filePath) {
    final text = data['text'] as String;
    
    final node = DialogueNode(
      id: 'main',
      text: text,
      type: DialogueNodeType.say,
    );

    final scene = DialogueScene(
      id: 'main',
      nodes: [node],
    );

    return _NormalizeResult(
      scenes: {'main': scene},
      startSceneId: 'main',
    );
  }

  /// 노드 기반 형식 정규화
  _NormalizeResult _normalizeNodeBased(Map<String, dynamic> data, String filePath) {
    final startNodeId = data['startNode'] as String;
    final nodesData = data['nodes'] as Map<String, dynamic>;

    final scenes = <String, DialogueScene>{};

    // 각 노드를 씬으로 변환
    for (final entry in nodesData.entries) {
      final nodeId = entry.key;
      final nodeData = entry.value as Map<String, dynamic>;

      final node = _parseNode(nodeData, nodeId);
      
      scenes[nodeId] = DialogueScene(
        id: nodeId,
        nodes: [node],
      );
    }

    return _NormalizeResult(
      scenes: scenes,
      startSceneId: startNodeId,
    );
  }

  /// 씬 기반 형식 정규화 (가장 일반적)
  _NormalizeResult _normalizeSceneBased(Map<String, dynamic> data, String filePath) {
    final scenes = <String, DialogueScene>{};
    String? startSceneId;

    for (final entry in data.entries) {
      final sceneId = entry.key;
      
      // 메타데이터 키는 스킵
      if (sceneId == 'metadata') continue;
      
      final sceneData = entry.value;
      if (sceneData is! Map<String, dynamic>) continue;

      // 첫 번째 씬을 시작 씬으로
      startSceneId ??= sceneId;

      final nodes = <DialogueNode>[];

      // start 노드 처리
      if (sceneData.containsKey('start')) {
        final startData = sceneData['start'];
        if (startData is Map<String, dynamic>) {
          nodes.add(_parseNode(startData, 'start'));
        } else if (startData is String) {
          nodes.add(DialogueNode(
            id: 'start',
            text: startData,
            type: DialogueNodeType.say,
          ));
        }
      } else if (sceneData.containsKey('line')) {
        // 레거시: line 필드
        nodes.add(DialogueNode(
          id: 'start',
          text: sceneData['line'] as String,
          type: DialogueNodeType.say,
        ));
      }

      // choices 처리
      if (sceneData.containsKey('choices')) {
        final choicesData = sceneData['choices'];
        final choices = _parseChoices(choicesData);
        
        if (choices.isNotEmpty) {
          // 선택지가 있으면 choice 노드 추가
          nodes.add(DialogueNode(
            id: 'choices',
            choices: choices,
            type: DialogueNodeType.choice,
          ));
        }
      }

      if (nodes.isNotEmpty) {
        scenes[sceneId] = DialogueScene(
          id: sceneId,
          nodes: nodes,
        );
      }
    }

    return _NormalizeResult(
      scenes: scenes,
      startSceneId: startSceneId ?? 'start',
    );
  }

  /// 오퍼레이션 기반 형식 정규화
  _NormalizeResult _normalizeOperationBased(Map<String, dynamic> data, String filePath) {
    final scenes = <String, DialogueScene>{};
    String? startSceneId;

    for (final entry in data.entries) {
      final sceneId = entry.key;
      if (sceneId == 'metadata') continue;
      
      final sceneData = entry.value;
      if (sceneData is! Map<String, dynamic>) continue;

      startSceneId ??= sceneId;

      if (!sceneData.containsKey('ops')) continue;
      
      final ops = sceneData['ops'] as List;
      final nodes = <DialogueNode>[];

      for (var i = 0; i < ops.length; i++) {
        if (ops[i] is! Map<String, dynamic>) continue;
        
        final op = ops[i] as Map<String, dynamic>;
        final node = _parseOperation(op, 'op_$i');
        if (node != null) {
          nodes.add(node);
        }
      }

      if (nodes.isNotEmpty) {
        scenes[sceneId] = DialogueScene(
          id: sceneId,
          nodes: nodes,
        );
      }
    }

    return _NormalizeResult(
      scenes: scenes,
      startSceneId: startSceneId ?? 'start',
    );
  }

  /// 씬 배열 형식 정규화
  _NormalizeResult _normalizeSceneArray(Map<String, dynamic> data, String filePath) {
    final scenesArray = data['scenes'] as List;
    final scenes = <String, DialogueScene>{};
    String? startSceneId;

    for (final sceneData in scenesArray) {
      if (sceneData is! Map<String, dynamic>) continue;
      if (!sceneData.containsKey('id')) continue;

      final sceneId = sceneData['id'] as String;
      startSceneId ??= sceneId;

      // ops가 있으면 오퍼레이션 기반으로 파싱
      if (sceneData.containsKey('ops')) {
        final ops = sceneData['ops'] as List;
        final nodes = <DialogueNode>[];

        for (var i = 0; i < ops.length; i++) {
          if (ops[i] is! Map<String, dynamic>) continue;
          final op = ops[i] as Map<String, dynamic>;
          final node = _parseOperation(op, 'op_$i');
          if (node != null) nodes.add(node);
        }

        if (nodes.isNotEmpty) {
          scenes[sceneId] = DialogueScene(id: sceneId, nodes: nodes);
        }
      } else {
        // 씬 기반으로 파싱
        // (간단하게 처리 - 필요시 확장)
        final nodes = <DialogueNode>[];
        if (sceneData.containsKey('text')) {
          nodes.add(DialogueNode(
            id: 'main',
            text: sceneData['text'] as String,
            type: DialogueNodeType.say,
          ));
        }
        if (nodes.isNotEmpty) {
          scenes[sceneId] = DialogueScene(id: sceneId, nodes: nodes);
        }
      }
    }

    return _NormalizeResult(
      scenes: scenes,
      startSceneId: startSceneId ?? 'start',
    );
  }

  /// 노드 데이터 파싱
  DialogueNode _parseNode(Map<String, dynamic> nodeData, String nodeId) {
    final text = nodeData['text'] as String?;
    final speaker = nodeData['speaker'] as String?;
    
    final choices = nodeData.containsKey('choices')
        ? _parseChoices(nodeData['choices'])
        : <DialogueChoice>[];

    final effects = nodeData.containsKey('effects')
        ? _parseEffects(nodeData['effects'])
        : <DialogueEffect>[];

    final conditions = nodeData.containsKey('conditions')
        ? _parseConditions(nodeData['conditions'])
        : <DialogueCondition>[];

    return DialogueNode(
      id: nodeId,
      text: text,
      speaker: speaker,
      choices: choices,
      effects: effects,
      conditions: conditions,
      type: choices.isNotEmpty ? DialogueNodeType.choice : DialogueNodeType.say,
      metadata: nodeData['metadata'] as Map<String, dynamic>?,
    );
  }

  /// 오퍼레이션 파싱
  DialogueNode? _parseOperation(Map<String, dynamic> op, String nodeId) {
    // say 오퍼레이션
    if (op.containsKey('say')) {
      return DialogueNode(
        id: nodeId,
        text: op['say'] as String,
        type: DialogueNodeType.say,
      );
    }

    // choice 오퍼레이션
    if (op.containsKey('choice')) {
      final choices = _parseChoices(op['choice']);
      return DialogueNode(
        id: nodeId,
        choices: choices,
        type: DialogueNodeType.choice,
      );
    }

    // effect 오퍼레이션
    if (op.containsKey('effect')) {
      final effectData = op['effect'] as Map<String, dynamic>;
      final effects = _parseEffectsFromMap(effectData);
      return DialogueNode(
        id: nodeId,
        effects: effects,
        type: DialogueNodeType.effect,
      );
    }

    // jump 오퍼레이션
    if (op.containsKey('jump')) {
      final jumpData = op['jump'] as Map<String, dynamic>;
      final jump = DialogueJump(
        filePath: jumpData['file'] as String?,
        sceneId: jumpData['scene'] as String? ?? '',
        nodeId: jumpData['node'] as String?,
      );
      
      // jump를 특수한 선택지로 변환 (자동 진행)
      return DialogueNode(
        id: nodeId,
        choices: [
          DialogueChoice(
            id: 'auto_jump',
            text: '[Continue]',
            jump: jump,
          ),
        ],
        type: DialogueNodeType.jump,
      );
    }

    // end 오퍼레이션
    if (op['end'] == true) {
      return DialogueNode(
        id: nodeId,
        type: DialogueNodeType.end,
      );
    }

    return null;
  }

  /// 선택지들 파싱
  List<DialogueChoice> _parseChoices(dynamic choicesData) {
    final choices = <DialogueChoice>[];

    if (choicesData is List) {
      for (var i = 0; i < choicesData.length; i++) {
        if (choicesData[i] is! Map<String, dynamic>) continue;
        final choiceData = choicesData[i] as Map<String, dynamic>;
        choices.add(_parseChoice(choiceData, 'choice_$i'));
      }
    } else if (choicesData is Map) {
      for (final entry in (choicesData as Map).entries) {
        if (entry.value is! Map<String, dynamic>) continue;
        final choiceData = entry.value as Map<String, dynamic>;
        choices.add(_parseChoice(choiceData, entry.key.toString()));
      }
    }

    return choices;
  }

  /// 개별 선택지 파싱
  DialogueChoice _parseChoice(Map<String, dynamic> choiceData, String defaultId) {
    final id = (choiceData['id'] ?? 
                choiceData['key'] ?? 
                defaultId).toString();
    final text = (choiceData['text'] ?? '').toString();
    
    // next 처리 (여러 형식 지원)
    String? nextScene;
    String? nextNode;
    DialogueJump? jump;

    if (choiceData.containsKey('next_scene')) {
      nextScene = choiceData['next_scene'] as String?;
    } else if (choiceData.containsKey('next')) {
      final next = choiceData['next'];
      if (next is String) {
        nextScene = next;
      } else if (next is Map) {
        final nextMap = next as Map<String, dynamic>;
        // ✅ next: { "end": true } 처리
        if (nextMap.containsKey('end') && nextMap['end'] == true) {
          nextScene = 'end';
        } else if (nextMap.containsKey('scene')) {
          nextScene = nextMap['scene'] as String?;
        }
        if (nextMap.containsKey('node')) {
          nextNode = nextMap['node'] as String?;
        }
        if (nextMap.containsKey('jump')) {
          final jumpData = nextMap['jump'] as Map<String, dynamic>;
          jump = DialogueJump(
            filePath: jumpData['file'] as String?,
            sceneId: jumpData['scene'] as String? ?? '',
            nodeId: jumpData['node'] as String?,
          );
        }
      }
    }

    final effects = choiceData.containsKey('effects')
        ? _parseEffects(choiceData['effects'])
        : <DialogueEffect>[];

    final conditions = choiceData.containsKey('conditions')
        ? _parseConditions(choiceData['conditions'])
        : <DialogueCondition>[];

    final enabled = choiceData['enabled'] as bool? ?? true;
    final disabledReason = choiceData['disabled_reason'] as String?;
    final isBranchPoint = choiceData['branch'] as bool? ?? false;

    return DialogueChoice(
      id: id,
      text: text,
      nextScene: nextScene,
      nextNode: nextNode,
      jump: jump,
      effects: effects,
      conditions: conditions,
      enabled: enabled,
      disabledReason: disabledReason,
      isBranchPoint: isBranchPoint,
      metadata: choiceData['metadata'] as Map<String, dynamic>?,
    );
  }

  /// 효과들 파싱 (배열 형식)
  List<DialogueEffect> _parseEffects(dynamic effectsData) {
    if (effectsData is! List) return [];

    final effects = <DialogueEffect>[];
    for (final effectData in effectsData) {
      if (effectData is! Map<String, dynamic>) continue;

      // ===== 트레잇 shorthand 지원 (하위 호환/확장) =====
      // {"add_trait":"brave"} / {"remove_trait":"brave"}
      if (effectData.containsKey('add_trait')) {
        final id = effectData['add_trait'];
        effects.add(DialogueEffect(
          // 기존 enum 확장 없이 customEvent로 표준화
          type: DialogueEffectType.customEvent,
          data: {'event_type': 'add_trait', 'id': id},
          description: effectData['description'] as String?,
        ));
        continue;
      }
      if (effectData.containsKey('remove_trait')) {
        final id = effectData['remove_trait'];
        effects.add(DialogueEffect(
          type: DialogueEffectType.customEvent,
          data: {'event_type': 'remove_trait', 'id': id},
          description: effectData['description'] as String?,
        ));
        continue;
      }
      
      final type = _parseEffectType(effectData['type'] as String?);
      if (type == null) continue;

      effects.add(DialogueEffect(
        type: type,
        data: Map<String, dynamic>.from(effectData['data'] as Map? ?? {}),
        description: effectData['description'] as String?,
      ));
    }

    return effects;
  }

  /// 효과들 파싱 (맵 형식 - 오퍼레이션 기반)
  List<DialogueEffect> _parseEffectsFromMap(Map<String, dynamic> effectData) {
    final effects = <DialogueEffect>[];

    // stat 변경
    if (effectData.containsKey('stat')) {
      effects.add(DialogueEffect(
        type: DialogueEffectType.changeStat,
        data: {'stats': effectData['stat']},
      ));
    }

    // flag 설정
    if (effectData.containsKey('flag')) {
      effects.add(DialogueEffect(
        type: DialogueEffectType.setFlag,
        data: {'flags': effectData['flag']},
      ));
    }

    // item 추가/제거
    if (effectData.containsKey('item')) {
      final itemData = effectData['item'] as Map<String, dynamic>;
      if (itemData.containsKey('add')) {
        effects.add(DialogueEffect(
          type: DialogueEffectType.addItem,
          data: {'item': itemData['add']},
        ));
      }
      if (itemData.containsKey('remove')) {
        effects.add(DialogueEffect(
          type: DialogueEffectType.removeItem,
          data: {'item': itemData['remove']},
        ));
      }
    }

    // trait 추가/제거 (오퍼레이션 기반 effect 맵 확장)
    if (effectData.containsKey('add_trait')) {
      effects.add(DialogueEffect(
        type: DialogueEffectType.customEvent,
        data: {'event_type': 'add_trait', 'id': effectData['add_trait']},
      ));
    }
    if (effectData.containsKey('remove_trait')) {
      effects.add(DialogueEffect(
        type: DialogueEffectType.customEvent,
        data: {'event_type': 'remove_trait', 'id': effectData['remove_trait']},
      ));
    }

    return effects;
  }

  /// 효과 타입 파싱
  DialogueEffectType? _parseEffectType(String? typeStr) {
    if (typeStr == null) return null;

    switch (typeStr.toLowerCase()) {
      case 'changestat':
      case 'change_stat':
        return DialogueEffectType.changeStat;
      case 'additem':
      case 'add_item':
        return DialogueEffectType.addItem;
      case 'removeitem':
      case 'remove_item':
        return DialogueEffectType.removeItem;
      case 'setflag':
      case 'set_flag':
        return DialogueEffectType.setFlag;
      case 'changescene':
      case 'change_scene':
        return DialogueEffectType.changeScene;
      case 'customevent':
      case 'custom_event':
        return DialogueEffectType.customEvent;
      default:
        return null;
    }
  }

  /// 조건들 파싱
  List<DialogueCondition> _parseConditions(dynamic conditionsData) {
    if (conditionsData is! Map<String, dynamic>) return [];

    final conditions = <DialogueCondition>[];

    // 각 조건 타입별로 파싱
    if (conditionsData.containsKey('stats')) {
      final stats = conditionsData['stats'] as Map<String, dynamic>;
      for (final entry in stats.entries) {
        conditions.add(DialogueCondition(
          type: DialogueConditionType.hasStat,
          data: {'stat': entry.key, 'min': entry.value},
        ));
      }
    }

    if (conditionsData.containsKey('items')) {
      final items = conditionsData['items'] as List;
      for (final item in items) {
        conditions.add(DialogueCondition(
          type: DialogueConditionType.hasItem,
          data: {'item': item},
        ));
      }
    }

    if (conditionsData.containsKey('flags')) {
      final flags = conditionsData['flags'] as Map<String, dynamic>;
      for (final entry in flags.entries) {
        conditions.add(DialogueCondition(
          type: DialogueConditionType.hasFlag,
          data: {'flag': entry.key, 'value': entry.value},
        ));
      }
    }

    // ===== 트레잇 조건 확장 =====
    // 지원 입력:
    // - {"has_trait": "brave"}
    // - {"has_trait": {"id": "brave"}}
    if (conditionsData.containsKey('has_trait')) {
      final raw = conditionsData['has_trait'];
      String? id;
      if (raw is String) {
        id = raw;
      } else if (raw is Map) {
        final m = Map<String, dynamic>.from(raw as Map);
        if (m['id'] is String) id = m['id'] as String;
      }

      // 내부 표준화: enum 확장 없이 custom 조건으로 표현
      if (id != null) {
        conditions.add(DialogueCondition(
          type: DialogueConditionType.custom,
          data: {'type': 'has_trait', 'id': id},
        ));
      }
    }

    return conditions;
  }
}

/// 정규화 결과 (내부용)
class _NormalizeResult {
  final Map<String, DialogueScene> scenes;
  final String startSceneId;

  _NormalizeResult({
    required this.scenes,
    required this.startSceneId,
  });
}

