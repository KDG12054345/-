import '../state/events.dart';
import 'event_envelope.dart';

/// 이벤트 타임라인: 최근 이벤트 순환 버퍼
/// 
/// - 최근 100개 이벤트 유지
/// - Internal 이벤트는 기록 **금지** (요약만)
/// - traceId로 그룹 조회
/// - Guards 차단/불변조건 위반 시 자동 덤프
class EventTimeline {
  final List<EventEnvelope> _buffer = [];
  static const int MAX_SIZE = 100;
  
  // Internal 이벤트 요약용 카운터
  int _internalEventCount = 0;
  int _internalEventCountSinceLastSummary = 0;
  DateTime? _lastSummaryTime;
  static const Duration SUMMARY_INTERVAL = Duration(seconds: 5);
  
  // Getters
  int get length => _buffer.length;
  int get internalEventCount => _internalEventCount;
  List<EventEnvelope> get buffer => List.unmodifiable(_buffer);
  
  /// 이벤트 기록
  /// 
  /// - Internal 이벤트는 타임라인 기록 **금지** (요약 카운터만 증가)
  void record(EventEnvelope envelope) {
    // Internal 이벤트는 타임라인에 기록하지 않음
    if (envelope.event.tier == EventTier.internal) {
      _internalEventCount++;
      _internalEventCountSinceLastSummary++;
      return;
    }
    
    // 버퍼가 가득 차면 가장 오래된 것 제거
    if (_buffer.length >= MAX_SIZE) {
      _buffer.removeAt(0);
    }
    _buffer.add(envelope);
  }
  
  /// traceId로 이벤트 조회
  List<EventEnvelope> getByTraceId(String traceId) {
    return _buffer.where((e) => e.traceId == traceId).toList();
  }
  
  /// 정상 Phase 타임라인 분석 (이탈 지점 표시)
  /// 
  /// 표준 흐름: EnterCombat → CombatResult → EnterReward
  void analyzeChain(List<EventEnvelope> chain) {
    const expectedFlow = ['EnterCombat', 'CombatResult', 'EnterReward'];
    
    print('=== Chain Analysis ===');
    for (int i = 0; i < chain.length; i++) {
      final actual = chain[i].event.runtimeType.toString();
      final expected = i < expectedFlow.length ? expectedFlow[i] : 'END';
      
      if (i < expectedFlow.length && actual != expected) {
        print('⚠️ DEVIATION at step $i: expected $expected, got $actual');
      } else {
        print('✓ Step $i: $actual');
      }
    }
    print('=== End Analysis ===');
  }
  
  /// 타임라인 덤프 (Guards 차단/불변조건 위반/phase 전환 실패 시)
  /// 
  /// - filterTraceId: 특정 traceId만 필터링
  /// - reason: 덤프 사유
  void dump({String? filterTraceId, String? reason}) {
    print('');
    print('╔════════════════════════════════════════════════════════════');
    print('║ EventTimeline Dump');
    print('║ Reason: ${reason ?? "manual dump"}');
    print('║ Total events in buffer: ${_buffer.length}');
    print('║ Internal events skipped: $_internalEventCount');
    if (filterTraceId != null) {
      print('║ Filter: traceId=$filterTraceId');
    }
    print('╠════════════════════════════════════════════════════════════');
    
    final target = filterTraceId != null 
        ? getByTraceId(filterTraceId) 
        : _buffer;
    
    if (target.isEmpty) {
      print('║ (no events)');
    } else {
      for (int i = 0; i < target.length; i++) {
        final e = target[i];
        print('║ [$i] ${e.toLogString()}');
        print('║     parent: ${e.parentEventId ?? "root"}');
        print('║     time: ${e.timestamp.toIso8601String()}');
      }
    }
    
    print('╚════════════════════════════════════════════════════════════');
    print('');
  }
  
  /// Internal 이벤트 요약 로그 (5초마다)
  /// 
  /// - 개별 틱 로그 금지
  /// - 5초마다 1회 요약만 허용
  void maybePrintInternalSummary() {
    final now = DateTime.now();
    if (_lastSummaryTime == null || 
        now.difference(_lastSummaryTime!) >= SUMMARY_INTERVAL) {
      
      if (_internalEventCountSinceLastSummary > 0) {
        print('[EventTimeline] Internal events summary: '
              '$_internalEventCountSinceLastSummary events in last 5s '
              '(total: $_internalEventCount)');
      }
      
      _lastSummaryTime = now;
      _internalEventCountSinceLastSummary = 0;
    }
  }
  
  /// 버퍼 초기화
  void clear() {
    _buffer.clear();
    _internalEventCount = 0;
    _internalEventCountSinceLastSummary = 0;
    _lastSummaryTime = null;
  }
  
  /// 메트릭 요약 문자열
  String getMetricsSummary() {
    return '[EventTimeline] Metrics: '
           'bufferSize=${_buffer.length}/$MAX_SIZE, '
           'internalSkipped=$_internalEventCount';
  }
}
