/// 스킬 체크 설정
class SkillCheckConfig {
  final String stat;
  final int baseStat;
  final double baseChance;
  final double perStatBonus;
  final SkillCheckClamp clamp;
  final SkillCheckVisibility visibility;

  const SkillCheckConfig({
    required this.stat,
    this.baseStat = 5,
    this.baseChance = 45.0,
    this.perStatBonus = 5.0,
    this.clamp = const SkillCheckClamp(),
    this.visibility = SkillCheckVisibility.estimate,
  });

  factory SkillCheckConfig.fromJson(Map<String, dynamic> json) {
    return SkillCheckConfig(
      stat: json['stat'] as String,
      baseStat: json['baseStat'] as int? ?? 5,
      baseChance: (json['baseChance'] as num?)?.toDouble() ?? 45.0,
      perStatBonus: (json['perStatBonus'] as num?)?.toDouble() ?? 5.0,
      clamp: json['clamp'] != null 
          ? SkillCheckClamp.fromJson(json['clamp'] as Map<String, dynamic>)
          : const SkillCheckClamp(),
      visibility: SkillCheckVisibility.fromString(json['visibility'] as String? ?? 'estimate'),
    );
  }
}

/// 확률 상하한 설정
class SkillCheckClamp {
  final double min;
  final double max;

  const SkillCheckClamp({
    this.min = 10.0,
    this.max = 90.0,
  });

  factory SkillCheckClamp.fromJson(Map<String, dynamic> json) {
    return SkillCheckClamp(
      min: (json['min'] as num?)?.toDouble() ?? 10.0,
      max: (json['max'] as num?)?.toDouble() ?? 90.0,
    );
  }
}

/// 확률 표시 방식
enum SkillCheckVisibility {
  hidden,
  estimate, 
  exact;

  static SkillCheckVisibility fromString(String value) {
    switch (value.toLowerCase()) {
      case 'hidden': return SkillCheckVisibility.hidden;
      case 'estimate': return SkillCheckVisibility.estimate;
      case 'exact': return SkillCheckVisibility.exact;
      default: return SkillCheckVisibility.estimate;
    }
  }
}

/// 선택지 결과 설정
class ChoiceOutcome {
  final String? goto;
  final List<Map<String, dynamic>>? events;

  const ChoiceOutcome({
    this.goto,
    this.events,
  });

  factory ChoiceOutcome.fromJson(Map<String, dynamic> json) {
    return ChoiceOutcome(
      goto: json['goto'] as String?,
      events: json['events'] as List<Map<String, dynamic>>?,
    );
  }
}

/// 확장된 선택지 클래스
class EnhancedChoice {
  final String id;
  final String text;
  final Map<String, dynamic> conditions;
  final SkillCheckConfig? skillCheck;
  final ChoiceOutcome? onSuccess;
  final ChoiceOutcome? onFailure;
  final bool isEnabled;
  final double? displayChance;
  final String? displayTier;

  const EnhancedChoice({
    required this.id,
    required this.text,
    this.conditions = const {},
    this.skillCheck,
    this.onSuccess,
    this.onFailure,
    this.isEnabled = true,
    this.displayChance,
    this.displayTier,
  });

  factory EnhancedChoice.fromJson(Map<String, dynamic> json) {
    return EnhancedChoice(
      id: json['id'] as String,
      text: json['text'] as String,
      conditions: json['conditions'] as Map<String, dynamic>? ?? {},
      skillCheck: json['skillCheck'] != null 
          ? SkillCheckConfig.fromJson(json['skillCheck'] as Map<String, dynamic>)
          : null,
      onSuccess: json['onSuccess'] != null
          ? ChoiceOutcome.fromJson(json['onSuccess'] as Map<String, dynamic>)
          : null,
      onFailure: json['onFailure'] != null
          ? ChoiceOutcome.fromJson(json['onFailure'] as Map<String, dynamic>)
          : null,
    );
  }

  /// 표시 정보가 추가된 새 인스턴스 생성
  EnhancedChoice withDisplayInfo({
    required bool isEnabled,
    double? displayChance,
    String? displayTier,
  }) {
    return EnhancedChoice(
      id: id,
      text: text,
      conditions: conditions,
      skillCheck: skillCheck,
      onSuccess: onSuccess,
      onFailure: onFailure,
      isEnabled: isEnabled,
      displayChance: displayChance,
      displayTier: displayTier,
    );
  }
}
