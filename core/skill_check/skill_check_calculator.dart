import 'dart:math';
import 'skill_check_models.dart';
import '../character/character_models.dart';

/// 전역 스킬 체크 규칙
class GlobalSkillCheckRules {
  final Map<String, double> statDefaults;
  final SkillCheckConfig defaultConfig;
  final Map<String, SkillCheckConfig> statOverrides;

  const GlobalSkillCheckRules({
    this.statDefaults = const {
      'strength': 45.0,
      'agility': 45.0, 
      'intelligence': 45.0,
      'charisma': 40.0,
    },
    this.defaultConfig = const SkillCheckConfig(
      stat: '',
      baseStat: 5,
      baseChance: 45.0,
      perStatBonus: 5.0,
    ),
    this.statOverrides = const {},
  });

  factory GlobalSkillCheckRules.fromJson(Map<String, dynamic> json) {
    final defaults = json['choice_success_rules']?['default'] as Map<String, dynamic>?;
    final overrides = json['choice_success_rules']?['overrides'] as Map<String, dynamic>?;
    
    return GlobalSkillCheckRules(
      statDefaults: Map<String, double>.from(json['stat_defaults'] ?? {}),
      defaultConfig: defaults != null 
          ? SkillCheckConfig.fromJson(defaults)
          : const SkillCheckConfig(stat: ''),
      statOverrides: overrides?.map((key, value) => 
          MapEntry(key, SkillCheckConfig.fromJson(value as Map<String, dynamic>))) ?? {},
    );
  }
}

/// 스킬 체크 계산 및 판정을 담당하는 클래스
class SkillCheckCalculator {
  final GlobalSkillCheckRules rules;
  final Random _random;

  SkillCheckCalculator({
    this.rules = const GlobalSkillCheckRules(),
    Random? random,
  }) : _random = random ?? Random();

  /// Player 객체에서 능력치 맵 추출
  Map<String, int> _getPlayerStats(Player player) {
    return {
      'strength': player.strength,
      'agility': player.agility,
      'intelligence': player.intelligence,
      'charisma': player.charisma,
      'vitality': player.vitality,
      'sanity': player.sanity,
    };
  }

  /// 성공 확률 계산 (Player 객체 사용)
  double calculateSuccessRateFromPlayer(SkillCheckConfig config, Player player) {
    final playerStats = _getPlayerStats(player);
    return calculateSuccessRate(config, playerStats);
  }

  /// 성공 확률 계산 (기존 방식 유지)
  double calculateSuccessRate(SkillCheckConfig config, Map<String, int> playerStats) {
    final playerStat = playerStats[config.stat] ?? config.baseStat;
    
    // 스탯별 오버라이드 적용
    final effectiveConfig = _applyOverrides(config);
    
    // 기본 공식: baseChance + (playerStat - baseStat) * perStatBonus
    double chance = effectiveConfig.baseChance + 
                   (playerStat - effectiveConfig.baseStat) * effectiveConfig.perStatBonus;
    
    // 클램프 적용
    chance = chance.clamp(effectiveConfig.clamp.min, effectiveConfig.clamp.max);
    
    return chance;
  }

  /// 표시용 확률 정보 생성 (Player 객체 사용)
  String? getDisplayChanceFromPlayer(SkillCheckConfig config, Player player) {
    final playerStats = _getPlayerStats(player);
    return getDisplayChance(config, playerStats);
  }

  /// 표시용 확률 정보 생성 (기존 방식 유지)
  String? getDisplayChance(SkillCheckConfig config, Map<String, int> playerStats) {
    switch (config.visibility) {
      case SkillCheckVisibility.hidden:
        return null;
        
      case SkillCheckVisibility.exact:
        final chance = calculateSuccessRate(config, playerStats);
        return '${chance.round()}%';
        
      case SkillCheckVisibility.estimate:
        final chance = calculateSuccessRate(config, playerStats);
        return _getChanceTier(chance);
    }
  }

  /// 확률 등급 변환
  String _getChanceTier(double chance) {
    if (chance < 25) return '매우 낮음';
    if (chance < 40) return '낮음';
    if (chance < 60) return '보통';
    if (chance < 75) return '높음';
    return '매우 높음';
  }

  /// 실제 성공/실패 판정 (Player 객체 사용)
  bool rollForSuccessFromPlayer(SkillCheckConfig config, Player player) {
    final playerStats = _getPlayerStats(player);
    return rollForSuccess(config, playerStats);
  }

  /// 실제 성공/실패 판정 (기존 방식 유지)
  bool rollForSuccess(SkillCheckConfig config, Map<String, int> playerStats) {
    final chance = calculateSuccessRate(config, playerStats);
    final roll = _random.nextDouble() * 100;
    return roll < chance;
  }

  /// 스탯별 오버라이드 적용
  SkillCheckConfig _applyOverrides(SkillCheckConfig config) {
    final override = rules.statOverrides[config.stat];
    if (override == null) return config;
    
    return SkillCheckConfig(
      stat: config.stat,
      baseStat: override.baseStat != 5 ? override.baseStat : config.baseStat,
      baseChance: override.baseChance != 45.0 ? override.baseChance : config.baseChance,
      perStatBonus: override.perStatBonus != 5.0 ? override.perStatBonus : config.perStatBonus,
      clamp: override.clamp.min != 10.0 || override.clamp.max != 90.0 ? override.clamp : config.clamp,
      visibility: config.visibility,
    );
  }

  /// 텔레메트리용 로그 데이터 생성 (Player 객체 사용)
  Map<String, dynamic> createTelemetryLogFromPlayer({
    required String choiceId,
    required SkillCheckConfig config,
    required Player player,
    required bool outcome,
  }) {
    final playerStats = _getPlayerStats(player);
    return createTelemetryLog(
      choiceId: choiceId,
      config: config,
      playerStats: playerStats,
      outcome: outcome,
    );
  }

  /// 텔레메트리용 로그 데이터 생성 (기존 방식 유지)
  Map<String, dynamic> createTelemetryLog({
    required String choiceId,
    required SkillCheckConfig config,
    required Map<String, int> playerStats,
    required bool outcome,
  }) {
    final playerStat = playerStats[config.stat] ?? config.baseStat;
    final chance = calculateSuccessRate(config, playerStats);
    
    return {
      'choice_id': choiceId,
      'stat_type': config.stat,
      'player_stat': playerStat,
      'calculated_chance': chance,
      'outcome': outcome ? 'success' : 'failure',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}







