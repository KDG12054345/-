// lib/data/item_data.dart

class Item {
  final String id;
  final String type;
  final String grade;
  final int dropWeight;
  final I18n i18n;
  final Stats stats;
  final List<Effect> effects; // 변경: List<String> -> List<Effect>
  final Combine? combine;

  Item({
    required this.id,
    required this.type,
    required this.grade,
    required this.dropWeight,
    required this.i18n,
    required this.stats,
    this.effects = const [],
    this.combine,
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json['id'] as String,
        type: json['type'] as String,
        grade: json['grade'] as String,
        dropWeight: json['drop_weight'] as int,
        i18n: I18n.fromJson(json['i18n'] as Map<String, dynamic>),
        stats: Stats.fromJson(json['stats'] as Map<String, dynamic>),
        effects: (json['effects'] as List<dynamic>?)
                ?.map((e) => Effect.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        combine: json['combine'] != null
            ? Combine.fromJson(json['combine'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'grade': grade,
        'drop_weight': dropWeight,
        'i18n': i18n.toJson(),
        'stats': stats.toJson(),
        'effects': effects.map((e) => e.toJson()).toList(),
        if (combine != null) 'combine': combine!.toJson(),
      };
}

class I18n {
  final Map<String, String> name;

  I18n({required this.name});

  factory I18n.fromJson(Map<String, dynamic> json) => I18n(
        name: Map<String, String>.from(json['name'] as Map),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
      };
}

class Stats {
  final String damage;
  final String? accuracy;
  final double? cooldown;
  final String? critChance;
  final String? critMultiplier;
  final double? staminaCost;

  Stats({
    required this.damage,
    this.accuracy,
    this.cooldown,
    this.critChance,
    this.critMultiplier,
    this.staminaCost,
  });

  factory Stats.fromJson(Map<String, dynamic> json) => Stats(
        damage: json['damage'] as String,
        accuracy: json['accuracy'] as String?,
        cooldown: (json['cooldown'] is num) ? (json['cooldown'] as num).toDouble() : null,
        critChance: json['crit_chance'] as String?,
        critMultiplier: json['crit_multiplier'] as String?,
        staminaCost: (json['stamina_cost'] is num) ? (json['stamina_cost'] as num).toDouble() : null,
      );

  Map<String, dynamic> toJson() => {
        'damage': damage,
        if (accuracy != null) 'accuracy': accuracy,
        if (cooldown != null) 'cooldown': cooldown,
        if (critChance != null) 'crit_chance': critChance,
        if (critMultiplier != null) 'crit_multiplier': critMultiplier,
        if (staminaCost != null) 'stamina_cost': staminaCost,
      };
}

class Combine {
  final List<String> recipe;
  final String result;

  Combine({
    required this.recipe,
    required this.result,
  });

  factory Combine.fromJson(Map<String, dynamic> json) => Combine(
        recipe: (json['recipe'] as List<dynamic>).map((e) => e as String).toList(),
        result: json['result'] as String,
      );

  Map<String, dynamic> toJson() => {
        'recipe': recipe,
        'result': result,
      };
}

class Effect {
  final String type; // 예: 'burn', 'poison', 'heal'
  final int stack;   // 예: 2 (2스택)
  final String? target; // 'self', 'enemy' 등
  final String? costType; // 예: 'mana'
  final int? costAmount;  // 예: 2

  Effect({
    required this.type,
    this.stack = 1,
    this.target,
    this.costType,
    this.costAmount,
  });

  factory Effect.fromJson(Map<String, dynamic> json) => Effect(
        type: json['type'] as String,
        stack: json['stack'] as int? ?? 1,
        target: json['target'] as String?,
        costType: json['cost_type'] as String?,
        costAmount: json['cost_amount'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        if (stack != 1) 'stack': stack,
        if (target != null) 'target': target,
        if (costType != null) 'cost_type': costType,
        if (costAmount != null) 'cost_amount': costAmount,
      };
} 