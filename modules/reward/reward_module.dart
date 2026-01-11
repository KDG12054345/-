import '../../core/game_controller.dart';
import '../../core/state/app_phase.dart';
import '../../core/state/events.dart';
import '../../core/state/game_state.dart';

class RewardModule implements GameModule {
  @override
  Set<AppPhase> get supportedPhases => {AppPhase.inGame_reward};

  @override
  Set<Type> get handledEvents => {EnterReward, LoadEncounter, Next};

  @override
  Future<List<GEvent>> handle(GEvent event, GameVM vm) async {
    if (event is LoadEncounter) {
      // 보상 화면에서 승리 인카운터로 이동
      // Phase를 encounter로 변경하는 이벤트 반환
      print('[RewardModule] Loading victory encounter: ${event.encounterPath}');
      // EncounterModule이 처리하도록 그대로 전달
      return [event];
    } else if (event is Next) {
      // Next가 눌렸을 때 (victoryScenePath가 없는 경우)
      // 일반 인카운터로 복귀
      print('[RewardModule] Reward screen closed, returning to encounter');
      return [const SlotOpened()];  // 다음 슬롯 열기
    }
    
    // TODO: 실제 보상 로직 구현 (아이템 지급 등)
    return [];
  }
}









