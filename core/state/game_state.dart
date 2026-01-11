import 'app_phase.dart';
import '../character/character_models.dart';
import 'combat_state.dart';
import '../../inventory/inventory_system.dart';

class ChoiceVM {
  final String id; 
  final String text; 
  final bool enabled; 
  final String? why;
  const ChoiceVM(this.id, this.text, {this.enabled=true, this.why});
}

class GameVM {
  final AppPhase phase; 
  final String? text; 
  final List<ChoiceVM> choices;
  final bool loading; 
  final String? error; 
  final String? debug;
  final Player? player;  // 플레이어 정보 추가
  final CombatState? combat;  // 전투 상태 추가
  final InventorySystem? playerInventory;  // 플레이어 인벤토리 추가
  final String? victoryScenePath;  // 전투 승리 후 이동할 인카운터 경로
  final String? defeatScenePath;   // 전투 패배 후 이동할 인카운터 경로
  
  const GameVM({
    this.phase=AppPhase.startMenu,
    this.text,
    this.choices=const [],
    this.loading=false,
    this.error,
    this.debug,
    this.player,  // 추가
    this.combat,  // 추가
    this.playerInventory,  // 추가
    this.victoryScenePath,  // 추가
    this.defeatScenePath,   // 추가
  });
  
  GameVM copyWith({
    AppPhase? phase,
    String? text,
    List<ChoiceVM>? choices,
    bool? loading,
    String? error,
    String? debug,
    Player? player,  // 추가
    CombatState? combat,  // 추가
    InventorySystem? playerInventory,  // 추가
    String? victoryScenePath,  // 추가
    String? defeatScenePath,   // 추가
  }) =>
    GameVM(
      phase: phase??this.phase, 
      text: text??this.text, 
      choices: choices??this.choices,
      loading: loading??this.loading, 
      error: error??this.error, 
      debug: debug??this.debug,
      player: player??this.player,  // 추가
      combat: combat??this.combat,  // 추가
      playerInventory: playerInventory??this.playerInventory,  // 추가
      victoryScenePath: victoryScenePath??this.victoryScenePath,  // 추가
      defeatScenePath: defeatScenePath??this.defeatScenePath,     // 추가
    );
}






