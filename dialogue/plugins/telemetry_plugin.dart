/// 텔레메트리 플러그인
/// 
/// 플레이어 행동을 로깅하고 분석 데이터를 수집합니다.

import 'package:flutter/foundation.dart';
import '../core/dialogue_data.dart';
import 'dialogue_plugin.dart';

/// 텔레메트리 이벤트
class TelemetryEvent {
  final String eventType;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  TelemetryEvent({
    required this.eventType,
    required this.data,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'eventType': eventType,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() => 'TelemetryEvent($eventType at ${timestamp.toIso8601String()})';
}

/// 텔레메트리 플러그인
class TelemetryPlugin extends SimpleDialoguePlugin {
  final List<TelemetryEvent> _events = [];
  bool enableLogging = kDebugMode;

  TelemetryPlugin()
      : super(
          id: 'telemetry',
          name: 'Telemetry Plugin',
          priority: 200, // 가장 나중에 실행 (다른 플러그인 영향 안 받음)
        );

  List<TelemetryEvent> get events => List.unmodifiable(_events);

  void _logEvent(String eventType, Map<String, dynamic> data) {
    final event = TelemetryEvent(eventType: eventType, data: data);
    _events.add(event);

    if (enableLogging) {
      debugPrint('[TelemetryPlugin] $event');
    }
  }

  @override
  Future<void> onDialogueStarted(context, sceneId) async {
    _logEvent('dialogue_started', {'sceneId': sceneId});
  }

  @override
  Future<void> onSceneEntered(context, scene) async {
    _logEvent('scene_entered', {'sceneId': scene.id});
  }

  @override
  Future<void> onChoiceSelected(context, choice) async {
    _logEvent('choice_selected', {
      'choiceId': choice.id,
      'choiceText': choice.text,
      'isBranchPoint': choice.isBranchPoint,
    });
  }

  @override
  Future<void> onDialogueEnded(context) async {
    _logEvent('dialogue_ended', {});
  }

  Map<String, dynamic> getStatistics() {
    final eventCounts = <String, int>{};
    for (final event in _events) {
      eventCounts[event.eventType] = (eventCounts[event.eventType] ?? 0) + 1;
    }

    return {
      'totalEvents': _events.length,
      'eventCounts': eventCounts,
    };
  }

  void clearEvents() {
    _events.clear();
  }
}

