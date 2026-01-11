import '../inventory/inventory_item.dart';

/// 보상 아이템 정의
class RewardItemDefinition {
  final String id;
  final String name;
  final String description;
  final int baseWidth;
  final int baseHeight;
  final Map<String, dynamic> properties; // footprint, rarity, type 등

  const RewardItemDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.baseWidth,
    required this.baseHeight,
    this.properties = const {},
  });
}

/// 보상 아이템을 InventoryItem으로 변환하는 팩토리
class RewardItemFactory {
  /// RewardItemDefinition을 InventoryItem으로 변환
  static InventoryItem createInventoryItemFromReward(RewardItemDefinition def) {
    // footprint가 없으면 기본 사각형 마스크 생성
    final footprint = def.properties['footprint'] as List<List<int>>?;
    final finalFootprint = footprint ?? _createRectMask(def.baseWidth, def.baseHeight);

    return InventoryItem(
      id: def.id,
      name: def.name,
      description: def.description,
      baseWidth: def.baseWidth,
      baseHeight: def.baseHeight,
      iconPath: def.properties['iconPath'] as String? ?? '',
      properties: {
        ...def.properties,
        'footprint': finalFootprint,
        // rotation이 없으면 0으로 설정
        'rotation': def.properties['rotation'] ?? 0,
      },
      position: null, // 보상 아이템은 아직 배치되지 않음
      // rotation은 0/90/180/270 또는 0..3(step)로 올 수 있으므로,
      // InventoryItem은 rotationDegrees SSOT로 수용한다.
      rotationDegrees: (def.properties['rotation'] is int) ? def.properties['rotation'] as int : 0,
      isRotated: false, // legacy compatibility
    );
  }

  /// 기본 사각형 마스크 생성
  static List<List<int>> _createRectMask(int width, int height) {
    return List.generate(
      height,
      (_) => List.filled(width, 1, growable: false),
      growable: false,
    );
  }

  /// 다양한 모양의 footprint 패턴 생성
  static List<List<int>> createLShapeFootprint() {
    // ㄱ 모양 (L자형)
    return [
      [1, 0],
      [1, 1],
    ];
  }

  static List<List<int>> createReverseLShapeFootprint() {
    // ㄴ 모양 (역 L자형)
    return [
      [0, 1],
      [1, 1],
    ];
  }

  static List<List<int>> createTShapeFootprint() {
    // ㅗ 모양 (T자형)
    return [
      [1, 1, 1],
      [0, 1, 0],
    ];
  }

  static List<List<int>> createIShapeFootprint() {
    // ㅣ 모양 (직선형)
    return [
      [1],
      [1],
      [1],
    ];
  }

  static List<List<int>> createSquareFootprint(int size) {
    // ㅁ 모양 (정사각형)
    return _createRectMask(size, size);
  }
}


















