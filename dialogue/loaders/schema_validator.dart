/// JSON 다이얼로그 스키마 검증기
/// 
/// 로드된 JSON 데이터가 올바른 형식인지 검증하고,
/// 명확한 에러 메시지를 제공합니다.

import 'package:flutter/foundation.dart';

/// 검증 에러
class DialogueValidationError implements Exception {
  final String message;
  final String? path;
  final dynamic value;

  DialogueValidationError(this.message, {this.path, this.value});

  @override
  String toString() {
    final buffer = StringBuffer('DialogueValidationError: $message');
    if (path != null) buffer.write(' at path: $path');
    if (value != null) buffer.write(' (value: $value)');
    return buffer.toString();
  }
}

/// 검증 경고 (에러는 아니지만 주의 필요)
class DialogueValidationWarning {
  final String message;
  final String? path;

  DialogueValidationWarning(this.message, {this.path});

  @override
  String toString() {
    final buffer = StringBuffer('DialogueValidationWarning: $message');
    if (path != null) buffer.write(' at path: $path');
    return buffer.toString();
  }
}

/// 검증 결과
class ValidationResult {
  final bool isValid;
  final List<DialogueValidationError> errors;
  final List<DialogueValidationWarning> warnings;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  factory ValidationResult.success({List<DialogueValidationWarning>? warnings}) {
    return ValidationResult(
      isValid: true,
      warnings: warnings ?? [],
    );
  }

  factory ValidationResult.failure(List<DialogueValidationError> errors, {List<DialogueValidationWarning>? warnings}) {
    return ValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings ?? [],
    );
  }

  /// 에러와 경고 모두 출력
  void printAll() {
    for (final error in errors) {
      debugPrint('[ERROR] $error');
    }
    for (final warning in warnings) {
      debugPrint('[WARNING] $warning');
    }
  }
}

/// JSON 다이얼로그 스키마 검증기
class SchemaValidator {
  final List<DialogueValidationError> _errors = [];
  final List<DialogueValidationWarning> _warnings = [];

  /// JSON 데이터 검증
  ValidationResult validate(Map<String, dynamic> data, String filePath) {
    _errors.clear();
    _warnings.clear();

    try {
      // 1. 기본 구조 검증
      _validateBasicStructure(data, filePath);

      // 2. 씬 검증
      _validateScenes(data, filePath);

      // 2-1. 트레잇 문법 검증 (하위 호환: 없으면 스킵)
      _validateTraitSyntax(data, filePath);

      // 3. 참조 무결성 검증
      _validateReferences(data, filePath);

      // 4. 순환 참조 검증
      _validateCircularReferences(data, filePath);

      if (_errors.isEmpty) {
        return ValidationResult.success(warnings: List.from(_warnings));
      } else {
        return ValidationResult.failure(List.from(_errors), warnings: List.from(_warnings));
      }
    } catch (e) {
      _errors.add(DialogueValidationError('Unexpected validation error: $e'));
      return ValidationResult.failure(List.from(_errors));
    }
  }

  // ===== 트레잇 검증 =====

  void _validateTraitSyntax(dynamic node, String path) {
    if (node is Map) {
      final map = node as Map;

      if (map.containsKey('has_trait')) {
        _validateHasTraitValue(map['has_trait'], '$path.has_trait');
      }
      if (map.containsKey('add_trait')) {
        _validateTraitId(map['add_trait'], '$path.add_trait');
      }
      if (map.containsKey('remove_trait')) {
        _validateTraitId(map['remove_trait'], '$path.remove_trait');
      }

      // 재귀 탐색
      for (final entry in map.entries) {
        final key = entry.key.toString();
        _validateTraitSyntax(entry.value, '$path.$key');
      }
    } else if (node is List) {
      for (var i = 0; i < node.length; i++) {
        _validateTraitSyntax(node[i], '$path[$i]');
      }
    }
  }

  void _validateHasTraitValue(dynamic value, String path) {
    // {"has_trait":"brave"}
    if (value is String) {
      _validateTraitId(value, path);
      return;
    }

    // {"has_trait":{"id":"brave"}}
    if (value is Map) {
      final m = value as Map;
      if (!m.containsKey('id')) {
        _errors.add(DialogueValidationError(
          'has_trait object must contain "id"',
          path: path,
          value: value,
        ));
        return;
      }
      _validateTraitId(m['id'], '$path.id');
      return;
    }

    _errors.add(DialogueValidationError(
      'has_trait must be a String or an object with {id: String}',
      path: path,
      value: value?.runtimeType,
    ));
  }

  void _validateTraitId(dynamic value, String path) {
    if (value is! String) {
      _errors.add(DialogueValidationError(
        'Trait id must be a non-empty String',
        path: path,
        value: value?.runtimeType,
      ));
      return;
    }

    final id = value;
    if (id.trim().isEmpty) {
      _errors.add(DialogueValidationError(
        'Trait id must be a non-empty String',
        path: path,
        value: value,
      ));
      return;
    }

    // 권장 규칙: 공백 금지 (결정론/호환성 위해)
    if (RegExp(r'\s').hasMatch(id)) {
      _errors.add(DialogueValidationError(
        'Trait id must not contain whitespace',
        path: path,
        value: value,
      ));
    }
  }

  /// 기본 구조 검증
  void _validateBasicStructure(Map<String, dynamic> data, String filePath) {
    // 완전히 빈 파일
    if (data.isEmpty) {
      _errors.add(DialogueValidationError('Empty dialogue file', path: filePath));
      return;
    }

    // 단순 텍스트 형식 (이것도 유효)
    if (data.containsKey('text') && data['text'] is String) {
      // 유효한 단순 형식
      return;
    }

    // 노드 기반 형식 검증
    if (data.containsKey('startNode') && data.containsKey('nodes')) {
      if (data['nodes'] is! Map) {
        _errors.add(DialogueValidationError(
          'nodes must be a Map',
          path: '$filePath.nodes',
          value: data['nodes'].runtimeType,
        ));
      }
      return;
    }

    // 씬 기반 형식은 더 복잡하므로 나중에 검증
  }

  /// 씬 검증
  void _validateScenes(Map<String, dynamic> data, String filePath) {
    // 단순 텍스트나 노드 기반이면 스킵
    if (data.containsKey('text') || data.containsKey('nodes')) {
      return;
    }

    // scenes 배열 형식
    if (data.containsKey('scenes') && data['scenes'] is List) {
      final scenes = data['scenes'] as List;
      for (var i = 0; i < scenes.length; i++) {
        if (scenes[i] is! Map) {
          _errors.add(DialogueValidationError(
            'Scene must be a Map',
            path: '$filePath.scenes[$i]',
            value: scenes[i].runtimeType,
          ));
          continue;
        }
        _validateScene(scenes[i] as Map<String, dynamic>, '$filePath.scenes[$i]');
      }
      return;
    }

    // 씬 맵 형식 (가장 일반적)
    for (final entry in data.entries) {
      if (entry.value is Map) {
        _validateScene(entry.value as Map<String, dynamic>, '$filePath.${entry.key}');
      }
    }
  }

  /// 개별 씬 검증
  void _validateScene(Map<String, dynamic> scene, String path) {
    // ops 배열 형식
    if (scene.containsKey('ops')) {
      if (scene['ops'] is! List) {
        _errors.add(DialogueValidationError(
          'ops must be a List',
          path: '$path.ops',
          value: scene['ops'].runtimeType,
        ));
        return;
      }
      _validateOps(scene['ops'] as List, '$path.ops');
      return;
    }

    // 전통적 start/choices 형식
    if (scene.containsKey('start')) {
      _validateNode(scene['start'], '$path.start');
    }

    if (scene.containsKey('choices')) {
      final choices = scene['choices'];
      if (choices is List) {
        for (var i = 0; i < choices.length; i++) {
          _validateChoice(choices[i], '$path.choices[$i]');
        }
      } else if (choices is Map) {
        for (final entry in (choices as Map).entries) {
          _validateChoice(entry.value, '$path.choices.${entry.key}');
        }
      } else {
        _errors.add(DialogueValidationError(
          'choices must be a List or Map',
          path: '$path.choices',
          value: choices.runtimeType,
        ));
      }
    }

    // line (레거시)
    if (scene.containsKey('line') && scene['line'] is! String) {
      _errors.add(DialogueValidationError(
        'line must be a String',
        path: '$path.line',
        value: scene['line'].runtimeType,
      ));
    }
  }

  /// ops 배열 검증
  void _validateOps(List ops, String path) {
    for (var i = 0; i < ops.length; i++) {
      if (ops[i] is! Map) {
        _errors.add(DialogueValidationError(
          'Operation must be a Map',
          path: '$path[$i]',
          value: ops[i].runtimeType,
        ));
        continue;
      }
      _validateOp(ops[i] as Map<String, dynamic>, '$path[$i]');
    }
  }

  /// 개별 operation 검증
  void _validateOp(Map<String, dynamic> op, String path) {
    // 최소한 하나의 유효한 키가 있어야 함
    const validKeys = {'say', 'choice', 'effect', 'jump', 'end'};
    final hasValidKey = op.keys.any((key) => validKeys.contains(key));

    if (!hasValidKey) {
      _warnings.add(DialogueValidationWarning(
        'Operation has no recognized keys (say, choice, effect, jump, end)',
        path: path,
      ));
    }

    // say 검증
    if (op.containsKey('say') && op['say'] is! String) {
      _errors.add(DialogueValidationError(
        'say must be a String',
        path: '$path.say',
        value: op['say'].runtimeType,
      ));
    }

    // choice 검증
    if (op.containsKey('choice')) {
      if (op['choice'] is List) {
        final choices = op['choice'] as List;
        for (var i = 0; i < choices.length; i++) {
          _validateChoice(choices[i], '$path.choice[$i]');
        }
      } else {
        _errors.add(DialogueValidationError(
          'choice must be a List',
          path: '$path.choice',
          value: op['choice'].runtimeType,
        ));
      }
    }

    // effect 검증
    if (op.containsKey('effect') && op['effect'] is! Map) {
      _errors.add(DialogueValidationError(
        'effect must be a Map',
        path: '$path.effect',
        value: op['effect'].runtimeType,
      ));
    }

    // jump 검증
    if (op.containsKey('jump')) {
      if (op['jump'] is! Map) {
        _errors.add(DialogueValidationError(
          'jump must be a Map',
          path: '$path.jump',
          value: op['jump'].runtimeType,
        ));
      } else {
        final jump = op['jump'] as Map;
        if (!jump.containsKey('scene') && !jump.containsKey('file')) {
          _warnings.add(DialogueValidationWarning(
            'jump should have scene or file',
            path: '$path.jump',
          ));
        }
      }
    }
  }

  /// 노드 검증
  void _validateNode(dynamic node, String path) {
    if (node is! Map) {
      _errors.add(DialogueValidationError(
        'Node must be a Map',
        path: path,
        value: node.runtimeType,
      ));
      return;
    }

    final nodeMap = node as Map<String, dynamic>;

    // text 필드 검증
    if (nodeMap.containsKey('text') && nodeMap['text'] is! String) {
      _errors.add(DialogueValidationError(
        'text must be a String',
        path: '$path.text',
        value: nodeMap['text'].runtimeType,
      ));
    }
  }

  /// 선택지 검증
  void _validateChoice(dynamic choice, String path) {
    if (choice is! Map) {
      _errors.add(DialogueValidationError(
        'Choice must be a Map',
        path: path,
        value: choice.runtimeType,
      ));
      return;
    }

    final choiceMap = choice as Map<String, dynamic>;

    // 필수 필드: text
    if (!choiceMap.containsKey('text') && !choiceMap.containsKey('id')) {
      _errors.add(DialogueValidationError(
        'Choice must have text or id',
        path: path,
      ));
    }

    // text 타입 검증
    if (choiceMap.containsKey('text') && choiceMap['text'] is! String) {
      _errors.add(DialogueValidationError(
        'Choice text must be a String',
        path: '$path.text',
        value: choiceMap['text'].runtimeType,
      ));
    }

    // enabled 타입 검증
    if (choiceMap.containsKey('enabled') && choiceMap['enabled'] is! bool) {
      _errors.add(DialogueValidationError(
        'enabled must be a bool',
        path: '$path.enabled',
        value: choiceMap['enabled'].runtimeType,
      ));
    }
  }

  /// 참조 무결성 검증 (next_scene이 실제로 존재하는지)
  void _validateReferences(Map<String, dynamic> data, String filePath) {
    // 모든 씬 ID 수집
    final sceneIds = <String>{};
    
    if (data.containsKey('scenes') && data['scenes'] is List) {
      for (final scene in data['scenes'] as List) {
        if (scene is Map && scene.containsKey('id')) {
          sceneIds.add(scene['id'].toString());
        }
      }
    } else {
      // 씬 맵 형식
      sceneIds.addAll(data.keys.where((key) => data[key] is Map));
    }

    // 'end'와 'start'는 특수 키
    sceneIds.add('end');
    sceneIds.add('start');

    // 모든 next_scene 참조 검증
    _validateSceneReferences(data, sceneIds, filePath);
  }

  void _validateSceneReferences(dynamic node, Set<String> validSceneIds, String path) {
    if (node is Map) {
      for (final entry in (node as Map).entries) {
        final key = entry.key.toString();
        final value = entry.value;

        if (key == 'next_scene' && value is String && value.isNotEmpty) {
          if (!validSceneIds.contains(value)) {
            _warnings.add(DialogueValidationWarning(
              'next_scene "$value" not found in this file',
              path: path,
            ));
          }
        }

        _validateSceneReferences(value, validSceneIds, '$path.$key');
      }
    } else if (node is List) {
      for (var i = 0; i < node.length; i++) {
        _validateSceneReferences(node[i], validSceneIds, '$path[$i]');
      }
    }
  }

  /// 순환 참조 검증 (씬 A -> B -> A 같은 경우)
  void _validateCircularReferences(Map<String, dynamic> data, String filePath) {
    // 간단한 순환 참조 감지
    // 복잡한 그래프 분석은 나중에 필요시 추가
    
    final visited = <String>{};
    final stack = <String>[];

    void dfs(String sceneId) {
      if (stack.contains(sceneId)) {
        _warnings.add(DialogueValidationWarning(
          'Possible circular reference detected: ${stack.join(' -> ')} -> $sceneId',
          path: filePath,
        ));
        return;
      }

      if (visited.contains(sceneId)) return;

      visited.add(sceneId);
      stack.add(sceneId);

      // 이 씬의 모든 next_scene 찾기
      final scene = data[sceneId];
      if (scene is Map) {
        _findNextScenes(scene).forEach(dfs);
      }

      stack.removeLast();
    }

    // 모든 씬에서 시작
    for (final key in data.keys) {
      if (data[key] is Map) {
        dfs(key);
      }
    }
  }

  Set<String> _findNextScenes(Map scene) {
    final nextScenes = <String>{};

    void search(dynamic node) {
      if (node is Map) {
        if (node.containsKey('next_scene') && node['next_scene'] is String) {
          nextScenes.add(node['next_scene'] as String);
        }
        node.values.forEach(search);
      } else if (node is List) {
        node.forEach(search);
      }
    }

    search(scene);
    return nextScenes;
  }
}

