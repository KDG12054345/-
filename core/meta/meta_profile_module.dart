/// MetaProfileModule - MetaProfile 관련 이벤트 처리
///
/// GameModule로 통합되어 메타 진행도를 관리합니다.

import 'package:flutter/foundation.dart';
import '../game_controller.dart';
import '../state/app_phase.dart';
import '../state/events.dart';
import '../state/game_state.dart';
import 'meta_profile.dart';
import 'meta_profile_system.dart';

/// MetaProfile 관리 모듈
class MetaProfileModule implements GameModule {
  final MetaProfileSystem _system;
  MetaProfile _profile;
  
  MetaProfileModule({MetaProfileSystem? system})
      : _system = system ?? MetaProfileSystem(),
        _profile = const MetaProfile();
  
  /// 현재 MetaProfile 가져오기
  MetaProfile get profile => _profile;
  
  /// MetaProfile 초기화 (앱 시작 시 호출)
  Future<void> initialize() async {
    _profile = await _system.load();
    debugPrint('[MetaProfileModule] ✅ Initialized: $_profile');
  }
  
  @override
  Set<AppPhase> get supportedPhases => {
    AppPhase.startMenu,
    AppPhase.inGame_characterCreation,
    AppPhase.inGame_encounter,
    AppPhase.inGame_combat,
    AppPhase.inGame_reward,
    AppPhase.inGame_gameOver,
  };
  
  @override
  Set<Type> get handledEvents => {
    StartGame,
    UnlockMetaFlag,
    EncounterEnded,
    ShowEnding,
  };
  
  @override
  Future<List<GEvent>> handle(GEvent event, GameVM vm) async {
    if (event is StartGame) {
      return await _handleStartGame();
    } else if (event is UnlockMetaFlag) {
      return await _handleUnlockMetaFlag(event);
    } else if (event is EncounterEnded) {
      return await _handleEncounterEnded(event);
    } else if (event is ShowEnding) {
      return await _handleShowEnding(event);
    }
    return const [];
  }
  
  /// StartGame: runCount 증가
  Future<List<GEvent>> _handleStartGame() async {
    try {
      _profile = _profile.startNewRun();
      await _system.save(_profile);
      debugPrint('[MetaProfileModule] 🎮 New run started: run #${_profile.runCount}');
      return const [];
    } catch (e) {
      debugPrint('[MetaProfileModule] ❌ Failed to start new run: $e');
      return const [];
    }
  }
  
  /// UnlockMetaFlag: 언락 플래그 추가
  Future<List<GEvent>> _handleUnlockMetaFlag(UnlockMetaFlag event) async {
    try {
      final oldFlags = _profile.unlockedFlags.length;
      _profile = _profile.addUnlockedFlag(event.flag);
      
      if (_profile.unlockedFlags.length > oldFlags) {
        await _system.save(_profile);
        debugPrint('[MetaProfileModule] 🔓 Unlocked: ${event.flag}');
        debugPrint('[MetaProfileModule] Total unlocked: ${_profile.unlockedFlags.length}');
      } else {
        debugPrint('[MetaProfileModule] ℹ️ Already unlocked: ${event.flag}');
      }
      
      return const [];
    } catch (e) {
      debugPrint('[MetaProfileModule] ❌ Failed to unlock flag: $e');
      return const [];
    }
  }
  
  /// EncounterEnded: 인카운터 본 횟수 증가
  Future<List<GEvent>> _handleEncounterEnded(EncounterEnded event) async {
    try {
      final encounterId = event.encounterId;
      if (encounterId == null || encounterId.isEmpty) {
        return const [];
      }
      
      _profile = _profile.incrementEncounterSeen(encounterId);
      await _system.save(_profile);
      
      final count = _profile.getEncounterSeenCount(encounterId);
      debugPrint('[MetaProfileModule] 📖 Encounter seen: $encounterId (count: $count)');
      
      return const [];
    } catch (e) {
      debugPrint('[MetaProfileModule] ❌ Failed to record encounter: $e');
      return const [];
    }
  }
  
  /// ShowEnding: 엔딩 추가
  Future<List<GEvent>> _handleShowEnding(ShowEnding event) async {
    try {
      final endingId = event.endingId;
      if (endingId == null || endingId.isEmpty) {
        return const [];
      }
      
      final oldEndings = _profile.seenEndings.length;
      _profile = _profile.addSeenEnding(endingId);
      
      if (_profile.seenEndings.length > oldEndings) {
        await _system.save(_profile);
        debugPrint('[MetaProfileModule] 🎬 New ending seen: $endingId');
        debugPrint('[MetaProfileModule] Total endings: ${_profile.seenEndings.length}');
      } else {
        debugPrint('[MetaProfileModule] ℹ️ Ending already seen: $endingId');
      }
      
      return const [];
    } catch (e) {
      debugPrint('[MetaProfileModule] ❌ Failed to record ending: $e');
      return const [];
    }
  }
  
  /// 특정 플래그가 언락되어 있는지 확인
  bool hasFlag(String flag) => _profile.hasFlag(flag);
  
  /// 필터링용: requiredFlags가 모두 만족되는지 확인
  bool checkRequiredFlags(List<String>? requiredFlags) {
    if (requiredFlags == null || requiredFlags.isEmpty) {
      return true; // 요구사항 없으면 통과
    }
    
    return requiredFlags.every((flag) => _profile.hasFlag(flag));
  }
}

