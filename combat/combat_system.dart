import 'dart:async';
import 'combat_entity.dart';

class CombatSystem {
  final CombatEntity player;
  final CombatEntity enemy;
  
  Timer? _combatTimer;
  Timer? _overtimeTimer;
  int _elapsedSeconds = 0;
  bool _isActive = false;

  CombatSystem({
    required this.player,
    required this.enemy,
  });

  bool get isActive => _isActive;
  int get elapsedSeconds => _elapsedSeconds;

  void start() {
    if (_isActive) return;
    _isActive = true;
    _elapsedSeconds = 0;

    // 매 초마다 전투 상태 업데이트
    _combatTimer = Timer.periodic(Duration(seconds: 1), _updateCombat);

    // 1분 30초 후 지속 피해 시작
    _overtimeTimer = Timer(Duration(seconds: 90), _startOvertime);
  }

  void stop() {
    _isActive = false;
    _combatTimer?.cancel();
    _overtimeTimer?.cancel();
    player.dispose();
    enemy.dispose();
  }

  void _updateCombat(Timer timer) {
    if (!_isActive || player.isDead || enemy.isDead) {
      stop();
      return;
    }

    _elapsedSeconds++;

    // 아이템 자동 사용 로직
    for (var item in player.items) {
      player.useItem(item);
    }
    for (var item in enemy.items) {
      enemy.useItem(item);
    }
  }

  void _startOvertime() {
    if (!_isActive) return;

    Timer.periodic(Duration(seconds: 1), (timer) {
      if (!_isActive) {
        timer.cancel();
        return;
      }

      final overtimeDamage = _elapsedSeconds - 90;
      if (overtimeDamage > 0) {
        player.takeDamage(overtimeDamage);
        enemy.takeDamage(overtimeDamage);
      }
    });
  }
} 