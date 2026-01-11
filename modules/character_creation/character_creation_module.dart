import '../../core/game_controller.dart';
import '../../core/state/app_phase.dart';
import '../../core/state/events.dart';
import '../../core/state/game_state.dart';
import '../../core/character/character_system.dart';
import '../../core/character/character_effects.dart';

class CharacterCreationModule implements GameModule {
  final CharacterCreationService _creationService;
  final CharacterEffectsSystem _effectsSystem;

  CharacterCreationModule()
      : _creationService = CharacterCreationService(
          traitSystem: InnateTraitSystem(traitPool: defaultTraitPool),
        ),
        _effectsSystem = CharacterEffectsSystem();

  @override
  Set<AppPhase> get supportedPhases => {AppPhase.inGame_characterCreation};

  @override
  Set<Type> get handledEvents => {StartGame};

  @override
  Future<List<GEvent>> handle(GEvent event, GameVM vm) async {
    if (event is StartGame) {
      // 캐릭터 생성
      final player = _creationService.createNewCharacter();
      
      // 특성 효과 적용 (향후 구현)
      // _effectsSystem.applyStartingEffects(player, inventory, allBagItems);
      
      return [CharacterCreated(player)];
    }
    return [];
  }
}