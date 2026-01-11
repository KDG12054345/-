import '../state/game_state.dart';
import 'character_models.dart';
import '../../event_system.dart' as legacy;
import '../game_controller.dart';

/// Player 객체와 GameVM 동기화를 담당하는 클래스
class CharacterStateSynchronizer {
  final GameController _controller;

  CharacterStateSynchronizer(this._controller);

  /// Player 능력치를 GameVM에 동기화
  void syncPlayerToGameState(Player player) {
    // TODO: 새로운 이벤트 시스템으로 마이그레이션
    // 현재는 레거시 EventSystem 사용
    // 향후: _controller.dispatch(UpdatePlayerStats(player)) 형태로 변경
    
    final stats = <String, int>{
      'strength': player.strength,
      'agility': player.agility,
      'intelligence': player.intelligence,
      'charisma': player.charisma,
      'vitality': player.vitality,
      'sanity': player.sanity,
      'maxVitality': player.maxVitality,
      'maxSanity': player.maxSanity,
    };

    // 레거시 시스템 사용 (마이그레이션 필요)
    // eventSystem.handleEvent(GameEvent(...))
  }

  /// GameVM에서 Player 객체 생성
  Player createPlayerFromGameState() {
    // GameVM에 이미 player 객체가 있으면 반환, 없으면 기본값으로 생성
    final existingPlayer = _controller.vm.player;
    
    if (existingPlayer != null) {
      return existingPlayer;
    }
    
    // 기본 플레이어 생성
    return Player(
      strength: 4,
      agility: 4,
      intelligence: 4,
      charisma: 4,
      vitality: 4,
      sanity: 4,
      maxVitality: 4,
      maxSanity: 4,
      traits: [], // 특성은 별도 처리
    );
  }
}







