import 'dart:math';
import 'data/item_data.dart';       // Item 클래스가 있는 파일

/* ──────────────────────────────────────────────────────────
  Luck(1-7) × Grade 보정 계수 테이블
────────────────────────────────────────────────────────── */
const Map<String, List<double>> _gradeCorrectionTable = {
  'common':    [1.55, 1.35, 1.20, 1.00, 0.80, 0.65, 0.45],
  'rare':      [0.44, 0.66, 0.82, 1.00, 1.10, 1.20, 1.30],
  'epic':      [0.23, 0.46, 0.69, 1.00, 1.30, 1.60, 1.92],
  'legendary': [0.00, 0.10, 0.25, 1.00, 1.80, 2.40, 3.00],
};

/// luck(1-7)와 grade에 맞는 보정 계수 반환
double getGradeCorrection(String grade, int luck) {
  final idx = luck.clamp(1, 7) - 1;               // 0-based index
  return _gradeCorrectionTable[grade.toLowerCase()]?[idx] ?? 1.0;
}

/* ──────────────────────────────────────────────────────────
  RewardSystem
────────────────────────────────────────────────────────── */
class RewardSystem {
  final Random _random;
  RewardSystem({Random? random}) : _random = random ?? Random();

  /// ① 카테고리 필터 → ② 보정 weight → ③ Weighted Random → ④ 단일 아이템 반환
  Item? generateDrop(List<Item> items, int luck, {String? category}) {
    if (items.isEmpty) return null;

    // ① 카테고리 필터
    final pool = category == null
        ? items
        : items.where((i) => i.type == category).toList();
    if (pool.isEmpty) return null;

    // ②-③ 보정 weight 계산 및 총합
    final weights = pool
        .map((i) => i.dropWeight * getGradeCorrection(i.grade, luck))
        .toList();
    final totalWeight = weights.fold<double>(0, (a, b) => a + b);
    if (totalWeight <= 0) return null;

    // ④ Weighted Random
    final r = _random.nextDouble() * totalWeight;
    double acc = 0;
    for (var i = 0; i < pool.length; i++) {
      acc += weights[i];
      if (r < acc) return pool[i];
    }
    return pool.last; // 이론상 도달 불가-보호용
  }

  /// 항상 [count]개(기본 5개)를 **중복 없이** 드랍
  List<Item> generateDrops(List<Item> items, int luck,
      {String? category, int count = 5}) {
    if (items.isEmpty || count <= 0) return [];

    final pool = category == null
        ? List<Item>.from(items)
        : items.where((i) => i.type == category).toList();
    if (pool.isEmpty) return [];

    final drops = <Item>[];
    final maxDrop = count.clamp(1, pool.length);

    for (var n = 0; n < maxDrop; n++) {
      final drop = generateDrop(pool, luck);
      if (drop == null) break;
      drops.add(drop);
      pool.remove(drop); // 중복 제거
    }
    return drops;
  }
}

// RewardSystem을 재사용하기 위한 전역 인스턴스 -------------------------------
final RewardSystem _rewardSystem = RewardSystem();
// --------------------------------------------------------------------------

/* ──────────────────────────────────────────────────────────
  간단 테스트 (원한다면 삭제하거나 test 코드로 분리)
────────────────────────────────────────────────────────── */
class RewardResult {
  final Item item;
  final int dropCount;
  final double finalWeight;
  final int luck;
  final String? category;

  RewardResult({
    required this.item,
    required this.dropCount,
    required this.finalWeight,
    required this.luck,
    this.category,
  });

  @override
  String toString() {
    return 'RewardResult(item: ${item.id}, grade: ${item.grade}, count: $dropCount, weight: $finalWeight, luck: $luck, category: $category)';
  }
}

// onBattleEnd / onShopOpen --------------------------------------------------
RewardResult onBattleEnd(List<Item> items, int luck) {
  final item = _rewardSystem.generateDrop(items, luck);
  if (item == null) throw StateError('드랍 풀에 아이템이 없습니다.');

  final adjWeight = item.dropWeight * getGradeCorrection(item.grade, luck);
  return RewardResult(
    item: item,
    dropCount: 1,
    finalWeight: adjWeight,
    luck: luck,
    category: null,
  );
}

RewardResult onShopOpen(List<Item> items, int luck, String category) {
  final item = _rewardSystem.generateDrop(items, luck, category: category);
  if (item == null) {
    throw StateError('카테고리($category)에 해당하는 아이템이 없습니다.');
  }

  final adjWeight = item.dropWeight * getGradeCorrection(item.grade, luck);
  return RewardResult(
    item: item,
    dropCount: 1,
    finalWeight: adjWeight,
    luck: luck,
    category: category,
  );
}
// --------------------------------------------------------------------------

// main() 테스트용 더미 아이템 -------------------------------------------------
void main() {
  final items = [
    Item(
      id: 'sword_1',
      type: 'weapon',
      grade: 'common',
      dropWeight: 50,
      i18n: I18n(name: {'en': 'Sword 1'}),
      stats: Stats(damage: '10'),
    ),
    Item(
      id: 'sword_2',
      type: 'weapon',
      grade: 'rare',
      dropWeight: 30,
      i18n: I18n(name: {'en': 'Sword 2'}),
      stats: Stats(damage: '15'),
    ),
    Item(
      id: 'shield_1',
      type: 'armor',
      grade: 'common',
      dropWeight: 40,
      i18n: I18n(name: {'en': 'Shield 1'}),
      stats: Stats(damage: '0'),
    ),
    Item(
      id: 'potion_1',
      type: 'consumable',
      grade: 'rare',
      dropWeight: 25,
      i18n: I18n(name: {'en': 'Potion 1'}),
      stats: Stats(damage: '0'),
    ),
    Item(
      id: 'ring_1',
      type: 'accessory',
      grade: 'epic',
      dropWeight: 10,
      i18n: I18n(name: {'en': 'Ring 1'}),
      stats: Stats(damage: '0'),
    ),
    Item(
      id: 'amulet_1',
      type: 'accessory',
      grade: 'legendary',
      dropWeight: 2,
      i18n: I18n(name: {'en': 'Amulet 1'}),
      stats: Stats(damage: '0'),
    ),
  ];

  // luck 1~7, 각 100회 시뮬레이션 ------------------------------------------
  for (int luck = 1; luck <= 7; luck++) {
    final gradeCount = <String, int>{};
    for (int i = 0; i < 100; i++) {
      final result = onBattleEnd(items, luck);
      gradeCount[result.item.grade] =
          (gradeCount[result.item.grade] ?? 0) + 1;
    }
    final grades = ['common', 'rare', 'epic', 'legendary'];
    final stats =
        grades.map((g) => '$g ${gradeCount[g] ?? 0}').join(', ');
    print('Luck $luck: $stats');
  }
}
// --------------------------------------------------------------------------
