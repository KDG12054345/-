import 'dart:math';
import 'dart:convert';
import 'dart:io';
import '../core/game_controller.dart';
import '../core/state/game_state.dart';
import '../core/state/events.dart';
import '../core/state/app_phase.dart';
import '../core/state/combat_state.dart';
import '../modules/character_creation/character_creation_module.dart';
import '../modules/encounter/encounter_module.dart';
import '../modules/combat/combat_module.dart';
import '../modules/reward/reward_module.dart';
import '../modules/xp/xp_module.dart';
import '../combat/character.dart';

/// Headless TestHarness - UI 없이 게임 로직을 검증하는 엔진
/// 
/// 이 클래스는 GameController를 직접 인스턴스화하고,
/// 이벤트를 제어하여 게임 로직을 테스트할 수 있게 합니다.
class HeadlessTestHarness {
  GameController? _controller;
  CombatModule? _combatModule;
  String _runId = '';
  int _gameTimeMs = 0;
  int _seed = 0;
  Random? _rng;
  
  /// 현재 GameController 인스턴스 (null일 수 있음)
  GameController? get controller => _controller;
  
  /// 현재 RUN_ID
  String get runId => _runId;
  
  /// 현재 게임 시간 (밀리초)
  int get gameTimeMs => _gameTimeMs;
  
  /// 현재 시드
  int get seed => _seed;
  
  /// 게임 초기화 및 시작
  /// 
  /// [seed]를 사용하여 RNG를 고정하고, 게임을 시작합니다.
  /// StartGame 이벤트를 dispatch하여 캐릭터 생성 및 초기 인카운터 로드를 트리거합니다.
  Future<void> initialize(int seed) async {
    // RNG 시드 고정
    _seed = seed;
    _rng = Random(seed);
    
    // RUN_ID 생성 (UUID 형식)
    _runId = _generateRunId();
    _gameTimeMs = 0;
    
    _log('Initializing game with seed: $seed, RUN_ID: $_runId');
    
    // 모듈 생성
    final characterModule = CharacterCreationModule();
    final xpModule = XpModule();
    final encounterModule = EncounterModule();
    _combatModule = CombatModule();
    final rewardModule = RewardModule();
    
    // GameController 생성 (모듈 주입)
    _controller = GameController(
      modules: [
        characterModule,
        xpModule,
        encounterModule,
        _combatModule!,
        rewardModule,
      ],
    );
    
    // 게임 시작 이벤트 dispatch
    await _controller!.dispatch(const StartGame());
    
    // 이벤트 처리 완료 대기
    await Future.delayed(const Duration(milliseconds: 100));
    
    _log('Game initialized. Phase: ${_controller!.vm.phase}');
  }
  
  /// 강제로 전투 상태 진입
  /// 
  /// EnterCombat 이벤트를 dispatch하여 전투를 시작합니다.
  /// 기본 적 스탯을 사용하거나, [enemyStats]를 제공하여 커스텀 적을 생성할 수 있습니다.
  Future<void> forceEnterCombat({
    Map<String, dynamic>? enemyStats,
    String? enemyName,
    String? encounterTitle,
    String? victoryScenePath,
    String? defeatScenePath,
  }) async {
    if (_controller == null) {
      throw StateError('Game not initialized. Call initialize() first.');
    }
    
    _log('Forcing combat entry...');
    
    final payload = <String, dynamic>{
      'title': encounterTitle ?? '테스트 전투',
      'enemyName': enemyName ?? '테스트 적',
      if (enemyStats != null) 'enemyStats': enemyStats,
    };
    
    await _controller!.dispatch(EnterCombat(
      payload,
      victoryScenePath,
      defeatScenePath,
    ));
    
    // 이벤트 처리 완료 대기
    await Future.delayed(const Duration(milliseconds: 200));
    
    _log('Combat entered. Phase: ${_controller!.vm.phase}');
  }
  
  /// 게임 시간을 강제로 진행시키고 상태 업데이트
  /// 
  /// [milliseconds]만큼 시간을 진행시킵니다.
  /// 전투 중인 경우, CombatModule의 tick() 메서드를 호출하여 CombatEngine을 직접 업데이트합니다.
  Future<void> tick(int milliseconds) async {
    if (_controller == null) {
      throw StateError('Game not initialized. Call initialize() first.');
    }
    
    _gameTimeMs += milliseconds;
    
    // 전투 중인 경우 CombatModule의 tick() 메서드 호출
    if (_controller!.vm.phase == AppPhase.inGame_combat) {
      final combatState = _controller!.vm.combat;
      if (combatState != null && combatState.isActive && _combatModule != null) {
        _log('Combat tick: ${milliseconds}ms (elapsed: ${combatState.elapsedSeconds}s)');
        
        // CombatModule의 tick() 메서드를 호출하여 전투 엔진 업데이트
        _combatModule!.tick(milliseconds);
        
        // 이벤트 처리 완료 대기
        await Future.delayed(const Duration(milliseconds: 10));
      }
    } else {
      // 전투가 아닌 경우 시간만 증가
      await Future.delayed(Duration(milliseconds: milliseconds));
    }
  }
  
  /// 현재 GameVM의 주요 상태를 표준화된 JSON 형태로 반환
  /// 
  /// 반환되는 JSON 포맷:
  /// ```json
  /// {
  ///   "meta": { "run_id": "UUID", "seed": 1234, "timestamp": "ISO8601" },
  ///   "state": {
  ///     "phase": "AppPhase.inGame_combat",
  ///     "player": { "hp": 100, "stamina": 50, "effects": ["bleeding"] },
  ///     "enemy": { "hp": 80, "id": "goblin_scout" },
  ///     "combat": { "turn_timer": 12.5, "proc_queue_size": 2 }
  ///   }
  /// }
  /// ```
  String dumpState() {
    final timestamp = DateTime.now().toIso8601String();
    
    final meta = <String, dynamic>{
      'run_id': _runId,
      'seed': _seed,
      'timestamp': timestamp,
    };
    
    if (_controller == null) {
      return jsonEncode({
        'meta': meta,
        'state': {
          'error': 'Game not initialized',
          'gameTimeMs': _gameTimeMs,
        },
      });
    }
    
    final vm = _controller!.vm;
    final state = <String, dynamic>{
      'phase': vm.phase.toString(),
    };
    
    // 플레이어 정보 (전투 중인 경우 전투 캐릭터, 아닌 경우 일반 플레이어)
    if (vm.combat != null && vm.combat!.player != null) {
      final player = vm.combat!.player!;
      state['player'] = {
        'hp': player.currentHealth,
        'maxHp': player.maxHealth,
        'stamina': player.currentStamina,
        'maxStamina': player.maxStamina,
        'effects': player.statusEffects.keys.toList(),
      };
    } else if (vm.player != null) {
      state['player'] = {
        'vitality': vm.player!.vitality,
        'sanity': vm.player!.sanity,
        'strength': vm.player!.strength,
        'agility': vm.player!.agility,
        'intelligence': vm.player!.intelligence,
        'charisma': vm.player!.charisma,
        'traits': vm.player!.traits.map((t) => t.id).toList(),
      };
    }
    
    // 적 정보 (전투 중인 경우)
    if (vm.combat != null && vm.combat!.enemy != null) {
      final enemy = vm.combat!.enemy!;
      state['enemy'] = {
        'hp': enemy.currentHealth,
        'maxHp': enemy.maxHealth,
        'id': enemy.name, // 적 ID는 이름으로 대체
        'stamina': enemy.currentStamina,
        'effects': enemy.statusEffects.keys.toList(),
      };
    }
    
    // 전투 상태 정보
    if (vm.combat != null) {
      final combat = vm.combat!;
      state['combat'] = {
        'turn_timer': combat.elapsedSeconds.toDouble(),
        'isActive': combat.isActive,
        'isCombatOver': combat.isCombatOver,
        'playerWon': combat.playerWon,
        'encounterTitle': combat.encounterTitle,
        // proc_queue_size는 현재 구현에서 직접 접근 불가하므로 생략
        // 필요시 CombatModule에 public getter 추가 필요
      };
    }
    
    // 추가 상태 정보
    if (vm.text != null) {
      state['text'] = vm.text;
    }
    if (vm.loading) {
      state['loading'] = vm.loading;
    }
    if (vm.error != null) {
      state['error'] = vm.error;
    }
    if (vm.debug != null) {
      state['debug'] = vm.debug;
    }
    
    // JSON 인코더 생성 (들여쓰기 포함)
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'meta': meta,
      'state': state,
    });
  }
  
  /// 상태 덤프를 파일로 저장
  /// 
  /// [filename]에 상태를 JSON 형식으로 저장합니다.
  /// 파일이 이미 존재하면 덮어씁니다.
  /// 
  /// 반환값: 저장된 파일의 절대 경로
  Future<String> saveDumpToFile(String filename) async {
    final stateJson = dumpState();
    
    // 파일 경로 정규화
    final file = File(filename);
    final directory = file.parent;
    
    // 디렉토리가 없으면 생성
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    // 파일에 쓰기
    await file.writeAsString(stateJson);
    
    _log('State dump saved to: ${file.absolute.path}');
    
    return file.absolute.path;
  }
  
  /// RUN_ID 생성 (UUID 형식)
  String _generateRunId() {
    // 간단한 UUID v4 형식 생성 (실제 UUID는 아니지만 충분히 고유함)
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(0x1000000).toRadixString(16).padLeft(6, '0');
    
    return '${timestamp.toRadixString(16)}-$randomPart-${_seed.toRadixString(16)}';
  }
  
  /// 로그 출력 (RUN_ID와 GameTime 포함)
  void _log(String message) {
    final timeStr = (_gameTimeMs / 1000.0).toStringAsFixed(2);
    print('[HeadlessTestHarness][$_runId][${timeStr}s] $message');
  }
  
  /// 리소스 정리
  void dispose() {
    _controller?.dispose();
    _controller = null;
    _combatModule = null;
    _rng = null;
  }
}

