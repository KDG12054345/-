import 'vector2_int.dart';
import 'footprint_rotation_cache.dart';
import '../data/inventory_item_weight_units.dart';
import '../data/item_rarity.dart';
import '../data/item_type.dart';

class InventoryItem {
  final String id;
  final String name;
  final String description;
  final int baseWidth;        // 기본 너비
  final int baseHeight;       // 기본 높이
  final String iconPath;      // 아이템 아이콘 경로
  final Map<String, dynamic> properties; // 확장 가능한 속성들
  
  /// 회전 상태 SSOT: 0/90/180/270 (clockwise)
  /// - 외부에서 임의값을 넣어도 4방향으로 정규화됩니다.
  int rotationDegrees;

  /// (호환용) 기존 bool 회전 API
  /// - true면 90도로 맞춤, false면 0도로 맞춤
  /// - 180/270을 표현할 수 없으므로, 새 코드에서는 rotationDegrees/currentRotation 사용 권장
  bool get isRotated => rotationDegrees == 90 || rotationDegrees == 270;
  set isRotated(bool v) {
    rotationDegrees = v ? 90 : 0;
  }

  Vector2Int? position;       // 인벤토리 내 위치 (null이면 배치되지 않음)
  
  InventoryItem({
    required this.id,
    required this.name,
    required this.description,
    required this.baseWidth,
    required this.baseHeight,
    required this.iconPath,
    int rotationDegrees = 0,
    bool isRotated = false,
    this.position,
    this.properties = const {},
  }) : rotationDegrees = _normalizeRotation(rotationDegrees != 0 ? rotationDegrees : (isRotated ? 90 : 0));

  static int _normalizeRotation(int rotationDegrees) {
    final r = ((rotationDegrees % 360) + 360) % 360;
    if (r == 0 || r == 90 || r == 180 || r == 270) return r;
    // Snap to nearest right angle
    if (r < 45) return 0;
    if (r < 135) return 90;
    if (r < 225) return 180;
    return 270;
  }
  
  /// 현재 회전 상태를 고려한 실제 너비
  int get currentWidth => (currentRotation == 90 || currentRotation == 270) ? baseHeight : baseWidth;
  
  /// 현재 회전 상태를 고려한 실제 높이  
  int get currentHeight => (currentRotation == 90 || currentRotation == 270) ? baseWidth : baseHeight;
  
  /// 현재 회전 각도 (0, 90, 180, 270)
  int get currentRotation => _normalizeRotation(rotationDegrees);
  
  // ═══════════════════════════════════════════════════════════════════════════
  // 가격 및 무게 메타데이터
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// 구입 가격 (properties['buyPrice']에서 읽음, 없으면 0)
  int get buyPrice {
    final price = properties['buyPrice'];
    if (price is int) return price;
    if (price is num) return price.toInt();
    return 0;
  }
  
  /// 판매 가격 (구입 가격의 절반)
  int get sellPrice => buyPrice ~/ 2;
  
  /// 아이템 무게 units (0.5 단위 = 1 unit)
  /// 
  /// ## 해석 우선순위
  /// 1. `properties['weightUnits']` - JSON에 정의된 값 (권장)
  /// 2. `properties['weight']` - 호환용 (사용 시 경고)
  /// 3. `kInventoryItemWeightUnitsById[id]` - 레거시 Dart 맵
  /// 4. 0 - 기본값 (dev/profile 빌드에서 경고)
  /// 
  /// 예: 2 units = 1.0 weight
  int get weightUnits => resolveWeightUnits(id, properties);
  
  /// 아이템 무게 (실수, 0.5 단위)
  /// InventorySystem.currentWeight와 동일한 계산 방식
  double get weight => weightUnits / 2.0;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // 희귀도 (Rarity)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// 아이템 희귀도 (정규화된 enum)
  ///
  /// ## 정규화 규칙
  /// - 대소문자 무시: 'epic', 'EPIC', 'Epic' 모두 [ItemRarity.epic]
  /// - 공백 trim: '  rare  ' → [ItemRarity.rare]
  /// - 누락/null: [ItemRarity.common] (기본값)
  /// - 잘못된 값: [ItemRarity.common] (dev 빌드에서 경고 로그)
  ///
  /// ## 사용 예시
  /// ```dart
  /// if (item.rarity == ItemRarity.legendary) {
  ///   showSpecialEffect();
  /// }
  /// ```
  ItemRarity get rarity => resolveItemRarity(properties['rarity'], id);
  
  /// 희귀도 문자열 (정규화된 대문자)
  ///
  /// JSON 직렬화나 문자열 비교에 사용합니다.
  /// 예: 'COMMON', 'RARE', 'EPIC', 'LEGENDARY'
  String get rarityString => rarity.normalized;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // 아이템 타입 (Type)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// 아이템 타입 (정규화된 enum)
  ///
  /// ## 정규화 규칙
  /// - 대소문자 무시: 'weapon', 'WEAPON', 'Weapon' 모두 [ItemType.weapon]
  /// - 공백 trim: '  armor  ' → [ItemType.armor]
  /// - alias 지원: 'potion' → [ItemType.misc]
  /// - 누락/null: [ItemType.misc] (기본값)
  /// - 잘못된 값: [ItemType.misc] (dev 빌드에서 경고 로그)
  ///
  /// ## 허용 타입
  /// - weapon, armor, accessory, bag, misc
  ///
  /// ## alias
  /// - potion → misc (미구현)
  /// - food → misc (미구현)
  /// - consumable → misc (더 이상 사용하지 않음)
  /// - acc → accessory
  ///
  /// ## 사용 예시
  /// ```dart
  /// if (item.itemType == ItemType.weapon) {
  ///   equipWeapon(item);
  /// }
  /// 
  /// if (item.itemType.isBag) {
  ///   addToBagSlot(item);
  /// }
  /// ```
  ItemType get itemType => resolveItemType(properties['type'], id);
  
  /// 타입 문자열 (정규화된 소문자)
  ///
  /// JSON 직렬화나 문자열 비교에 사용합니다.
  /// 예: 'weapon', 'armor', 'accessory', 'bag', 'misc'
  String get itemTypeString => itemType.normalized;
  
  /// 가방인지 확인 (정규화된 타입 기반)
  ///
  /// 내부적으로 [itemType]을 사용하여 판단합니다.
  /// 원본 `properties['type']` 문자열을 직접 비교하지 않습니다.
  bool get isBag => itemType.isBag;
  
  /// 가방 속성 가져오기 (가방이 아닌 경우 null)
  Map<String, dynamic>? get bagProperties {
    if (!isBag) return null;
    return properties['bag'] as Map<String, dynamic>?;
  }
  
  /// 장비인지 확인 (weapon, armor, accessory)
  bool get isEquipment => itemType.isEquipment;
  
  /// 아이템이 차지하는 모든 셀의 좌표 반환 (footprint 고려)
  List<Vector2Int> getOccupiedCells() {
    if (position == null) return [];
    
    // FootprintRotationCache를 사용하여 footprint 기반으로 셀 계산
    final cache = FootprintRotationCache.fromItem(this);
    final cells = <Vector2Int>[];
    
    for (final localCell in cache.getLocalOccupiedCells(currentRotation)) {
      cells.add(Vector2Int(
        position!.x + localCell.x,
        position!.y + localCell.y,
      ));
    }
    
    return cells;
  }
  
  /// 시계방향 90도 회전
  void rotate() {
    rotationDegrees = _normalizeRotation(rotationDegrees + 90);
  }

  /// (내부/디버그용) 지정 회전 설정
  void setRotationDegrees(int deg) {
    rotationDegrees = _normalizeRotation(deg);
  }
  
  /// 아이템 복사 (위치와 회전 상태 포함)
  InventoryItem copyWith({
    String? id,
    String? name,
    String? description,
    int? baseWidth,
    int? baseHeight,
    String? iconPath,
    int? rotationDegrees,
    bool? isRotated,
    Vector2Int? position,
    Map<String, dynamic>? properties,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      baseWidth: baseWidth ?? this.baseWidth,
      baseHeight: baseHeight ?? this.baseHeight,
      iconPath: iconPath ?? this.iconPath,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      isRotated: isRotated ?? this.isRotated,
      position: position ?? this.position,
      properties: properties ?? this.properties,
    );
  }
  
  @override
  String toString() {
    return 'InventoryItem{id: $id, name: $name, rot: $currentRotation, size: $currentWidth x $currentHeight, pos: $position}';
  }
} 