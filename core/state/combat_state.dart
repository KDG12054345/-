import '../../combat/character.dart';

/// 전투 상태 정보
class CombatState {
  final Character? player;
  final Character? enemy;
  final bool isActive;
  final int elapsedSeconds;
  final String? encounterTitle;
  
  const CombatState({
    this.player,
    this.enemy,
    this.isActive = false,
    this.elapsedSeconds = 0,
    this.encounterTitle,
  });
  
  CombatState copyWith({
    Character? player,
    Character? enemy,
    bool? isActive,
    int? elapsedSeconds,
    String? encounterTitle,
  }) {
    return CombatState(
      player: player ?? this.player,
      enemy: enemy ?? this.enemy,
      isActive: isActive ?? this.isActive,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      encounterTitle: encounterTitle ?? this.encounterTitle,
    );
  }
  
  bool get isPlayerAlive => player != null && !player!.isDead;
  bool get isEnemyAlive => enemy != null && !enemy!.isDead;
  bool get isCombatOver => !isPlayerAlive || !isEnemyAlive;
  bool get playerWon => isPlayerAlive && !isEnemyAlive;
  
  @override
  String toString() => 'CombatState(active: $isActive, elapsed: $elapsedSeconds, playerAlive: $isPlayerAlive, enemyAlive: $isEnemyAlive)';
}

