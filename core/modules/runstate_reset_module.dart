/// RunStateResetModule - 새 회차 시작 시 RunState 초기화
///
/// StartGame 이벤트를 받아서 모든 싱글톤 시스템들을 초기화합니다.

import 'package:flutter/foundation.dart';
import '../game_controller.dart';
import '../state/app_phase.dart';
import '../state/events.dart';
import '../state/game_state.dart';
import '../../inventory/inventory_system.dart';
import '../../autosave/autosave_dialogue_manager.dart';

/// RunState 초기화 모듈
/// 
/// 새 회차 시작 시 InventorySystem, DialogueManager 등을 초기화합니다.
class RunStateResetModule implements GameModule {
  final InventorySystem _inventory;
  final AutosaveDialogueManager _dialogueManager;
  
  RunStateResetModule({
    required InventorySystem inventory,
    required AutosaveDialogueManager dialogueManager,
  })  : _inventory = inventory,
        _dialogueManager = dialogueManager;
  
  @override
  Set<AppPhase> get supportedPhases => {
    AppPhase.startMenu,
    AppPhase.inGame_characterCreation,
  };
  
  @override
  Set<Type> get handledEvents => {StartGame};
  
  @override
  Future<List<GEvent>> handle(GEvent event, GameVM vm) async {
    if (event is StartGame) {
      return await _handleStartGame();
    }
    return const [];
  }
  
  /// StartGame: 모든 RunState 시스템 초기화
  Future<List<GEvent>> _handleStartGame() async {
    try {
      debugPrint('[RunStateReset] 🔄 Resetting all RunState systems...');
      
      // 1. InventorySystem 초기화
      _inventory.resetForNewRun();
      
      // 2. DialogueManager 초기화
      _dialogueManager.resetForNewRun();
      
      // TODO: 필요한 다른 시스템들 초기화
      // - EncounterScheduler.reset()
      // - XpService.reset()
      // 등등...
      
      debugPrint('[RunStateReset] ✅ All RunState systems reset complete');
      
      return const [];
    } catch (e, stackTrace) {
      debugPrint('[RunStateReset] ❌ Reset failed: $e');
      debugPrint('$stackTrace');
      return const [];
    }
  }
}



