import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class DialogueValidationError extends Error {
  final String message;
  DialogueValidationError(this.message);
  
  @override
  String toString() => 'DialogueValidationError: $message';
}

class DialogueStore {
  static DialogueStore? _instance;
  static DialogueStore get instance => _instance ??= DialogueStore._();
  DialogueStore._();

  final Map<String, Map<String, dynamic>> _cache = {};

  /// 개별 JSON 로드·파싱·검증·캐시
  Future<Map<String, dynamic>> loadDialogue(String path) async {
    // 캐시에서 확인
    if (_cache.containsKey(path)) {
      return _cache[path]!;
    }

    try {
      final jsonString = await rootBundle.loadString(path);
      final data = json.decode(jsonString) as Map<String, dynamic>;
      
      // JSON 유효성 검증
      _validateDialogueData(data, path);
      
      // 캐시에 저장
      _cache[path] = data;
      
      debugPrint('[DialogueStore] Loaded and cached: $path');
      return data;
    } catch (e) {
      debugPrint('[DialogueStore] Failed to load $path: $e');
      throw DialogueValidationError('Failed to load dialogue from $path: $e');
    }
  }

  /// JSON 유효성 검증
  void _validateDialogueData(Map<String, dynamic> data, String path) {
    // 기본 검증만 수행 (단순한 텍스트 기반 인카운터도 지원)
    if (data.containsKey('text')) {
      // 단순 텍스트 형식
      debugPrint('[DialogueStore] Validation passed (simple text) for $path');
      return;
    }
    
    // 오퍼레이션 기반 형식 검증 (ops)
    if (data.isNotEmpty) {
      final firstKey = data.keys.first;
      final scene = data[firstKey];
      if (scene is Map<String, dynamic> && scene.containsKey('ops')) {
        debugPrint('[DialogueStore] Validation passed (ops format) for $path');
        return;
      }
    }
    
    // 노드 기반 형식 검증
    if (data.containsKey('startNode') && data.containsKey('nodes')) {
      final nodes = data['nodes'] as Map<String, dynamic>?;
      if (nodes == null || nodes.isEmpty) {
        throw DialogueValidationError('Empty nodes in $path');
      }
      debugPrint('[DialogueStore] Validation passed (node format) for $path');
      return;
    }

    // 어떤 형식도 아니면 경고만 출력하고 통과 (유연한 처리)
    debugPrint('[DialogueStore] Warning: Unknown format in $path, but allowing it');
  }

  /// 캐시 초기화
  void clearCache() {
    _cache.clear();
  }
}








