import '../../core/state/game_state.dart';
import '../../core/state/events.dart';
import '../../services/dialogue_index.dart';
import '../../dialogue/dialogue_engine.dart';
import '../../core/schedule/encounter_scheduler.dart'; // 🆕 XP 통합
import '../../core/game_controller.dart';
import 'dart:math';

class EncounterController {
  DialogueEngine? _engine;
  GameController? _gameController;  // GameController 참조
  
  // 🆕 XP 시스템: 현재 인카운터 ID 및 경로 추적
  String? _currentEncounterId;
  String? _currentEncounterPath;
  
  // 🆕 XP 통합: 스케줄러 인스턴스
  final EncounterScheduler _scheduler = EncounterScheduler.instance;
  
  // ✅ 전투 트리거 중복 방지
  String? _lastCombatCheckedSceneId;

  // ✅ jump 오퍼레이션이 생성한 내부 선택지(id=auto_jump) 처리
  static bool _isAutoJumpOnlyView(DialogueView v) =>
      v.choices.isNotEmpty && v.choices.every((c) => c.id == 'auto_jump');

  Future<void> _drainAutoJumpIfNeeded() async {
    if (_engine == null) return;
    if (_engine!.isEnded) return;

    var view = _engine!.getCurrentView();
    var guard = 0;
    while (view != null &&
        !_engine!.isEnded &&
        view.hasChoices &&
        _isAutoJumpOnlyView(view) &&
        guard < 20) {
      await _engine!.selectChoice('auto_jump');
      view = _engine!.getCurrentView();
      guard++;
    }
  }
  
  /// GameController 설정
  void setGameController(GameController controller) {
    _gameController = controller;
  }
  
  /// 커스텀 이벤트 핸들러 등록
  void _registerCustomHandlers() {
    if (_engine == null) return;
    
    // enterCombat 이벤트 처리
    _engine!.registerCustomEventHandler('enterCombat', (data) {
      print('[EncounterController] enterCombat event triggered');
      print('[EncounterController] Combat data: $data');
      
      if (_gameController == null) {
        print('[EncounterController] ⚠️ GameController not set, cannot start combat');
        return;
      }
      
      // victoryScene과 defeatScene 경로 추출
      final victoryScene = data['victoryScene'] as String?;
      final defeatScene = data['defeatScene'] as String?;
      
      // 현재 인카운터 파일 경로를 기준으로 절대 경로 생성
      String? victoryPath;
      String? defeatPath;
      
      if (victoryScene != null && _currentEncounterPath != null) {
        // 같은 파일 내 씬이면 "파일경로#씬ID" 형식
        victoryPath = '$_currentEncounterPath#$victoryScene';
      }
      
      if (defeatScene != null && _currentEncounterPath != null) {
        // 같은 파일 내 씬이면 "파일경로#씬ID" 형식
        defeatPath = '$_currentEncounterPath#$defeatScene';
      }
      
      print('[EncounterController] Victory path: $victoryPath');
      print('[EncounterController] Defeat path: $defeatPath');
      
      // EnterCombat 이벤트 발송
      _gameController!.dispatch(EnterCombat(
        data,
        victoryPath,
        defeatPath,
      ));
    });
    
    // 🆕 unlock_meta 이벤트 처리 (메타 진행도 언락)
    _engine!.registerCustomEventHandler('unlock_meta', (data) {
      print('[EncounterController] unlock_meta event triggered');
      print('[EncounterController] Unlock data: $data');
      
      if (_gameController == null) {
        print('[EncounterController] ⚠️ GameController not set, cannot unlock meta flag');
        return;
      }
      
      final flag = data['flag'] as String?;
      if (flag == null || flag.isEmpty) {
        print('[EncounterController] ⚠️ No flag specified in unlock_meta');
        return;
      }
      
      // UnlockMetaFlag 이벤트 발송
      _gameController!.dispatch(UnlockMetaFlag(flag));
      print('[EncounterController] 🔓 Dispatched UnlockMetaFlag: $flag');
    });
  }
  
  // ❌ 삭제: 기존 하드코딩 라인들
  // int _fallbackIndex = 0;
  // final List<String> _fallbackLines = const [
  //   '모험을 시작하는 그대에게...',
  //   '높은 언덕과 거친 파도를 지나...',
  //   '그렇게도 나의 그늘이 궁금한가?',
  // ];

  Future<List<GEvent>> handle(GEvent e, GameVM vm) async {
    if (e is CharacterCreated) {
      return await _handleStartGame(vm);
    } else if (e is Next) {
      return await _handleNext();
    } else if (e is Choose) { // Choose 이벤트 처리 복구
      return await _handleChoose(e.id);
    } else if (e is SlotOpened) { // 🆕 XP 통합: 다음 인카운터 로드
      return await _handleSlotOpened(vm);
    } else if (e is LoadEncounter) { // 특정 인카운터 로드
      return await _handleLoadEncounter(e.encounterPath, e.sceneId);
    }
    return const [];
  }
  
  /// 선택지 처리
  Future<List<GEvent>> _handleChoose(String choiceId) async {
    if (_engine == null) {
      print('[EncounterController] ⚠️ Engine is null, cannot handle choice');
      return const [];
    }

    try {
      // ✅ auto_jump는 jump 오퍼레이션이 만든 내부 선택지이며 UI에 노출되면 안 됨.
      // 이미 자동 진행된 뒤 클릭될 수 있어 "Choice not found"가 발생하므로 흡수한다.
      if (choiceId == 'auto_jump') {
        print('[EncounterController] Ignoring manual auto_jump choice; auto-advancing instead');
        await _drainAutoJumpIfNeeded();
        final result = await _handleNext();
        _checkAndTriggerCombat();
        return result;
      }

      print('[EncounterController] Selecting choice: $choiceId');
      print('[EncounterController] Engine state before selectChoice: isEnded=${_engine!.isEnded}');
      
      await _engine!.selectChoice(choiceId);
      
      print('[EncounterController] selectChoice completed, isEnded=${_engine!.isEnded}');
      
      // ✅ 선택지가 end를 트리거했는지 확인
      if (_engine!.isEnded) {
        print('[EncounterController] Dialogue ended after choice selection');
        
        // 🆕 XP 시스템: 인카운터 종료 이벤트 발생
        final encounterId = _currentEncounterId ?? 'unknown';
        final encounterPath = _currentEncounterPath ?? '';
        final metadataXp = _extractMetadataXp();
        final outcome = _createOutcome(
          success: true,
          encounterPath: encounterPath,
          xp: metadataXp,
        );
        _engine = null;
        _currentEncounterId = null;
        _currentEncounterPath = null;
        
        print('[EncounterController] Returning EncounterEnded + SlotOpened');
        // 🆕 XP 통합: 인카운터 종료 + 다음 슬롯 열기
        return [EncounterEnded(encounterId, outcome), const SlotOpened()];
      }
      
      print('[EncounterController] Dialogue not ended, calling _handleNext');
      final result = await _handleNext();
      
      // ✅ 선택지 처리 후 씬 변경되었을 수 있으므로 전투 체크
      _checkAndTriggerCombat();
      
      return result;
    } catch (e, stackTrace) {
      print('[EncounterController] Choice handling failed: $e');
      print('[EncounterController] StackTrace: $stackTrace');
      return [EncounterLoaded('선택 처리 중 오류가 발생했습니다.')];
    }
  }
  
  /// 현재 씬의 enemyInventory metadata 확인하여 전투 자동 시작
  void _checkAndTriggerCombat() {
    if (_engine == null || _gameController == null) return;
    if (_engine!.isEnded) return;
    
    try {
      final currentScene = _engine!.runtime?.getCurrentScene();
      if (currentScene == null) return;
      
      // ✅ 중복 체크 방지: 같은 씬에서는 한 번만 체크
      if (_lastCombatCheckedSceneId == currentScene.id) {
        return;
      }
      _lastCombatCheckedSceneId = currentScene.id;
      
      final metadata = currentScene.metadata;
      if (metadata == null) return;
      
      // ✅ enemyInventory가 있으면 자동으로 enterCombat 트리거
      // metadata.enemyInventory 또는 metadata.combat.enemyInventory 형식 지원
      Map<String, dynamic>? enemyInventoryData;
      if (metadata.containsKey('enemyInventory')) {
        enemyInventoryData = metadata['enemyInventory'] as Map<String, dynamic>?;
      } else if (metadata.containsKey('combat')) {
        final combat = metadata['combat'] as Map<String, dynamic>?;
        enemyInventoryData = combat?['enemyInventory'] as Map<String, dynamic>?;
      }
      
      if (enemyInventoryData != null) {
        print('[EncounterController] Detected enemyInventory in scene metadata, triggering combat');
        
        // enterCombat 이벤트 데이터 구성 (EnemyInventoryLoader가 기대하는 형식)
        final combatData = <String, dynamic>{
          'combat': {
            'enemyInventory': enemyInventoryData,
          },
        };
        
        // victoryScene과 defeatScene 경로 추출
        final victoryScene = metadata['victoryScene'] as String?;
        final defeatScene = metadata['defeatScene'] as String?;
        
        String? victoryPath;
        String? defeatPath;
        
        if (victoryScene != null && _currentEncounterPath != null) {
          victoryPath = '$_currentEncounterPath#$victoryScene';
        }
        
        if (defeatScene != null && _currentEncounterPath != null) {
          defeatPath = '$_currentEncounterPath#$defeatScene';
        }
        
        print('[EncounterController] Auto-triggering EnterCombat: victory=$victoryPath, defeat=$defeatPath');
        
        // EnterCombat 이벤트 발송
        _gameController!.dispatch(EnterCombat(
          combatData,
          victoryPath,
          defeatPath,
        ));
      }
    } catch (e) {
      print('[EncounterController] Failed to check combat trigger: $e');
    }
  }

  /// 특정 인카운터 로드 (파일 경로 + 씬 ID)
  Future<List<GEvent>> _handleLoadEncounter(String encounterPath, String? sceneId) async {
    try {
      // "파일경로#씬ID" 형식 파싱
      String filePath = encounterPath;
      String? targetScene = sceneId;
      
      if (encounterPath.contains('#')) {
        final parts = encounterPath.split('#');
        filePath = parts[0];
        targetScene = parts.length > 1 ? parts[1] : null;
      }
      
      print('[EncounterController] Loading specific encounter: $filePath${targetScene != null ? ", scene: $targetScene" : ""}');
      
      // 인카운터 ID 및 경로 저장
      _currentEncounterId = _extractEncounterId(filePath);
      _currentEncounterPath = filePath;
      _lastCombatCheckedSceneId = null; // ✅ 새 인카운터 로드 시 초기화
      
      // DialogueEngine 초기화
      _engine = DialogueEngine();
      
      // 커스텀 이벤트 핸들러 등록 (enterCombat 등)
      _registerCustomHandlers();
      
      // 대화 로드 및 시작
      await _engine!.loadDialogue(filePath);
      
      // 특정 씬으로 시작하거나 기본 시작
      if (targetScene != null) {
        await _engine!.start(fromScene: targetScene);
      } else {
        await _engine!.start();
      }

      // ✅ jump(auto_jump) 노드가 첫 화면에 걸리면 자동 처리
      await _drainAutoJumpIfNeeded();
      
      // 첫 화면 가져오기
      final view = _engine!.getCurrentView();
      if (view != null) {
        final events = <GEvent>[];
        if (view.hasText) {
          print('[EncounterController] Encounter loaded: ${view.text!.substring(0, view.text!.length > 50 ? 50 : view.text!.length)}...');
          events.add(EncounterLoaded(view.text!));
        }
        if (view.hasChoices) {
          events.add(EncounterViewUpdated(
            text: view.text,
            choices: view.choices
                .where((c) => c.id != 'auto_jump') // ✅ 내부 jump 선택지 숨김
                .map((c) => ChoiceVM(
                      c.id,
                      c.text,
                      enabled: c.enabled,
                      why: c.disabledReason,
                    ))
                .toList(),
          ));
        }
        if (events.isNotEmpty) return events;
      }
      
      return [EncounterLoaded('인카운터를 불러왔습니다.')];
    } catch (e, stackTrace) {
      print('[EncounterController] LoadEncounter failed: $e');
      print('[EncounterController] StackTrace: $stackTrace');
      return [EncounterLoaded('인카운터 로드 중 오류가 발생했습니다.')];
    }
  }

  Future<List<GEvent>> _handleStartGame(GameVM vm) async {
    try {
      print('[EncounterController] Starting game, loading random encounter...');
      
      // 🎲 랜덤 인카운터 파일 선택
      final encounterPath = await _selectRandomStartEncounterPath();
      
      if (encounterPath != null) {
        print('[EncounterController] Loading encounter: $encounterPath');
        
        // 🆕 XP 시스템: 인카운터 ID 및 경로 저장
        _currentEncounterId = _extractEncounterId(encounterPath);
        _currentEncounterPath = encounterPath;
        _lastCombatCheckedSceneId = null; // ✅ 새 인카운터 로드 시 초기화
        
        // DialogueEngine 초기화
        _engine = DialogueEngine();
        
        // 커스텀 이벤트 핸들러 등록 (enterCombat 등)
        _registerCustomHandlers();
        
        // 대화 로드 및 시작
        await _engine!.loadDialogue(encounterPath);
        await _engine!.start();

        // ✅ jump(auto_jump) 노드가 첫 화면에 걸리면 자동 처리
        await _drainAutoJumpIfNeeded();
        
        // 첫 화면 가져오기
        final view = _engine!.getCurrentView();
        if (view != null) {
          final events = <GEvent>[];
          if (view.hasText) {
            print('[EncounterController] First text loaded: ${view.text!.substring(0, view.text!.length > 50 ? 50 : view.text!.length)}...');
            events.add(EncounterLoaded(view.text!));
          } else {
            print('[EncounterController] No text in first view');
          }
          if (view.hasChoices) {
            events.add(EncounterViewUpdated(
              text: view.text,
              choices: view.choices
                  .where((c) => c.id != 'auto_jump') // ✅ 내부 jump 선택지 숨김
                  .map((c) => ChoiceVM(
                        c.id,
                        c.text,
                        enabled: c.enabled,
                        why: c.disabledReason,
                      ))
                  .toList(),
            ));
          }
          if (events.isNotEmpty) return events;
        }
      } else {
        print('[EncounterController] No encounter path selected');
      }
      
      // ❌ 실패시에도 에러 반환 (하드코딩 사용하지 않음)
      print('[EncounterController] Failed to load any encounter');
      return [EncounterLoaded('인카운터를 불러올 수 없습니다.')];
    } catch (e, stackTrace) {
      print('[EncounterController] StartGame failed: $e');
      print('[EncounterController] StackTrace: $stackTrace');
      return [EncounterLoaded('인카운터 로드 중 오류가 발생했습니다.')];
    }
  }

  Future<List<GEvent>> _handleNext() async {
    // DialogueEngine이 있으면 사용
    if (_engine != null && !_engine!.isEnded) {
      // ✅ jump(auto_jump) 노드가 끼어 있으면 UI에 보여주지 않고 자동 진행
      await _drainAutoJumpIfNeeded();
      final currentView = _engine!.getCurrentView();

      List<ChoiceVM> _toChoiceVMs(DialogueView view) {
        return view.choices
            .where((c) => c.id != 'auto_jump') // ✅ 내부 jump 선택지 숨김
            .map((c) => ChoiceVM(
                  c.id,
                  c.text,
                  enabled: c.enabled,
                  why: c.disabledReason,
                ))
            .toList();
      }
      
      // ✅ 선택지가 있으면 화면에 표시하고 입력을 기다린다
      if (currentView != null && currentView.hasChoices) {
        final filtered = _toChoiceVMs(currentView);
        // auto_jump만 있는 뷰라면 자동 진행 후 다시 계산
        if (filtered.isEmpty && _isAutoJumpOnlyView(currentView)) {
          await _drainAutoJumpIfNeeded();
          return await _handleNext();
        }
        return [
          EncounterViewUpdated(
            text: currentView.text,
            choices: filtered,
          ),
        ];
      }
      
      // 텍스트만 있으면 다음으로 진행
      if (currentView != null && currentView.canContinue) {
        _engine!.advance();
        
        // effect/jump 등 "표시할 것이 없는 노드"가 연속으로 나올 수 있어 제한적으로 스킵
        var nextView = _engine!.getCurrentView();
        var guard = 0;
        while (nextView != null &&
            !nextView.isEnded &&
            !nextView.hasText &&
            !nextView.hasChoices &&
            guard < 20) {
          _engine!.advance();
          nextView = _engine!.getCurrentView();
          guard++;
        }

        if (nextView != null) {
          if (nextView.isEnded) {
            print('[EncounterController] Dialogue ended');
            
            // 🆕 XP 시스템: 인카운터 종료 이벤트 발생
            final encounterId = _currentEncounterId ?? 'unknown';
            final encounterPath = _currentEncounterPath ?? '';
            final metadataXp = _extractMetadataXp(); // 🆕 metadata에서 xp 추출
            final outcome = _createOutcome(
              success: true,
              encounterPath: encounterPath,
              xp: metadataXp, // 🆕 metadata의 xp 전달
            );
            _engine = null;
            _currentEncounterId = null;
            _currentEncounterPath = null;
            
            // 🆕 XP 통합: 인카운터 종료 + 다음 슬롯 열기
            return [EncounterEnded(encounterId, outcome), const SlotOpened()];
          }
          
          // ✅ 씬 변경 후 enemyInventory metadata 확인하여 전투 자동 시작
          _checkAndTriggerCombat();
          
          // ✅ 핵심: advance() 후 choice-only(텍스트 없음) 뷰도 렌더링
          if (nextView.hasChoices) {
            return [
              EncounterViewUpdated(
                text: nextView.text, // null이면 기존 텍스트 유지 (reducer copyWith)
                choices: _toChoiceVMs(nextView),
              ),
            ];
          }

          if (nextView.hasText) {
            return [
              EncounterLoaded(nextView.text!),
              const EncounterViewUpdated(choices: []),
            ];
          }
        }
      }
      
      // 대화 종료
      print('[EncounterController] Dialogue finished');
      
      // 🆕 XP 시스템: 인카운터 종료 이벤트 발생
      final encounterId = _currentEncounterId ?? 'unknown';
      final encounterPath = _currentEncounterPath ?? '';
      final metadataXp = _extractMetadataXp(); // 🆕 metadata에서 xp 추출
      final outcome = _createOutcome(
        success: true,
        encounterPath: encounterPath,
        xp: metadataXp, // 🆕 metadata의 xp 전달
      );
      _engine = null;
      _currentEncounterId = null;
      _currentEncounterPath = null;
      
      // 🆕 XP 통합: 인카운터 종료 + 다음 슬롯 열기
      return [EncounterEnded(encounterId, outcome), const SlotOpened()];
    }
    
    // ❌ 폴백 제거 - DialogueEngine이 없으면 빈 배열 반환
    return const [];
  }

  /// 랜덤 시작 인카운터 경로 선택
  Future<String?> _selectRandomStartEncounterPath() async {
    try {
      final entries = await DialogueIndex.instance.getStartEncounters();
      if (entries.isEmpty) {
        print('[EncounterController] No entries in index');
        return null;
      }

      // 가중치 기반 랜덤 선택
      final random = Random();
      final totalWeight = entries.fold<int>(0, (sum, entry) => sum + entry.weight);
      
      if (totalWeight <= 0) {
        print('[EncounterController] Selected (no weight): ${entries.first.path}');
        return entries.first.path;
      }
      
      int randomValue = random.nextInt(totalWeight);
      
      for (final entry in entries) {
        randomValue -= entry.weight;
        if (randomValue < 0) {
          print('[EncounterController] Selected (weighted): ${entry.path}');
          return entry.path;
        }
      }
      
      print('[EncounterController] Selected (fallback): ${entries.last.path}');
      return entries.last.path;
    } catch (e) {
      print('[EncounterController] Selection failed: $e');
      return null;
    }
  }

  // ❌ 삭제: _useFallback() 메서드 전체 제거
  
  // 🆕 XP 시스템: 인카운터 ID 추출 헬퍼
  String _extractEncounterId(String path) {
    // 경로에서 파일명 추출 (예: "assets/dialogue/start/start_001.json" -> "start_001")
    final parts = path.split('/');
    final fileName = parts.last;
    return fileName.replaceAll('.json', '');
  }
  
  // 🆕 metadata에서 XP 추출
  int? _extractMetadataXp() {
    if (_engine?.runtime?.dialogueData.metadata != null) {
      final metadata = _engine!.runtime!.dialogueData.metadata!;
      if (metadata.containsKey('xp')) {
        final xpValue = metadata['xp'];
        if (xpValue is int && xpValue >= 1 && xpValue <= 3) {
          return xpValue;
        }
      }
    }
    return null; // metadata에 xp가 없거나 유효하지 않음
  }
  
  // 🆕 XP 시스템: 인카운터 결과 생성
  Map<String, dynamic> _createOutcome({
    bool success = true,
    String? difficulty,
    int? xp,
    String? encounterPath,
  }) {
    return {
      'success': success,
      if (difficulty != null) 'difficulty': difficulty,
      if (xp != null) 'xp': xp,
      if (encounterPath != null) 'encounterPath': encounterPath,
    };
  }
  
  // 🆕 XP 통합: 다음 슬롯 인카운터 로드
  Future<List<GEvent>> _handleSlotOpened(GameVM vm) async {
    try {
      print('[EncounterController] Slot opened - selecting next encounter...');
      
      // 🎯 스케줄러를 통해 다음 인카운터 선택
      final selection = await _scheduler.nextSlot();
      
      if (selection == null) {
        print('[EncounterController] No encounter selected (terminal or error)');
        return const [];
      }
      
      print('[EncounterController] Selected: $selection');
      
      // 인카운터 로드
      return await _loadEncounter(selection.path);
    } catch (e, stackTrace) {
      print('[EncounterController] SlotOpened failed: $e');
      print('[EncounterController] StackTrace: $stackTrace');
      return [EncounterLoaded('다음 인카운터를 불러올 수 없습니다.')];
    }
  }
  
  // 🆕 XP 통합: 인카운터 로드 헬퍼
  Future<List<GEvent>> _loadEncounter(String encounterPath) async {
    try {
      print('[EncounterController] Loading encounter: $encounterPath');
      
      // 🆕 인카운터 ID 및 경로 저장
      _currentEncounterId = _extractEncounterId(encounterPath);
      _currentEncounterPath = encounterPath;
      _lastCombatCheckedSceneId = null; // ✅ 새 인카운터 로드 시 초기화
      
      // DialogueEngine 초기화
      _engine = DialogueEngine();
      
      // 커스텀 이벤트 핸들러 등록 (enterCombat 등)
      _registerCustomHandlers();
      
      // 대화 로드 및 시작
      await _engine!.loadDialogue(encounterPath);
      await _engine!.start();
      
      // 첫 화면 가져오기
      final view = _engine!.getCurrentView();
      if (view != null && view.hasText) {
        print('[EncounterController] Encounter loaded: ${view.text!.substring(0, view.text!.length > 50 ? 50 : view.text!.length)}...');
        return [EncounterLoaded(view.text!)];
      } else {
        print('[EncounterController] No text in first view');
        return [EncounterLoaded('인카운터에 텍스트가 없습니다.')];
      }
    } catch (e, stackTrace) {
      print('[EncounterController] Load encounter failed: $e');
      print('[EncounterController] StackTrace: $stackTrace');
      return [EncounterLoaded('인카운터 로드 중 오류가 발생했습니다.')];
    }
  }
}
















