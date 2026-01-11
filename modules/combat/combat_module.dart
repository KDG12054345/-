import 'dart:async';
import 'dart:math';
import '../../core/game_controller.dart';
import '../../core/state/app_phase.dart';
import '../../core/state/events.dart';
import '../../core/state/game_state.dart';
import '../../core/state/combat_state.dart';
import '../../combat/character.dart';
import '../../combat/stats.dart';
import '../../combat/enemy_inventory_loader.dart';
import '../../combat/effect_processor.dart';
import '../../inventory/combat_lock_system.dart';
import 'inventory_adapter.dart';

class CombatModule implements GameModule {
  Timer? _combatTimer;
  CombatEngine? _currentEngine;
  GameController? _controller;
  
  // ========== 배속 시스템 ==========
  double _speedMultiplier = 1.0;
  static const double MAX_SPEED = 5.0;
  static const double MIN_SPEED = 1.0;
  
  // ========== 세션 관리 ==========
  String? _currentSessionId;
  bool _combatEnded = false;
  
  // ========== 부모 문맥 (traceId/parentId/depth) ==========
  String? _parentTraceId;
  String? _parentEventId;
  int _parentDepth = 0;
  
  // ========== UI 샘플링 (시뮬레이션 시간 기준) ==========
  double _lastUiUpdateSimTime = 0.0;
  static const double UI_UPDATE_INTERVAL_SIM_MS = 250.0;
  bool _firstFramePushed = false;  // 예외 (a): 첫 프레임 즉시 푸시
  
  // ========== 디버그 옵션 ==========
  /// 디버그용 seed 고정 옵션 (재현성용)
  static int? debugFixedSeed;
  
  /// 디버그/QA용 legacy UI dispatch 모드 토글
  /// - true: CmdQueue 경유 (250ms 샘플링 유지)
  /// - false (기본): CombatStateSlot 직접 업데이트
  static bool useLegacyUiDispatch = false;
  
  // 패널티 정보 저장
  int _vitalityPenalty = 1;
  int _sanityPenalty = 0;
  bool _instantDeath = false;
  bool _instantMadness = false;
  
  // 전투 후 이동할 인카운터 경로
  String? _victoryScenePath;
  String? _defeatScenePath;
  String? _encounterTitle;
  
  static const int TICK_RATE_MS = 100;  // 100ms마다 업데이트 (10 FPS)
  
  @override
  Set<AppPhase> get supportedPhases => {AppPhase.inGame_combat};

  @override
  Set<Type> get handledEvents => {EnterCombat, CombatResult};

  @override
  Future<List<GEvent>> handle(GEvent event, GameVM vm) async {
    if (event is EnterCombat) {
      return _handleEnterCombat(event, vm);
    } else if (event is CombatResult) {
      return _handleCombatResult(event, vm);
    }
    return [];
  }
  
  // ========== 배속 제어 ==========
  
  /// 배속 설정 (1.0 ~ 5.0 클램프)
  void setSpeed(double speed) {
    _speedMultiplier = speed.clamp(MIN_SPEED, MAX_SPEED);
    print('[CombatModule] Speed set to ${_speedMultiplier}x');
  }
  
  /// 현재 배속
  double get speedMultiplier => _speedMultiplier;
  
  // ========== 부모 문맥 주입 ==========
  
  /// EnterCombat 시점에 Controller가 부모 문맥 주입
  void setParentContext({
    String? traceId,
    String? eventId,
    int depth = 0,
  }) {
    _parentTraceId = traceId;
    _parentEventId = eventId;
    _parentDepth = depth;
    print('[CombatModule] Parent context set: '
          'traceId=$traceId, eventId=$eventId, depth=$depth');
  }
  
  /// 전투 시작 처리
  List<GEvent> _handleEnterCombat(EnterCombat event, GameVM vm) {
    print('[CombatModule] 전투 시작!');
    
    // ========== 새 세션 ID 발급 ==========
    _currentSessionId = _generateSessionId();
    _combatEnded = false;
    _firstFramePushed = false;
    _lastUiUpdateSimTime = 0.0;
    print('[CombatModule] New session: $_currentSessionId');
    
    // Controller에 세션 ID 전달
    if (_controller != null) {
      _controller!.combatStateSlot.setSessionId(_currentSessionId!);
    }
    
    // payload에서 적 정보 추출
    final payload = event.payload as Map<String, dynamic>?;
    final encounterTitle = payload?['title'] as String? ?? '전투';
    
    // 패널티 정보 저장
    _vitalityPenalty = payload?['vitalityPenalty'] as int? ?? 1;
    _sanityPenalty = payload?['sanityPenalty'] as int? ?? 0;
    _instantDeath = payload?['instantDeath'] as bool? ?? false;
    _instantMadness = payload?['instantMadness'] as bool? ?? false;
    
    // 승리/패배 경로 저장
    _victoryScenePath = event.victoryScenePath;
    _defeatScenePath = event.defeatScenePath;
    _encounterTitle = payload?['title'] as String? ?? '전투';
    print('[CombatModule] Victory path: $_victoryScenePath, Defeat path: $_defeatScenePath');
    
    // ========== 플레이어 캐릭터 생성 ==========
    final playerBaseStats = CombatStats(
      maxHealth: (vm.player?.vitality ?? 4) * 25,
      currentHealth: (vm.player?.vitality ?? 4) * 25,
      attackPower: 0,
      accuracy: 75,
    );
    
    final Character playerChar;
    
    if (vm.playerInventory != null) {
      playerChar = InventoryAdapter.createPlayerCharacter(
        name: '모험가',
        baseStats: playerBaseStats,
        inventory: vm.playerInventory!,
      );
      print('[CombatModule] Player character created with inventory bonus');
      
      vm.playerInventory!.lockSystem.lock(
        reason: InventoryLockReason.combat,
        additionalInfo: encounterTitle,
      );
    } else {
      playerChar = Character(
        name: '모험가',
        stats: playerBaseStats,
      );
      print('[CombatModule] Player character created (no inventory)');
    }
    
    // ========== 적 캐릭터 생성 ==========
    final enemyStats = payload?['enemyStats'] as Map<String, dynamic>?;
    
    final enemyBaseStats = CombatStats(
      maxHealth: enemyStats?['maxHealth'] as int? ?? 80,
      currentHealth: enemyStats?['maxHealth'] as int? ?? 80,
      attackPower: enemyStats?['attackPower'] as int? ?? 15,
      accuracy: enemyStats?['accuracy'] as int? ?? 70,
    );
    
    print('[CombatModule] Loading enemy inventory...');
    final enemyInventory = EnemyInventoryLoader.loadFromEncounter(payload);
    print('[CombatModule] Enemy inventory loaded: ${enemyInventory.items.length} items');
    
    final enemyChar = InventoryAdapter.createEnemyCharacter(
      name: payload?['enemyName'] as String? ?? '도적',
      baseStats: enemyBaseStats,
      inventory: enemyInventory,
    );
    
    // ========== 전투 엔진 생성 (재현성용 seed 지원) ==========
    final seed = debugFixedSeed ?? DateTime.now().millisecondsSinceEpoch;
    if (debugFixedSeed != null) {
      print('[CombatModule] Using fixed seed: $seed');
    }
    
    _currentEngine = CombatEngine(
      player: playerChar,
      enemy: enemyChar,
      randomSeed: seed,
    );
    _currentEngine!.start();
    
    // ========== 전투 시작 아이템 효과 적용 ==========
    if (vm.playerInventory != null) {
      EffectProcessor.processCombatStartEffects(
        items: vm.playerInventory!.placedItems,
        owner: playerChar,
      );
    }
    
    // 전투 상태 생성
    final combatState = CombatState(
      player: playerChar,
      enemy: enemyChar,
      isActive: true,
      elapsedSeconds: 0,
      encounterTitle: encounterTitle,
    );
    
    // ========== 예외 (a): 첫 프레임 즉시 푸시 ==========
    if (_controller != null) {
      _updateUi(combatState);
      _firstFramePushed = true;
    }
    
    // 전투 타이머 시작
    _startCombatTimer(combatState);
    
    // CombatStateUpdated는 Slot으로 전달되므로 이벤트 반환 불필요
    return [];
  }
  
  /// 전투 결과 처리
  List<GEvent> _handleCombatResult(CombatResult event, GameVM vm) {
    final result = event.result as Map<String, dynamic>?;
    final won = result?['won'] as bool? ?? false;
    print('[CombatModule] 전투 종료! 결과: ${won ? "승리" : "패배"}');
    
    // 플레이어 인벤토리 잠금 해제
    if (vm.playerInventory != null) {
      vm.playerInventory!.lockSystem.unlock();
      print('[CombatModule] Player inventory unlocked');
    }
    
    // EffectProcessor 정리
    EffectProcessor.clear();
    
    // 타이머 정리
    _stopCombatTimer();
    _currentEngine = null;
    
    return [];
  }
  
  /// 세션 ID 생성
  String _generateSessionId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return 'session_${now}_$random';
  }
  
  /// UI 업데이트 (Slot 또는 Legacy dispatch)
  void _updateUi(CombatState state) {
    if (_controller == null) return;
    if (_combatEnded) return;  // 종료 후 업데이트 금지
    
    if (useLegacyUiDispatch) {
      // Legacy 방식: CmdQueue 경유 (디버그/QA용)
      _controller!.dispatch(CombatStateUpdated(state));
    } else {
      // 기본 방식: Slot 직접 업데이트
      _controller!.combatStateSlot.update(state, sessionId: _currentSessionId!);
    }
    
    // 메트릭 기록
    _controller!.combatMetrics.recordUiUpdate();
  }
  
  /// 전투 타이머 시작 - 실제 전투 루프 실행
  void _startCombatTimer(CombatState initialState) {
    _stopCombatTimer();
    
    print('[CombatModule] ⏱️ 전투 타이머 시작! (${TICK_RATE_MS}ms마다 업데이트, 배속: ${_speedMultiplier}x)');
    print('[CombatModule] 🎮 Controller 연결 상태: ${_controller != null ? "연결됨" : "⚠️ 연결 안됨"}');
    
    int _tickCount = 0;
    
    _combatTimer = Timer.periodic(Duration(milliseconds: TICK_RATE_MS), (timer) {
      // 1. 세션 ID 검증
      if (_currentSessionId == null) {
        print('[CombatModule] ABORT: No session ID');
        timer.cancel();
        return;
      }
      
      // 2. 엔진 상태 검증
      if (_currentEngine == null || !_currentEngine!.isRunning) {
        timer.cancel();
        return;
      }
      
      // 3. 종료 플래그 검증
      if (_combatEnded) {
        timer.cancel();
        return;
      }
      
      _tickCount++;
      final tickStart = DateTime.now();
      
      // ========== dt 스케일링으로 배속 적용 ==========
      final scaledDt = TICK_RATE_MS.toDouble() * _speedMultiplier;
      _currentEngine!.update(scaledDt);
      
      // 패시브 아이템 효과 처리
      EffectProcessor.processPassiveTick(scaledDt);
      
      // 틱 메트릭 기록
      final tickDuration = DateTime.now().difference(tickStart);
      _controller?.combatMetrics.recordTick(elapsed: tickDuration);
      
      // 5초마다 진행 상황 로그 출력
      if (_tickCount % 50 == 0) {
        print('[CombatModule] 🎮 전투 진행 중: ${_currentEngine!.elapsedSeconds.toStringAsFixed(1)}초 | '
              'Player HP: ${_currentEngine!.player.currentHealth}/${_currentEngine!.player.maxHealth} | '
              'Enemy HP: ${_currentEngine!.enemy.currentHealth}/${_currentEngine!.enemy.maxHealth} | '
              'Speed: ${_speedMultiplier}x');
        
        // 메트릭 5초 요약
        _controller?.combatMetrics.maybePrintSummary(
          currentSimTimeMs: _currentEngine!.elapsedMs,
        );
      }
      
      // ========== 전투 종료 체크 ==========
      if (_currentEngine!.player.isDead || _currentEngine!.enemy.isDead) {
        final playerWon = _currentEngine!.enemy.isDead && !_currentEngine!.player.isDead;
        print('[CombatModule] 전투 종료 감지! 승자: ${playerWon ? "플레이어" : "적"}');
        
        // ========== 예외 (b): 마지막 상태 반영 ==========
        if (!_combatEnded) {
          final finalState = CombatState(
            player: _currentEngine!.player,
            enemy: _currentEngine!.enemy,
            isActive: false,
            elapsedSeconds: _currentEngine!.elapsedSeconds.floor(),
            encounterTitle: initialState.encounterTitle,
          );
          _updateUi(finalState);
        }
        
        // ========== 종료 처리 (체크리스트 순서 엄수) ==========
        _endCombat(playerWon);
        
        timer.cancel();
        return;
      }
      
      // ========== 시뮬레이션 시간 기준 UI 샘플링 ==========
      final currentSimTime = _currentEngine!.elapsedMs;
      if (currentSimTime - _lastUiUpdateSimTime >= UI_UPDATE_INTERVAL_SIM_MS) {
        _lastUiUpdateSimTime = currentSimTime;
        
        final updatedState = CombatState(
          player: _currentEngine!.player,
          enemy: _currentEngine!.enemy,
          isActive: true,
          elapsedSeconds: _currentEngine!.elapsedSeconds.floor(),
          encounterTitle: initialState.encounterTitle,
        );
        
        _updateUi(updatedState);
      }
    });
  }
  
  /// 전투 종료 처리 (체크리스트 순서 엄수)
  /// 
  /// 1. Timer.cancel()
  /// 2. _combatEnded = true
  /// 3. Slot.markCombatEnded()
  /// 4. dispatchWithContext(CombatResult)
  /// 5. Guards 불변조건 검사
  void _endCombat(bool playerWon) {
    // 1. Timer 취소
    _combatTimer?.cancel();
    _combatTimer = null;
    
    // 2. 모듈 종료 플래그
    _combatEnded = true;
    
    // 3. Slot 종료 (구독 갱신 중지)
    _controller?.combatStateSlot.markCombatEnded();
    
    // 4. CombatResult 발송 (문맥 포함)
    if (_controller != null) {
      _controller!.dispatchWithContext(
        CombatResult(
          {
            'won': playerWon,
            'vitalityPenalty': _vitalityPenalty,
            'sanityPenalty': _sanityPenalty,
            'instantDeath': _instantDeath,
            'instantMadness': _instantMadness,
            'elapsedTime': _currentEngine?.elapsedSeconds ?? 0,
            'playerHealth': _currentEngine?.player.currentHealth ?? 0,
            'enemyHealth': _currentEngine?.enemy.currentHealth ?? 0,
          },
          _victoryScenePath,
          _defeatScenePath,
        ),
        parentTraceId: _parentTraceId,
        parentEventId: _parentEventId,
        parentDepth: _parentDepth,
      );
      print('[CombatModule] ✅ CombatResult 이벤트 발송 완료 (문맥 포함)');
      
      // 5. 불변조건 검사 요청
      _controller!.eventGuards.verifyCombatEndInvariants(
        slot: _controller!.combatStateSlot,
        queue: _controller!.queue,
      );
    } else {
      print('[CombatModule] ⚠️ Controller가 null이어서 CombatResult를 발송할 수 없습니다!');
    }
  }
  
  /// 전투 타이머 정지
  void _stopCombatTimer() {
    _combatTimer?.cancel();
    _combatTimer = null;
    
    if (_currentEngine != null) {
      _currentEngine!.stop();
    }
    
    EffectProcessor.clear();
    
    // 패널티 정보 초기화
    _vitalityPenalty = 1;
    _sanityPenalty = 0;
    _instantDeath = false;
    _instantMadness = false;
    _encounterTitle = null;
  }
  
  /// GameController 참조 설정
  void setController(GameController controller) {
    _controller = controller;
  }
  
  /// Headless 환경에서 시간을 강제로 진행시키는 메서드
  void tick(int milliseconds) {
    if (_currentEngine != null && _currentEngine!.isRunning && !_combatEnded) {
      // dt 스케일링 적용
      final scaledMs = milliseconds.toDouble() * _speedMultiplier;
      _currentEngine!.update(scaledMs);
      
      // 전투 종료 체크
      if (_currentEngine!.player.isDead || _currentEngine!.enemy.isDead) {
        final playerWon = _currentEngine!.enemy.isDead && !_currentEngine!.player.isDead;
        print('[CombatModule] 전투 종료 감지! 승자: ${playerWon ? "플레이어" : "적"}');
        
        _endCombat(playerWon);
        return;
      }
      
      // 시뮬레이션 시간 기준 UI 샘플링
      final currentSimTime = _currentEngine!.elapsedMs;
      if (currentSimTime - _lastUiUpdateSimTime >= UI_UPDATE_INTERVAL_SIM_MS) {
        _lastUiUpdateSimTime = currentSimTime;
        
        final updatedState = CombatState(
          player: _currentEngine!.player,
          enemy: _currentEngine!.enemy,
          isActive: true,
          elapsedSeconds: _currentEngine!.elapsedSeconds.floor(),
          encounterTitle: _encounterTitle,
        );
        
        _updateUi(updatedState);
      }
    }
  }
  
  /// 모듈 정리
  void dispose() {
    _stopCombatTimer();
    _currentEngine = null;
    _controller = null;
    _currentSessionId = null;
    _combatEnded = false;
    _parentTraceId = null;
    _parentEventId = null;
    _parentDepth = 0;
  }
}
