import '../../core/game_controller.dart';
import '../../core/state/app_phase.dart';
import '../../core/state/events.dart';
import '../../core/state/game_state.dart';
import 'encounter_controller.dart';

class EncounterModule implements GameModule {
  final EncounterController _controller = EncounterController();
  GameController? _gameController;

  @override
  Set<AppPhase> get supportedPhases => {AppPhase.inGame_encounter};

  @override
  Set<Type> get handledEvents => {CharacterCreated, Next, SlotOpened, LoadEncounter, Choose}; // Choose 추가
  
  @override
  void setController(GameController controller) {
    _gameController = controller;
    _controller.setGameController(controller);
  }

  @override
  Future<List<GEvent>> handle(GEvent event, GameVM vm) async {
    // 패배 인카운터 경로가 있으면 해당 인카운터 로드
    if (event is Next && vm.defeatScenePath != null) {
      print('[EncounterModule] Defeat scene detected, loading: ${vm.defeatScenePath}');
      final result = await _controller.handle(LoadEncounter(vm.defeatScenePath!), vm);
      // defeatScenePath 초기화 - 다음 Next 때는 일반 처리
      // (GameVM의 defeatScenePath를 null로 설정하는 것은 reducer에서 처리됨)
      return result;
    }
    
    return _controller.handle(event, vm);
  }
}
