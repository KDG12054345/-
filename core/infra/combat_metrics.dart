import '../state/events.dart';
import 'event_timeline.dart';

/// Combat 메트릭 수집 및 QA 리그레션 게이트
/// 
/// - ticksProcessed: 처리된 틱 수
/// - uiUpdatesSent: UI 업데이트 횟수
/// - queueLengthHighWatermark: 큐 최대 길이
/// - dispatchCountByTier: tier별 dispatch 횟수
/// - slowTickCount: 느린 틱 횟수 (>150ms)
class CombatMetrics {
  // ========== QA 모드 설정 ==========
  /// QA 모드 활성화 (개발/테스트 중에만 true)
  static bool qaMode = false;
  
  // ========== QA 임계값 ==========
  static const int UI_UPDATES_MIN = 200;
  static const int UI_UPDATES_MAX = 280;
  static const int QUEUE_WATERMARK_MAX = 10;
  static const int SLOW_TICK_MAX = 5;
  static const int SLOW_TICK_THRESHOLD_MS = 150;
  
  // ========== 메트릭 ==========
  int ticksProcessed = 0;
  int uiUpdatesSent = 0;
  int queueLengthHighWatermark = 0;
  Map<EventTier, int> dispatchCountByTier = {
    EventTier.user: 0,
    EventTier.system: 0,
    EventTier.internal: 0,
  };
  int slowTickCount = 0;
  
  // 5초 요약용
  DateTime? _lastSummaryTime;
  double? _lastSummarySimTime;
  static const Duration SUMMARY_INTERVAL = Duration(seconds: 5);
  
  // 전투 시간 추적
  DateTime? _combatStartTime;
  double _combatStartSimTime = 0.0;
  
  /// 틱 처리 기록
  void recordTick({required Duration elapsed}) {
    ticksProcessed++;
    if (elapsed.inMilliseconds > SLOW_TICK_THRESHOLD_MS) {
      slowTickCount++;
    }
  }
  
  /// UI 업데이트 기록
  void recordUiUpdate() {
    uiUpdatesSent++;
  }
  
  /// 이벤트 dispatch 기록
  void recordDispatch(EventTier tier) {
    dispatchCountByTier[tier] = (dispatchCountByTier[tier] ?? 0) + 1;
  }
  
  /// 큐 High Watermark 업데이트
  void updateQueueHighWatermark(int currentLength) {
    if (currentLength > queueLengthHighWatermark) {
      queueLengthHighWatermark = currentLength;
    }
  }
  
  /// 전투 시작 시점 기록
  void startCombat({required double simTimeMs}) {
    _combatStartTime = DateTime.now();
    _combatStartSimTime = simTimeMs;
    reset();
  }
  
  /// 5초 주기 요약 출력 (디버그 모드)
  /// 
  /// - 시뮬레이션 시간 기준
  void maybePrintSummary({required double currentSimTimeMs}) {
    final now = DateTime.now();
    
    // 시뮬레이션 시간 기반 5초 체크
    final simElapsed = currentSimTimeMs - (_lastSummarySimTime ?? _combatStartSimTime);
    
    if (_lastSummaryTime == null || 
        now.difference(_lastSummaryTime!) >= SUMMARY_INTERVAL ||
        simElapsed >= 5000.0) {
      
      _lastSummaryTime = now;
      _lastSummarySimTime = currentSimTimeMs;
      
      print('');
      print('[CombatMetrics] 5s summary:');
      print('  ticksProcessed: $ticksProcessed');
      print('  uiUpdatesSent: $uiUpdatesSent');
      print('  queueLengthHighWatermark: $queueLengthHighWatermark');
      print('  dispatchCountByTier: $dispatchCountByTier');
      print('  slowTickCount: $slowTickCount (>${SLOW_TICK_THRESHOLD_MS}ms)');
      print('  simTime: ${currentSimTimeMs.toStringAsFixed(1)}ms');
      print('');
    }
  }
  
  /// QA 리그레션 게이트 검사
  /// 
  /// **테스트 조건:** 전투 60초 + 배속 x5
  /// 
  /// | 메트릭 | 허용 범위 |
  /// |--------|----------|
  /// | uiUpdatesSent | 200~280 |
  /// | queueLengthHighWatermark | ≤10 |
  /// | slowTickCount | ≤5 |
  /// 
  /// **QA 실패 처리:**
  /// - 타임라인 덤프
  /// - 메트릭 덤프
  /// - assert 실패 (개발 중 조기 발견)
  void checkRegressionGates(EventTimeline timeline) {
    if (!qaMode) return;
    
    final failures = <String>[];
    
    // 1. UI 업데이트 횟수 검사
    if (uiUpdatesSent < UI_UPDATES_MIN || uiUpdatesSent > UI_UPDATES_MAX) {
      failures.add('uiUpdatesSent=$uiUpdatesSent '
                   '(expected $UI_UPDATES_MIN~$UI_UPDATES_MAX)');
    }
    
    // 2. 큐 High Watermark 검사
    if (queueLengthHighWatermark > QUEUE_WATERMARK_MAX) {
      failures.add('queueLengthHighWatermark=$queueLengthHighWatermark '
                   '(max $QUEUE_WATERMARK_MAX)');
    }
    
    // 3. 느린 틱 횟수 검사
    if (slowTickCount > SLOW_TICK_MAX) {
      failures.add('slowTickCount=$slowTickCount (max $SLOW_TICK_MAX)');
    }
    
    if (failures.isNotEmpty) {
      print('');
      print('❌ [QA FAILURE] Regression gates violated:');
      for (final f in failures) {
        print('  - $f');
      }
      
      // 타임라인 덤프
      timeline.dump(reason: 'QA regression gate failure');
      
      // 메트릭 덤프
      print('[Metrics Dump] $this');
      
      // QA 실패 표시 (앱 중단, Safe Mode 아님)
      // 개발 중 조기 발견 목적
      assert(false, 'QA regression gate failure: $failures');
    } else {
      print('✓ [QA] Regression gates passed');
    }
  }
  
  /// 메트릭 리셋
  void reset() {
    ticksProcessed = 0;
    uiUpdatesSent = 0;
    queueLengthHighWatermark = 0;
    dispatchCountByTier = {
      EventTier.user: 0,
      EventTier.system: 0,
      EventTier.internal: 0,
    };
    slowTickCount = 0;
    _lastSummaryTime = null;
    _lastSummarySimTime = null;
  }
  
  @override
  String toString() {
    return 'CombatMetrics('
           'ticks: $ticksProcessed, '
           'uiUpdates: $uiUpdatesSent, '
           'queueWatermark: $queueLengthHighWatermark, '
           'slowTicks: $slowTickCount, '
           'dispatchByTier: $dispatchCountByTier)';
  }
}
