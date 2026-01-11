/// 다이얼로그 플러그인 인터페이스
/// 
/// 플러그인은 다이얼로그 엔진의 다양한 시점에 훅을 제공받아
/// 커스텀 로직을 실행할 수 있습니다.

import 'package:flutter/foundation.dart';
import '../core/dialogue_data.dart';
import '../core/dialogue_runtime.dart';
import '../dialogue_engine.dart';

/// 플러그인 컨텍스트 (플러그인이 접근할 수 있는 정보)
class DialoguePluginContext {
  /// 다이얼로그 엔진
  final DialogueEngine engine;
  
  /// 현재 런타임
  DialogueRuntime? get runtime => engine.runtime;
  
  /// 현재 다이얼로그 데이터
  DialogueData? get dialogueData => runtime?.dialogueData;

  const DialoguePluginContext(this.engine);
}

/// 플러그인 베이스 인터페이스
/// 
/// 모든 훅은 선택적(optional)입니다.
/// 필요한 훅만 오버라이드하여 구현하면 됩니다.
abstract class DialoguePlugin {
  /// 플러그인 고유 ID
  String get id;
  
  /// 플러그인 이름
  String get name;
  
  /// 플러그인 우선순위 (낮을수록 먼저 실행, 기본: 100)
  int get priority => 100;
  
  /// 플러그인 활성화 여부
  bool get isEnabled => true;

  // ========== 생명주기 훅 ==========

  /// 엔진 초기화 시
  /// 
  /// 엔진이 생성될 때 한 번 호출됩니다.
  Future<void> onEngineInit(DialoguePluginContext context) async {}

  /// 다이얼로그 로드 완료 후
  /// 
  /// [dialogueData] - 로드된 다이얼로그 데이터
  Future<void> onDialogueLoaded(
    DialoguePluginContext context,
    DialogueData dialogueData,
  ) async {}

  /// 다이얼로그 시작 시
  /// 
  /// [sceneId] - 시작 씬 ID
  Future<void> onDialogueStarted(
    DialoguePluginContext context,
    String sceneId,
  ) async {}

  // ========== 씬 관련 훅 ==========

  /// 씬 진입 전
  /// 
  /// [scene] - 진입할 씬
  /// 
  /// 반환: false면 씬 진입 취소
  Future<bool> beforeSceneEnter(
    DialoguePluginContext context,
    DialogueScene scene,
  ) async {
    return true;
  }

  /// 씬 진입 후
  /// 
  /// [scene] - 진입한 씬
  Future<void> onSceneEntered(
    DialoguePluginContext context,
    DialogueScene scene,
  ) async {}

  /// 씬 종료 전
  /// 
  /// [scene] - 종료할 씬
  Future<void> beforeSceneExit(
    DialoguePluginContext context,
    DialogueScene scene,
  ) async {}

  /// 씬 종료 후
  /// 
  /// [fromSceneId] - 이전 씬 ID
  /// [toSceneId] - 다음 씬 ID
  Future<void> onSceneExited(
    DialoguePluginContext context,
    String fromSceneId,
    String toSceneId,
  ) async {}

  // ========== 노드 관련 훅 ==========

  /// 노드 표시 전
  /// 
  /// [node] - 표시할 노드
  /// 
  /// 반환: false면 노드 표시 스킵
  Future<bool> beforeNodeDisplay(
    DialoguePluginContext context,
    DialogueNode node,
  ) async {
    return true;
  }

  /// 노드 표시 후
  /// 
  /// [node] - 표시된 노드
  Future<void> onNodeDisplayed(
    DialoguePluginContext context,
    DialogueNode node,
  ) async {}

  // ========== 선택지 관련 훅 ==========

  /// 선택지 목록 표시 전
  /// 
  /// [choices] - 원본 선택지 목록
  /// 
  /// 반환: 수정된 선택지 목록 (추가/제거/순서 변경 가능)
  Future<List<DialogueChoice>> beforeChoicesPresent(
    DialoguePluginContext context,
    List<DialogueChoice> choices,
  ) async {
    return choices;
  }

  /// 선택지 선택 전
  /// 
  /// [choice] - 선택된 선택지
  /// 
  /// 반환: false면 선택 취소
  Future<bool> beforeChoiceSelected(
    DialoguePluginContext context,
    DialogueChoice choice,
  ) async {
    return true;
  }

  /// 선택지 선택 후
  /// 
  /// [choice] - 선택된 선택지
  Future<void> onChoiceSelected(
    DialoguePluginContext context,
    DialogueChoice choice,
  ) async {}

  // ========== 효과 관련 훅 ==========

  /// 효과 적용 전
  /// 
  /// [effect] - 적용할 효과
  /// 
  /// 반환: false면 효과 적용 취소
  Future<bool> beforeEffectApplied(
    DialoguePluginContext context,
    DialogueEffect effect,
  ) async {
    return true;
  }

  /// 효과 적용 후
  /// 
  /// [effect] - 적용된 효과
  Future<void> onEffectApplied(
    DialoguePluginContext context,
    DialogueEffect effect,
  ) async {}

  // ========== 상태 관련 훅 ==========

  /// 저장 전
  /// 
  /// [state] - 저장할 상태
  /// 
  /// 반환: 수정된 상태 (플러그인 데이터 추가 가능)
  Future<Map<String, dynamic>> beforeSave(
    DialoguePluginContext context,
    Map<String, dynamic> state,
  ) async {
    return state;
  }

  /// 불러오기 후
  /// 
  /// [state] - 불러온 상태
  Future<void> onLoaded(
    DialoguePluginContext context,
    Map<String, dynamic> state,
  ) async {}

  // ========== 종료 관련 훅 ==========

  /// 다이얼로그 종료 시
  Future<void> onDialogueEnded(DialoguePluginContext context) async {}

  /// 엔진 dispose 시
  Future<void> onEngineDispose(DialoguePluginContext context) async {}

  // ========== 유틸리티 ==========

  /// 플러그인 정보 문자열
  @override
  String toString() => '$name (id: $id, priority: $priority)';
}

/// 플러그인 에러
class PluginError implements Exception {
  final String pluginId;
  final String message;
  final Object? cause;

  PluginError({
    required this.pluginId,
    required this.message,
    this.cause,
  });

  @override
  String toString() {
    final buffer = StringBuffer('PluginError[$pluginId]: $message');
    if (cause != null) buffer.write(' (cause: $cause)');
    return buffer.toString();
  }
}

/// 플러그인 실행 결과
class PluginExecutionResult {
  /// 성공 여부
  final bool success;
  
  /// 에러 (실패 시)
  final Object? error;
  
  /// 실행 시간 (밀리초)
  final int executionTimeMs;
  
  /// 플러그인 ID
  final String pluginId;

  const PluginExecutionResult({
    required this.success,
    required this.pluginId,
    this.error,
    this.executionTimeMs = 0,
  });

  factory PluginExecutionResult.success(String pluginId, int timeMs) {
    return PluginExecutionResult(
      success: true,
      pluginId: pluginId,
      executionTimeMs: timeMs,
    );
  }

  factory PluginExecutionResult.failure(
    String pluginId,
    Object error, [
    int timeMs = 0,
  ]) {
    return PluginExecutionResult(
      success: false,
      pluginId: pluginId,
      error: error,
      executionTimeMs: timeMs,
    );
  }

  @override
  String toString() {
    if (success) {
      return 'PluginExecutionResult(success, $pluginId, ${executionTimeMs}ms)';
    } else {
      return 'PluginExecutionResult(failure, $pluginId, error: $error)';
    }
  }
}

/// 간단한 플러그인 베이스 (최소한의 구현)
abstract class SimpleDialoguePlugin implements DialoguePlugin {
  @override
  final String id;

  @override
  final String name;

  @override
  final int priority;

  SimpleDialoguePlugin({
    required this.id,
    required this.name,
    this.priority = 100,
  });

  @override
  bool get isEnabled => true;

  // 모든 훅은 기본 구현 (아무것도 안 함)
  @override
  Future<void> onEngineInit(DialoguePluginContext context) async {}

  @override
  Future<void> onDialogueLoaded(
    DialoguePluginContext context,
    DialogueData dialogueData,
  ) async {}

  @override
  Future<void> onDialogueStarted(
    DialoguePluginContext context,
    String sceneId,
  ) async {}

  @override
  Future<bool> beforeSceneEnter(
    DialoguePluginContext context,
    DialogueScene scene,
  ) async =>
      true;

  @override
  Future<void> onSceneEntered(
    DialoguePluginContext context,
    DialogueScene scene,
  ) async {}

  @override
  Future<void> beforeSceneExit(
    DialoguePluginContext context,
    DialogueScene scene,
  ) async {}

  @override
  Future<void> onSceneExited(
    DialoguePluginContext context,
    String fromSceneId,
    String toSceneId,
  ) async {}

  @override
  Future<bool> beforeNodeDisplay(
    DialoguePluginContext context,
    DialogueNode node,
  ) async =>
      true;

  @override
  Future<void> onNodeDisplayed(
    DialoguePluginContext context,
    DialogueNode node,
  ) async {}

  @override
  Future<List<DialogueChoice>> beforeChoicesPresent(
    DialoguePluginContext context,
    List<DialogueChoice> choices,
  ) async =>
      choices;

  @override
  Future<bool> beforeChoiceSelected(
    DialoguePluginContext context,
    DialogueChoice choice,
  ) async =>
      true;

  @override
  Future<void> onChoiceSelected(
    DialoguePluginContext context,
    DialogueChoice choice,
  ) async {}

  @override
  Future<bool> beforeEffectApplied(
    DialoguePluginContext context,
    DialogueEffect effect,
  ) async =>
      true;

  @override
  Future<void> onEffectApplied(
    DialoguePluginContext context,
    DialogueEffect effect,
  ) async {}

  @override
  Future<Map<String, dynamic>> beforeSave(
    DialoguePluginContext context,
    Map<String, dynamic> state,
  ) async =>
      state;

  @override
  Future<void> onLoaded(
    DialoguePluginContext context,
    Map<String, dynamic> state,
  ) async {}

  @override
  Future<void> onDialogueEnded(DialoguePluginContext context) async {}

  @override
  Future<void> onEngineDispose(DialoguePluginContext context) async {}
}

