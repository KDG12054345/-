/// 플러그인 매니저
/// 
/// 플러그인들을 등록하고 관리하며, 적절한 시점에 훅을 실행합니다.

import 'package:flutter/foundation.dart';
import 'dialogue_plugin.dart';

/// 플러그인 매니저
class DialoguePluginManager {
  /// 등록된 플러그인들
  final List<DialoguePlugin> _plugins = [];

  /// 플러그인 실행 로그 (디버그용)
  final List<PluginExecutionResult> _executionLog = [];

  /// 에러 로그
  final List<PluginError> _errorLog = [];

  /// 로깅 활성화 여부
  bool enableLogging = kDebugMode;

  /// 에러 격리 모드 (true면 한 플러그인 에러가 다른 플러그인 실행 안 막음)
  bool isolateErrors = true;

  /// 성능 측정 활성화
  bool enablePerformanceTracking = kDebugMode;

  DialoguePluginManager();

  // ========== 플러그인 관리 ==========

  /// 플러그인 등록
  void registerPlugin(DialoguePlugin plugin) {
    // 중복 체크
    if (_plugins.any((p) => p.id == plugin.id)) {
      debugPrint('[PluginManager] Plugin already registered: ${plugin.id}');
      return;
    }

    _plugins.add(plugin);
    _sortPlugins();

    if (enableLogging) {
      debugPrint('[PluginManager] Registered plugin: $plugin');
    }
  }

  /// 여러 플러그인 한번에 등록
  void registerPlugins(List<DialoguePlugin> plugins) {
    for (final plugin in plugins) {
      registerPlugin(plugin);
    }
  }

  /// 플러그인 제거
  bool unregisterPlugin(String pluginId) {
    final index = _plugins.indexWhere((p) => p.id == pluginId);
    if (index >= 0) {
      _plugins.removeAt(index);
      if (enableLogging) {
        debugPrint('[PluginManager] Unregistered plugin: $pluginId');
      }
      return true;
    }
    return false;
  }

  /// 모든 플러그인 제거
  void clearPlugins() {
    final count = _plugins.length;
    _plugins.clear();
    if (enableLogging) {
      debugPrint('[PluginManager] Cleared all plugins ($count)');
    }
  }

  /// 플러그인 조회
  DialoguePlugin? getPlugin(String pluginId) {
    try {
      return _plugins.firstWhere((p) => p.id == pluginId);
    } catch (_) {
      return null;
    }
  }

  /// 모든 플러그인 조회
  List<DialoguePlugin> getAllPlugins() => List.unmodifiable(_plugins);

  /// 활성화된 플러그인만 조회
  List<DialoguePlugin> getEnabledPlugins() {
    return _plugins.where((p) => p.isEnabled).toList();
  }

  // ========== 훅 실행 ==========

  /// 훅 실행 (단순, 반환값 없음)
  Future<List<PluginExecutionResult>> executeHook(
    String hookName,
    Future<void> Function(DialoguePlugin) hook,
  ) async {
    final results = <PluginExecutionResult>[];
    final enabledPlugins = getEnabledPlugins();

    for (final plugin in enabledPlugins) {
      final result = await _executePluginHook(
        plugin,
        hookName,
        () async {
          await hook(plugin);
          return null; // void
        },
      );
      results.add(result);

      // 에러가 발생하고 격리 모드가 아니면 중단
      if (!result.success && !isolateErrors) {
        break;
      }
    }

    return results;
  }

  /// 훅 실행 (불린 반환, 하나라도 false면 false)
  Future<bool> executeHookWithBoolResult(
    String hookName,
    Future<bool> Function(DialoguePlugin) hook,
  ) async {
    final enabledPlugins = getEnabledPlugins();

    for (final plugin in enabledPlugins) {
      final result = await _executePluginHook<bool>(
        plugin,
        hookName,
        () => hook(plugin),
      );

      if (!result.success) {
        if (!isolateErrors) {
          return false;
        }
        continue;
      }

      // 플러그인이 false 반환하면 즉시 중단
      if (result.success && !(result.error as bool? ?? true)) {
        return false;
      }
    }

    return true;
  }

  /// 훅 실행 (리스트 변환, 각 플러그인이 리스트 수정 가능)
  Future<List<T>> executeHookWithListTransform<T>(
    String hookName,
    List<T> initialList,
    Future<List<T>> Function(DialoguePlugin, List<T>) hook,
  ) async {
    var currentList = initialList;
    final enabledPlugins = getEnabledPlugins();

    for (final plugin in enabledPlugins) {
      final result = await _executePluginHook<List<T>>(
        plugin,
        hookName,
        () => hook(plugin, currentList),
      );

      if (!result.success) {
        if (!isolateErrors) {
          break;
        }
        continue;
      }

      // 결과가 있으면 업데이트
      if (result.success && result.error is List<T>) {
        currentList = result.error as List<T>;
      }
    }

    return currentList;
  }

  /// 훅 실행 (맵 변환, 각 플러그인이 맵 수정 가능)
  Future<Map<String, dynamic>> executeHookWithMapTransform(
    String hookName,
    Map<String, dynamic> initialMap,
    Future<Map<String, dynamic>> Function(DialoguePlugin, Map<String, dynamic>) hook,
  ) async {
    var currentMap = initialMap;
    final enabledPlugins = getEnabledPlugins();

    for (final plugin in enabledPlugins) {
      final result = await _executePluginHook<Map<String, dynamic>>(
        plugin,
        hookName,
        () => hook(plugin, currentMap),
      );

      if (!result.success) {
        if (!isolateErrors) {
          break;
        }
        continue;
      }

      // 결과가 있으면 업데이트
      if (result.success && result.error is Map<String, dynamic>) {
        currentMap = result.error as Map<String, dynamic>;
      }
    }

    return currentMap;
  }

  // ========== 내부 메서드 ==========

  /// 개별 플러그인 훅 실행 (에러 처리 및 성능 측정)
  Future<PluginExecutionResult> _executePluginHook<T>(
    DialoguePlugin plugin,
    String hookName,
    Future<T?> Function() hook,
  ) async {
    final startTime = DateTime.now();

    try {
      final result = await hook();

      final executionTime = DateTime.now().difference(startTime).inMilliseconds;

      final pluginResult = PluginExecutionResult(
        success: true,
        pluginId: plugin.id,
        executionTimeMs: executionTime,
        error: result, // 성공 시 결과를 error 필드에 저장 (리팩토링 필요)
      );

      if (enableLogging && enablePerformanceTracking && executionTime > 10) {
        debugPrint('[PluginManager] ${plugin.id}.$hookName took ${executionTime}ms');
      }

      if (enableLogging) {
        _executionLog.add(pluginResult);
      }

      return pluginResult;
    } catch (e, stackTrace) {
      final executionTime = DateTime.now().difference(startTime).inMilliseconds;

      final error = PluginError(
        pluginId: plugin.id,
        message: 'Error in hook $hookName',
        cause: e,
      );

      _errorLog.add(error);

      debugPrint('[PluginManager] Plugin error: $error');
      debugPrint('[PluginManager] Stack trace: $stackTrace');

      final pluginResult = PluginExecutionResult.failure(
        plugin.id,
        error,
        executionTime,
      );

      if (enableLogging) {
        _executionLog.add(pluginResult);
      }

      return pluginResult;
    }
  }

  /// 우선순위에 따라 플러그인 정렬
  void _sortPlugins() {
    _plugins.sort((a, b) => a.priority.compareTo(b.priority));
  }

  // ========== 통계 및 디버깅 ==========

  /// 실행 로그 조회
  List<PluginExecutionResult> getExecutionLog() {
    return List.unmodifiable(_executionLog);
  }

  /// 에러 로그 조회
  List<PluginError> getErrorLog() {
    return List.unmodifiable(_errorLog);
  }

  /// 로그 클리어
  void clearLogs() {
    _executionLog.clear();
    _errorLog.clear();
  }

  /// 통계 조회
  Map<String, dynamic> getStatistics() {
    final stats = <String, dynamic>{
      'totalPlugins': _plugins.length,
      'enabledPlugins': getEnabledPlugins().length,
      'totalExecutions': _executionLog.length,
      'totalErrors': _errorLog.length,
    };

    // 플러그인별 통계
    final pluginStats = <String, Map<String, dynamic>>{};
    for (final plugin in _plugins) {
      final executions = _executionLog.where((r) => r.pluginId == plugin.id);
      final errors = _errorLog.where((e) => e.pluginId == plugin.id);
      final totalTime = executions.fold<int>(
        0,
        (sum, r) => sum + r.executionTimeMs,
      );

      pluginStats[plugin.id] = {
        'name': plugin.name,
        'priority': plugin.priority,
        'enabled': plugin.isEnabled,
        'executions': executions.length,
        'errors': errors.length,
        'totalTimeMs': totalTime,
        'avgTimeMs': executions.isNotEmpty ? totalTime / executions.length : 0,
      };
    }

    stats['plugins'] = pluginStats;

    return stats;
  }

  /// 디버그 정보
  String getDebugInfo() {
    final buffer = StringBuffer();
    buffer.writeln('DialoguePluginManager:');
    buffer.writeln('  Total Plugins: ${_plugins.length}');
    buffer.writeln('  Enabled Plugins: ${getEnabledPlugins().length}');
    buffer.writeln('  Error Isolation: $isolateErrors');
    buffer.writeln('  Performance Tracking: $enablePerformanceTracking');
    buffer.writeln();

    buffer.writeln('Registered Plugins (priority order):');
    for (final plugin in _plugins) {
      buffer.writeln('  - $plugin (${plugin.isEnabled ? "enabled" : "disabled"})');
    }

    if (_errorLog.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Recent Errors:');
      for (final error in _errorLog.take(5)) {
        buffer.writeln('  - $error');
      }
    }

    return buffer.toString();
  }

  /// 성능 리포트
  String getPerformanceReport() {
    final stats = getStatistics();
    final pluginStats = stats['plugins'] as Map<String, Map<String, dynamic>>;

    final buffer = StringBuffer();
    buffer.writeln('Plugin Performance Report:');
    buffer.writeln('  Total Executions: ${stats['totalExecutions']}');
    buffer.writeln('  Total Errors: ${stats['totalErrors']}');
    buffer.writeln();

    // 실행 시간순으로 정렬
    final sorted = pluginStats.entries.toList()
      ..sort((a, b) => (b.value['totalTimeMs'] as int).compareTo(a.value['totalTimeMs'] as int));

    buffer.writeln('Plugins by Total Time:');
    for (final entry in sorted) {
      final name = entry.value['name'];
      final totalMs = entry.value['totalTimeMs'];
      final avgMs = (entry.value['avgTimeMs'] as num).toStringAsFixed(2);
      final executions = entry.value['executions'];
      buffer.writeln('  - $name: ${totalMs}ms total, ${avgMs}ms avg ($executions executions)');
    }

    return buffer.toString();
  }
}

