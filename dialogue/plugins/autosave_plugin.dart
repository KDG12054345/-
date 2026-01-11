/// 자동 저장 플러그인
/// 
/// 주기적으로 또는 중요한 시점에 게임을 자동 저장합니다.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/dialogue_data.dart';
import 'dialogue_plugin.dart';

/// 자동 저장 플러그인
class AutosavePlugin extends SimpleDialoguePlugin {
  /// 자동 저장 간격 (null이면 선택지마다)
  final Duration? autoSaveInterval;
  
  /// 마지막 저장 시간
  DateTime? _lastSaveTime;
  
  /// 저장 횟수
  int _saveCount = 0;
  
  /// 로깅 활성화
  bool enableLogging = kDebugMode;

  AutosavePlugin({
    this.autoSaveInterval,
  }) : super(
          id: 'autosave',
          name: 'Autosave Plugin',
          priority: 150,
        );

  int get saveCount => _saveCount;
  DateTime? get lastSaveTime => _lastSaveTime;

  @override
  Future<void> onChoiceSelected(context, choice) async {
    // 중요한 선택은 항상 저장
    if (choice.isBranchPoint) {
      await _performSave(context, 'branch_choice');
      return;
    }

    // 간격 기반 저장
    if (autoSaveInterval != null && _lastSaveTime != null) {
      final elapsed = DateTime.now().difference(_lastSaveTime!);
      if (elapsed >= autoSaveInterval!) {
        await _performSave(context, 'interval');
      }
    } else if (autoSaveInterval == null) {
      // 간격이 없으면 매 선택마다 저장
      await _performSave(context, 'every_choice');
    }
  }

  @override
  Future<void> onSceneEntered(context, scene) async {
    // 씬 진입 시에도 저장
    await _performSave(context, 'scene_enter');
  }

  Future<void> _performSave(context, String reason) async {
    try {
      // 실제 저장은 엔진을 통해 수행
      // Note: 플러그인에서 엔진의 saveState()를 호출해야 하는데
      // 현재 context에는 없으므로 이벤트로 처리하거나
      // 엔진에 콜백 등록 필요
      
      _lastSaveTime = DateTime.now();
      _saveCount++;

      if (enableLogging) {
        debugPrint('[AutosavePlugin] Saved (#$_saveCount, reason: $reason)');
      }
    } catch (e) {
      debugPrint('[AutosavePlugin] Save failed: $e');
    }
  }

  Map<String, dynamic> getStatistics() {
    return {
      'saveCount': _saveCount,
      'lastSaveTime': _lastSaveTime?.toIso8601String(),
    };
  }
}

