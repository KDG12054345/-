/// XP 및 마일스톤 모듈
/// 
/// 인카운터 종료 이벤트를 받아 XP를 정산하고 마일스톤을 큐에 추가합니다.

import 'dart:convert';
import '../../core/game_controller.dart';
import '../../core/state/app_phase.dart';
import '../../core/state/events.dart';
import '../../core/state/game_state.dart';
import '../../core/xp/xp_service.dart';
import '../../core/milestone/milestone_service.dart';
import '../../core/schedule/encounter_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class XpModule implements GameModule {
  final XpService _xpService = XpService.instance;
  final MilestoneService _milestoneService = MilestoneService.instance;
  final EncounterScheduler _scheduler = EncounterScheduler.instance;
  
  // 🆕 초기화 완료 플래그
  bool _initialized = false;

  @override
  Set<AppPhase> get supportedPhases => {
        AppPhase.inGame_characterCreation,
        AppPhase.inGame_encounter,
        // 다른 페이즈에서도 동작 가능하도록
      };

  @override
  Set<Type> get handledEvents => {
        CharacterCreated, // 🆕 초기화 트리거
        EncounterEnded,
        SlotOpened,
      };

  @override
  Future<List<GEvent>> handle(GEvent event, GameVM vm) async {
    if (event is CharacterCreated) {
      // 🆕 초기화: xp_config.json 로드
      return await _handleCharacterCreated(event, vm);
    } else if (event is EncounterEnded) {
      return await _handleEncounterEnded(event, vm);
    } else if (event is SlotOpened) {
      return await _handleSlotOpened(event, vm);
    }
    return const [];
  }
  
  /// 🆕 캐릭터 생성 시 XP 시스템 초기화
  Future<List<GEvent>> _handleCharacterCreated(
    CharacterCreated event,
    GameVM vm,
  ) async {
    if (_initialized) {
      if (kDebugMode) {
        debugPrint('[XpModule] Already initialized, skipping');
      }
      return const [];
    }

    try {
      if (kDebugMode) {
        debugPrint('[XpModule] 🎬 Initializing XP system...');
      }

      // 1. xp_config.json 로드
      final jsonString = await rootBundle.loadString('assets/config/xp_config.json');
      final config = json.decode(jsonString) as Map<String, dynamic>;

      if (kDebugMode) {
        debugPrint('[XpModule] ✅ Loaded xp_config.json');
      }

      // 2. MilestoneService 설정
      _milestoneService.loadConfig(MilestoneConfig.fromJson(config));
      
      if (kDebugMode) {
        debugPrint('[XpModule] ✅ MilestoneService configured');
        debugPrint('[XpModule]    Chapter: ${_milestoneService.config.themeMilestones}');
        debugPrint('[XpModule]    Story: ${_milestoneService.config.storyMilestones}');
      }

      // 3. EncounterScheduler 설정
      final tracks = config['tracks'] as Map<String, dynamic>?;
      if (tracks != null) {
        final chapterTrack = tracks['chapter'] as Map<String, dynamic>?;
        final storyTrack = tracks['story'] as Map<String, dynamic>?;

        _scheduler.loadConfig(
          themeConfig: chapterTrack != null 
              ? ThemeTrackConfig.fromJson(chapterTrack) 
              : null,
          storyConfig: storyTrack != null 
              ? StoryTrackConfig.fromJson(storyTrack) 
              : null,
          startThemeKey: 'default', // 기본값, 나중에 인카운터 경로로 감지
        );

        if (kDebugMode) {
          debugPrint('[XpModule] ✅ EncounterScheduler configured');
        }
      }

      // 4. 초기화 완료
      _initialized = true;
      
      if (kDebugMode) {
        debugPrint('[XpModule] 🎉 XP system initialization complete!');
      }

      return const [];
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[XpModule] ❌ Initialization failed: $e');
        debugPrint('[XpModule] StackTrace: $stackTrace');
      }
      return [ErrorEvt('XP 시스템 초기화 실패: $e')];
    }
  }

  /// 인카운터 종료 처리
  Future<List<GEvent>> _handleEncounterEnded(
    EncounterEnded event,
    GameVM vm,
  ) async {
    if (kDebugMode) {
      debugPrint('[XpModule] Encounter ended: ${event.encounterId}');
    }

    // 🆕 반복 인카운터인지 확인
    final encounterPath = event.outcome['encounterPath'] as String?;
    
    // 🆕 시작 테마 자동 감지 (start 인카운터에서)
    if (encounterPath != null && encounterPath.contains('/start/')) {
      _detectAndSetStartTheme(encounterPath);
    }
    
    final isRepeatEncounter = _isRepeatEncounter(encounterPath);
    
    if (!isRepeatEncounter) {
      if (kDebugMode) {
        debugPrint('[XpModule] Not a repeat encounter ($encounterPath), skipping XP');
      }
      return const [];
    }

    if (kDebugMode) {
      debugPrint('[XpModule] Repeat encounter detected: $encounterPath');
    }

    // 1. XP 정산 (반복 인카운터만)
    final (prevXp, nowXp, gained) = _xpService.onEncounterResolved(
      event.encounterId,
      event.outcome,
    );

    if (kDebugMode) {
      debugPrint('[XpModule] XP: $prevXp → $nowXp (+$gained)');
    }

    // 2. 교차 마일스톤 계산
    final crossed = _milestoneService.computeCrossed(prevXp, nowXp);

    if (crossed.isEmpty) {
      if (kDebugMode) {
        debugPrint('[XpModule] No milestones crossed');
      }
      return const [];
    }

    // 3. 마일스톤 큐에 추가
    _milestoneService.enqueueAll(crossed);

    // 4. 마일스톤 도달 이벤트 발생 (로깅용)
    final milestoneEvents = crossed
        .map((m) => MilestoneReached(m.value, m.type.name))
        .toList();

    if (kDebugMode) {
      debugPrint('[XpModule] Crossed milestones: $crossed');
      debugPrint('[XpModule] Queue size: ${_milestoneService.queueSize}');
    }

    // 5. 터미널 마일스톤(100)이면 특별 처리
    if (_milestoneService.isTerminalPending) {
      if (kDebugMode) {
        debugPrint('[XpModule] Terminal milestone (100) pending!');
      }
      // 터미널 플래그가 설정되어 다른 인카운터 차단됨
    }

    return milestoneEvents;
  }

  /// 슬롯 열림 처리 (스케줄러와 연동)
  Future<List<GEvent>> _handleSlotOpened(
    SlotOpened event,
    GameVM vm,
  ) async {
    if (kDebugMode) {
      debugPrint('[XpModule] Slot opened - delegating to scheduler');
    }

    // XpModule은 스케줄링 자체를 하지 않고
    // 스케줄러가 별도 모듈로 동작하거나
    // EncounterController에서 직접 처리합니다
    
    return const [];
  }

  /// 🆕 반복 인카운터 판별 헬퍼
  /// 
  /// /random/ 경로에 있는 인카운터만 반복 인카운터로 판단
  bool _isRepeatEncounter(String? encounterPath) {
    if (encounterPath == null || encounterPath.isEmpty) {
      return false;
    }
    
    // assets/dialogue/random/ 경로면 반복 인카운터
    return encounterPath.contains('/random/');
  }
  
  /// 🆕 시작 테마 자동 감지 및 설정
  /// 
  /// start 인카운터 경로에서 테마 키 추출
  /// 예: assets/dialogue/start/start_knight.json → 'start_knight'
  void _detectAndSetStartTheme(String encounterPath) {
    try {
      // 파일명 추출 (확장자 제거)
      final fileName = encounterPath.split('/').last.replaceAll('.json', '');
      
      // start_knight, start_mage 등의 형식이면 그대로 사용
      if (fileName.startsWith('start_')) {
        _scheduler.setStartThemeKey(fileName);
        
        if (kDebugMode) {
          debugPrint('[XpModule] 🎭 Detected start theme: $fileName');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[XpModule] Failed to detect start theme: $e');
      }
    }
  }
}

