import '../../combat/item.dart';
import '../../combat/stats.dart';

/// 아이템의 불변 속성 (게임 데이터)
class ItemDefinition {
  final String id;
  final String name;
  final String description;
  final String iconPath;
  final int baseWidth;
  final int baseHeight;
  final Map<String, dynamic> baseProperties;
  final ItemType type;
  final CombatStats baseStats;
  
  const ItemDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.iconPath,
    required this.baseWidth,
    required this.baseHeight,
    required this.type,
    required this.baseStats,
    this.baseProperties = const {},
  });
}
