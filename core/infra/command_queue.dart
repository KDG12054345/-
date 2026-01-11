import 'dart:async';
import '../state/events.dart';

typedef EventHandler = Future<void> Function(Object);

/// 이벤트 큐: 우선순위 기반 직렬 처리
/// 
/// - Internal 이벤트(CombatStateUpdated): 큐 삽입 **금지** (슬롯만 사용)
/// - 전환/종료 이벤트(CombatResult, EnterReward): 큐 맨 앞 삽입 (최우선)
/// - 진입/일반 이벤트: 큐 맨 뒤 추가
class CmdQueue {
  final List<Object> _q = <Object>[];  // 외부 직접 접근 금지
  bool _busy = false;
  final EventHandler _handle;
  
  // ========== 메트릭 ==========
  int _highWatermark = 0;
  int _rejectedInternalCount = 0;
  int _priorityInsertCount = 0;
  
  // Getters for metrics
  int get length => _q.length;
  int get highWatermark => _highWatermark;
  int get rejectedInternalCount => _rejectedInternalCount;
  int get priorityInsertCount => _priorityInsertCount;
  
  CmdQueue(this._handle);
  
  /// 이벤트 삽입 (우선순위 API)
  /// 
  /// - Internal 이벤트는 **거부** (REJECTED 로그)
  /// - 전환/종료 이벤트는 큐 맨 앞에 삽입
  /// - 일반 이벤트는 큐 맨 뒤에 추가
  Future<void> enqueue(Object e) async {
    // 1. Internal 이벤트는 큐에 넣지 않음 (Last-Value 슬롯 사용)
    if (e is GEvent && e.tier == EventTier.internal) {
      _rejectedInternalCount++;
      print('[CmdQueue] REJECTED: Internal event cannot be queued '
            '(${e.runtimeType})');
      return;
    }
    
    // 2. 우선순위에 따라 삽입 위치 결정
    if (_isHighPriority(e)) {
      _q.insert(0, e);  // 전환/종료 이벤트: 맨 앞
      _priorityInsertCount++;
    } else {
      _q.add(e);        // 일반 이벤트: 맨 뒤
    }
    
    // 3. High watermark 업데이트
    if (_q.length > _highWatermark) {
      _highWatermark = _q.length;
    }
    
    // 4. 처리 루프
    if (_busy) return;
    _busy = true;
    try {
      while (_q.isNotEmpty) { 
        final x = _q.removeAt(0); 
        await _handle(x); 
      }
    } finally {
      _busy = false;
    }
  }
  
  /// 고우선순위 이벤트 판별
  /// 
  /// - CombatResult, EnterReward: 전환/종료 이벤트 (최우선)
  bool _isHighPriority(Object e) {
    return e is CombatResult || e is EnterReward;
  }
  
  /// 메트릭 리셋
  void resetMetrics() {
    _highWatermark = 0;
    _rejectedInternalCount = 0;
    _priorityInsertCount = 0;
  }
  
  /// 메트릭 요약 문자열
  String getMetricsSummary() {
    return '[CmdQueue] Metrics: '
           'currentLength=${_q.length}, '
           'highWatermark=$_highWatermark, '
           'rejectedInternal=$_rejectedInternalCount, '
           'priorityInserts=$_priorityInsertCount';
  }
}
