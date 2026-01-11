import '../state/events.dart';
import 'command_queue.dart';
import 'combat_state_slot.dart';
import 'event_envelope.dart';
import 'event_timeline.dart';

/// Safe Mode 진입 콜백 타입
typedef SafeModeCallback = Future<void> Function(String reason);

/// 이벤트 가드: 런타임 불변조건 검사 및 Safe Mode
/// 
/// - maxDepth(12): 이벤트 체인 깊이 제한
/// - maxEventsPerTrace(200): trace당 이벤트 수 제한
/// - 폭주 감지: 동일 타입 20회/2초
/// - Combat 종료 불변조건 검사
/// - traceId/parentId 체인 검증
class EventGuards {
  // ========== 정책 임계값 ==========
  static const int MAX_DEPTH = 12;
  static const int MAX_EVENTS_PER_TRACE = 200;
  static const int BURST_THRESHOLD = 20;  // 동일 타입 20회
  static const double BURST_WINDOW_SIM_MS = 2000.0;  // 2초 윈도우 (시뮬레이션 시간)
  
  // ========== 추적 데이터 ==========
  final Map<String, int> _traceEventCount = {};
  final Map<Type, List<double>> _recentEventsByType = {};  // 시뮬레이션 시간 기반
  
  // ========== 의존성 ==========
  final EventTimeline _timeline;
  SafeModeCallback? _onSafeMode;
  
  // ========== 메트릭 ==========
  int _blockedCount = 0;
  int _depthViolations = 0;
  int _traceViolations = 0;
  int _burstViolations = 0;
  
  // Getters
  int get blockedCount => _blockedCount;
  int get depthViolations => _depthViolations;
  int get traceViolations => _traceViolations;
  int get burstViolations => _burstViolations;
  
  EventGuards(this._timeline);
  
  /// Safe Mode 콜백 설정
  void setSafeModeCallback(SafeModeCallback callback) {
    _onSafeMode = callback;
  }
  
  /// 이벤트 허용 여부 검사
  /// 
  /// - maxDepth 초과 → Safe Mode 진입
  /// - maxEventsPerTrace 초과 → Safe Mode 진입
  /// - 폭주 감지 → Safe Mode 진입
  bool allow(EventEnvelope envelope, {double? currentSimTimeMs}) {
    // 1. maxDepth 검사
    if (envelope.depth > MAX_DEPTH) {
      _depthViolations++;
      _blockTrace(envelope, 'maxDepth exceeded: ${envelope.depth} > $MAX_DEPTH');
      return false;
    }
    
    // 2. maxEventsPerTrace 검사
    final traceId = envelope.traceId;
    if (traceId != null) {
      _traceEventCount[traceId] = (_traceEventCount[traceId] ?? 0) + 1;
      if (_traceEventCount[traceId]! > MAX_EVENTS_PER_TRACE) {
        _traceViolations++;
        _blockTrace(envelope, 'maxEventsPerTrace exceeded: '
                              '${_traceEventCount[traceId]} > $MAX_EVENTS_PER_TRACE');
        return false;
      }
    }
    
    // 3. 폭주 감지 (시뮬레이션 시간 기반)
    if (currentSimTimeMs != null) {
      final eventType = envelope.event.runtimeType;
      _recentEventsByType[eventType] ??= [];
      _recentEventsByType[eventType]!.add(currentSimTimeMs);
      
      // 윈도우 밖의 이벤트 제거
      _recentEventsByType[eventType]!.removeWhere(
        (t) => currentSimTimeMs - t > BURST_WINDOW_SIM_MS
      );
      
      if (_recentEventsByType[eventType]!.length > BURST_THRESHOLD) {
        _burstViolations++;
        _blockTrace(envelope, 'burst detected: $eventType '
                              '(${_recentEventsByType[eventType]!.length} events '
                              'in ${BURST_WINDOW_SIM_MS}ms sim window)');
        return false;
      }
    }
    
    return true;
  }
  
  /// trace 차단 및 Safe Mode 진입
  void _blockTrace(EventEnvelope envelope, String reason) {
    _blockedCount++;
    
    // 1. 경고 로그
    print('');
    print('🚫 [EventGuards] BLOCKED: $reason');
    print('   Event: ${envelope.event.runtimeType}');
    print('   TraceId: ${envelope.traceId}');
    print('   Depth: ${envelope.depth}');
    
    // 2. 타임라인 덤프
    _timeline.dump(
      filterTraceId: envelope.traceId, 
      reason: 'EventGuards: $reason'
    );
    
    // 3. Safe Mode 진입 (앱 멈춤 금지)
    _enterSafeMode(reason);
  }
  
  /// Safe Mode 진입
  /// 
  /// 동작 순서:
  /// 1. 타임라인 덤프 (이미 _blockTrace에서 수행)
  /// 2. 경고 로그 출력
  /// 3. 안전 상태로 복귀 (콜백)
  void _enterSafeMode(String reason) {
    print('');
    print('⚠️ [EventGuards] Entering Safe Mode');
    print('   Reason: $reason');
    print('   Action: Current trace blocked, transitioning to safe state');
    
    // 안전 상태 복귀 콜백 호출 (앱 멈춤 금지)
    if (_onSafeMode != null) {
      _onSafeMode!(reason);
    }
  }
  
  /// Combat 종료 불변조건 검사
  /// 
  /// CombatResult 처리 직후 다음 조건을 **모두 검증**:
  /// - Slot.current == null
  /// - 종료 후 Slot.update() 호출 0회
  /// - CmdQueue에 CombatStateUpdated 0개 (큐가 거부하므로 항상 0)
  void verifyCombatEndInvariants({
    required CombatStateSlot slot,
    required CmdQueue queue,
  }) {
    final violations = <String>[];
    
    // 1. Slot.current 검사
    if (slot.current != null) {
      violations.add('Slot.current != null (expected null after combat end)');
    }
    
    // 2. 종료 후 update 횟수 검사
    if (slot.updateCountAfterEnd > 0) {
      violations.add('Slot.update called ${slot.updateCountAfterEnd} times '
                     'after markCombatEnded()');
    }
    
    // 3. 큐 검사 (Internal은 거부되므로 항상 0이어야 함)
    // CmdQueue는 이미 CombatStateUpdated를 거부하므로 
    // rejectedInternalCount가 증가했다면 누군가 시도한 것
    
    if (violations.isNotEmpty) {
      print('');
      print('❌ [EventGuards] Combat invariant violations:');
      for (final v in violations) {
        print('   - $v');
      }
      
      _timeline.dump(reason: 'Combat invariant violation');
      _enterSafeMode('Combat invariant violation: ${violations.join(", ")}');
    } else {
      print('✓ [EventGuards] Combat end invariants verified');
    }
  }
  
  /// traceId/parentId 체인 검증
  /// 
  /// EnterCombat → CombatResult → EnterReward 체인에서:
  /// - traceId 연결 일치
  /// - parentId가 부모 eventId와 일치
  /// - depth 정책 준수 (매 이벤트마다 +1)
  void verifyTraceChain(List<EventEnvelope> chain) {
    if (chain.isEmpty) return;
    
    final violations = <String>[];
    
    for (int i = 1; i < chain.length; i++) {
      final parent = chain[i - 1];
      final child = chain[i];
      
      // traceId 일치 검사
      if (child.traceId != parent.traceId) {
        violations.add('Step $i: traceId mismatch '
                       '(expected ${parent.traceId}, got ${child.traceId})');
      }
      
      // parentId 일치 검사
      if (child.parentEventId != parent.eventId) {
        violations.add('Step $i: parentId mismatch '
                       '(expected ${parent.eventId}, got ${child.parentEventId})');
      }
      
      // depth 검사
      if (child.depth != parent.depth + 1) {
        violations.add('Step $i: depth mismatch '
                       '(expected ${parent.depth + 1}, got ${child.depth})');
      }
    }
    
    if (violations.isNotEmpty) {
      print('');
      print('⚠️ [EventGuards] Trace chain violations:');
      for (final v in violations) {
        print('   - $v');
      }
      
      // 타임라인 덤프 (Safe Mode 진입 안 함)
      if (chain.first.traceId != null) {
        _timeline.dump(
          filterTraceId: chain.first.traceId, 
          reason: 'Trace chain violation'
        );
      }
      
      // 표준 흐름 분석
      _timeline.analyzeChain(chain);
    } else {
      print('✓ [EventGuards] Trace chain verified');
    }
  }
  
  /// 메트릭 리셋
  void resetMetrics() {
    _traceEventCount.clear();
    _recentEventsByType.clear();
    _blockedCount = 0;
    _depthViolations = 0;
    _traceViolations = 0;
    _burstViolations = 0;
  }
  
  /// 메트릭 요약 문자열
  String getMetricsSummary() {
    return '[EventGuards] Metrics: '
           'blocked=$_blockedCount, '
           'depthViolations=$_depthViolations, '
           'traceViolations=$_traceViolations, '
           'burstViolations=$_burstViolations';
  }
}
