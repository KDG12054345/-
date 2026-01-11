import 'combat_entity.dart';
import 'health_system.dart';

/// 전투 중 조건부 최대체력 증가 시스템
class CombatConditionManager {
  final CombatEntity entity;
  final Map<String, bool> _triggeredConditions = {}; // 이미 발동된 조건들
  
  CombatConditionManager(this.entity);
  
  /// 킬 카운트에 따른 체력 증가
  void checkKillStreak(int killCount) {
    final milestones = [5, 10, 20, 50]; // 킬 마일스톤
    
    for (final milestone in milestones) {
      final conditionKey = 'kill_streak_$milestone';
      
      if (killCount >= milestone && !_triggeredConditions.containsKey(conditionKey)) {
        _triggeredConditions[conditionKey] = true;
        
        final bonus = milestone * 2; // 킬 수 * 2만큼 체력 증가
        if (entity is HealthSystem) {
          (entity as HealthSystem).increaseMaxHealth(
            bonus,
            '킬 스트릭 $milestone',
            data: {'killCount': killCount, 'milestone': milestone},
          );
        }
      }
    }
  }
  
  /// 체력 비율에 따른 각성 효과
  void checkBerserkMode() {
    final healthRatio = entity.currentHealth / entity.maxHealth;
    const threshold = 0.3; // 30% 이하
    const conditionKey = 'berserk_mode';
    
    if (healthRatio <= threshold && !_triggeredConditions.containsKey(conditionKey)) {
      _triggeredConditions[conditionKey] = true;
      
      if (entity is HealthSystem) {
        (entity as HealthSystem).increaseMaxHealth(
          50,
          '각성 모드',
          duration: Duration(minutes: 2), // 2분간 지속
          data: {'healthRatio': healthRatio, 'trigger': 'low_health'},
        );
      }
    }
  }
  
  /// 전투 시간에 따른 아드레날린 효과
  void checkAdrenalineRush(Duration combatTime) {
    final minutes = combatTime.inMinutes;
    final intervals = [5, 10, 15]; // 5분, 10분, 15분
    
    for (final interval in intervals) {
      final conditionKey = 'adrenaline_$interval';
      
      if (minutes >= interval && !_triggeredConditions.containsKey(conditionKey)) {
        _triggeredConditions[conditionKey] = true;
        
        if (entity is HealthSystem) {
          (entity as HealthSystem).increaseMaxHealth(
            20,
            '아드레날린 러시',
            duration: Duration(minutes: 5), // 5분간 지속
            data: {'combatTime': combatTime, 'interval': interval},
          );
        }
      }
    }
  }
  
  /// 특정 아이템 사용 시 체력 증가
  void onItemUsed(String itemId) {
    final healthPotions = {
      'life_essence_potion': 30,
      'vitality_elixir': 50,
      'dragon_blood_serum': 100,
    };
    
    final bonus = healthPotions[itemId];
    if (bonus != null) {
      if (entity is HealthSystem) {
        (entity as HealthSystem).increaseMaxHealth(
          bonus,
          '생명력 강화 물약',
          data: {'itemId': itemId, 'bonus': bonus},
        );
      }
    }
  }
  
  /// 시너지 효과 발동 시 체력 증가
  void onSynergyActivated(String synergyName) {
    final synergyBonuses = {
      'guardian_set': 40,      // 수호자 세트
      'berserker_combo': 60,   // 광전사 조합
      'life_mastery': 80,      // 생명 숙련
    };
    
    final bonus = synergyBonuses[synergyName];
    if (bonus != null) {
      if (entity is HealthSystem) {
        (entity as HealthSystem).increaseMaxHealth(
          bonus,
          '시너지: $synergyName',
          duration: Duration(hours: 1), // 1시간 지속
          data: {'synergyName': synergyName, 'bonus': bonus},
        );
      }
    }
  }
  
  /// 조건 초기화 (새로운 전투 시작 시)
  void resetConditions() {
    _triggeredConditions.clear();
  }
} 