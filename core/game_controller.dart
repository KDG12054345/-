import 'package:flutter/foundation.dart';
import 'state/game_state.dart';
import 'state/events.dart';
import 'state/reducer.dart';
import 'state/app_phase.dart';
import 'infra/phase_gate.dart';
import 'infra/command_queue.dart';
import 'infra/combat_state_slot.dart';
import 'infra/event_envelope.dart';
import 'infra/event_timeline.dart';
import 'infra/event_guards.dart';
import 'infra/combat_metrics.dart';
import '../modules/combat/combat_module.dart';
import '../modules/encounter/encounter_module.dart';

// ⭐⭐⭐⭐⭐ 각 모듈의 인터페이스 정의
abstract interface class GameModule {
  Set<AppPhase> get supportedPhases;
  Set<Type> get handledEvents;
  Future<List<GEvent>> handle(GEvent event, GameVM vm);
}

/// 중앙 허브: 이벤트 직렬 처리 → reduce → (필요 시) 모듈 컨트롤러 사이드이펙트
/// 
/// Combat Tick 최적화 및 이벤트 시스템 개선:
/// - CombatStateSlot: UI 직접 구독용 Last-Value 슬롯
/// - EventEnvelope: 이벤트 메타데이터 래핑
/// - EventTimeline: 최근 이벤트 순환 버퍼
/// - EventGuards: 런타임 불변조건 검사
/// - CombatMetrics: 전투 성능 메트릭
class GameController extends ChangeNotifier {
  GameVM _vm = const GameVM();
  GameVM get vm => _vm;

  late final CmdQueue _queue;
  final List<GameModule> _modules;
  
  // ========== 인프라 컴포넌트 ==========
  
  /// UI 직접 구독용 전투 상태 슬롯
  final CombatStateSlot combatStateSlot = CombatStateSlot();
  
  /// 이벤트 타임라인 (최근 100개, Internal 제외)
  final EventTimeline eventTimeline = EventTimeline();
  
  /// 이벤트 가드 (런타임 불변조건 검사)
  late final EventGuards eventGuards;
  
  /// 전투 메트릭 (5초 요약, QA 리그레션 게이트)
  final CombatMetrics combatMetrics = CombatMetrics();
  
  /// 큐 접근자 (Guards에서 사용)
  CmdQueue get queue => _queue;
  
  // ========== 현재 Envelope 문맥 ==========
  EventEnvelope? _currentEnvelope;

  // ⭐⭐⭐⭐⭐ Dependency Injection으로 모든 모듈 받기
  GameController({required List<GameModule> modules}) 
    : _modules = modules {
    _queue = CmdQueue(_handle);
    
    // EventGuards 초기화 (Timeline 주입)
    eventGuards = EventGuards(eventTimeline);
    
    // Safe Mode 콜백 설정
    eventGuards.setSafeModeCallback(_handleSafeMode);
    
    // 각 모듈에 GameController 참조 주입
    for (final module in _modules) {
      if (module is CombatModule) {
        module.setController(this);
        print('[GameController] ✅ CombatModule에 Controller 참조 설정 완료');
      }
      if (module is EncounterModule) {
        module.setController(this);
        print('[GameController] ✅ EncounterModule에 Controller 참조 설정 완료');
      }
    }
    
    print('[GameController] ℹ️ Controller created, waiting for explicit StartGame');
  }

  /// 이벤트 dispatch (기본)
  Future<void> dispatch(GEvent e) => _queue.enqueue(e);
  
  /// 문맥 포함 dispatch (CombatModule 등에서 사용)
  /// 
  /// 부모 문맥(traceId/parentId/depth)을 상속받아 자식 이벤트로 래핑
  Future<void> dispatchWithContext(
    GEvent e, {
    String? parentTraceId,
    String? parentEventId,
    int parentDepth = 0,
  }) async {
    // Envelope 생성 (부모 문맥 적용)
    final envelope = EventEnvelope.withContext(
      event: e,
      origin: 'CombatModule',  // TODO: 호출자 식별
      parentTraceId: parentTraceId,
      parentEventId: parentEventId,
      parentDepth: parentDepth,
    );
    
    // 로그 출력 (Internal 제외)
    if (!e.isInternalEvent) {
      print('[Event] ${envelope.toLogString()}');
    }
    
    // 타임라인 기록
    eventTimeline.record(envelope);
    
    // 메트릭 기록
    combatMetrics.recordDispatch(e.tier);
    combatMetrics.updateQueueHighWatermark(_queue.length);
    
    // 큐에 삽입
    await _queue.enqueue(e);
  }

  Future<void> _handle(Object e) async {
    if (e is! GEvent) return;
    
    // ========== Envelope 생성 ==========
    EventEnvelope envelope;
    
    if (e.isUserEvent) {
      // UserEvent: 새 traceId 생성
      envelope = EventEnvelope.root(event: e, origin: 'GameController');
    } else if (_currentEnvelope != null) {
      // 파생 이벤트: 부모 문맥 상속
      envelope = _currentEnvelope!.child(event: e, origin: 'GameController');
    } else {
      // 독립 이벤트: 루트로 생성 (traceId 없음)
      envelope = EventEnvelope.root(event: e, origin: 'GameController');
    }
    
    // ========== Guards 검사 ==========
    // 시뮬레이션 시간은 전투 중에만 의미 있음
    double? simTimeMs;
    for (final module in _modules) {
      if (module is CombatModule && vm.phase == AppPhase.inGame_combat) {
        // CombatModule에서 시뮬레이션 시간 가져오기는 어려우므로
        // 폭주 감지는 벽시계 시간 기준으로 (BURST_WINDOW_MS는 sim 기준이지만)
        break;
      }
    }
    
    if (!eventGuards.allow(envelope, currentSimTimeMs: simTimeMs)) {
      print('[GameController] Event blocked by Guards: ${e.runtimeType}');
      return;
    }
    
    // ========== 로그 출력 (Internal 제외) ==========
    if (!e.isInternalEvent) {
      print('[Event] ${envelope.toLogString()}');
    }
    
    // ========== 타임라인 기록 ==========
    eventTimeline.record(envelope);
    
    // ========== 메트릭 기록 ==========
    combatMetrics.recordDispatch(e.tier);
    combatMetrics.updateQueueHighWatermark(_queue.length);
    
    // Internal 이벤트 요약 로그
    eventTimeline.maybePrintInternalSummary();
    
    // 현재 Envelope 저장 (파생 이벤트용)
    _currentEnvelope = envelope;
    
    // ========== EnterCombat 시 부모 문맥 주입 ==========
    if (e is EnterCombat) {
      for (final module in _modules) {
        if (module is CombatModule) {
          module.setParentContext(
            traceId: envelope.traceId,
            eventId: envelope.eventId,
            depth: envelope.depth,
          );
          
          // 슬롯 초기화
          combatStateSlot.reset();
          
          // 메트릭 시작
          combatMetrics.startCombat(simTimeMs: 0.0);
        }
      }
    }
    
    // ========== 순수 상태 전이 ==========
    final next = reduce(_vm, e);
    if (!identical(next, _vm)) {
      _vm = next;
      notifyListeners();
    }

    // ========== 모듈 실행 ==========
    final applicableModules = _modules.where((module) =>
      module.supportedPhases.contains(_vm.phase) &&
      module.handledEvents.contains(e.runtimeType)
    );

    for (final module in applicableModules) {
      final produced = await module.handle(e, _vm);
      for (final ev in produced) {
        await dispatch(ev);
      }
    }
    
    // ========== CombatResult 후 검증 ==========
    if (e is CombatResult) {
      // traceId 체인 검증
      if (envelope.traceId != null) {
        final chain = eventTimeline.getByTraceId(envelope.traceId!);
        eventGuards.verifyTraceChain(chain);
      }
      
      // QA 리그레션 게이트 검사
      combatMetrics.checkRegressionGates(eventTimeline);
    }
  }
  
  /// Safe Mode 처리: 안전 상태로 복귀
  /// 
  /// - 현재 trace 차단
  /// - 진행 중 전투 강제 종료 (패배 처리)
  /// - phase를 inGame_encounter로 복원
  Future<void> _handleSafeMode(String reason) async {
    print('[GameController] ⚠️ Safe Mode activated: $reason');
    
    // 전투 중이면 강제 종료
    if (_vm.phase == AppPhase.inGame_combat) {
      // CombatModule 정리
      for (final module in _modules) {
        if (module is CombatModule) {
          module.dispose();
        }
      }
      
      // Slot 정리
      combatStateSlot.markCombatEnded();
      
      // phase 복원 (reducer에서 처리되도록 이벤트 발송하지 않고 직접 변경)
      print('[GameController] Safe Mode: Combat force-ended, returning to encounter');
      
      // TODO: 안전한 방법으로 phase 복원
      // 현재는 로그만 출력하고 앱 멈춤 방지
    }
  }

  @override
  void dispose() {
    // 모듈 정리
    for (final module in _modules) {
      if (module is CombatModule) {
        module.dispose();
      }
    }
    
    super.dispose();
  }
}
