import 'dart:math';
import '../../branch_system.dart';

/// 특성 효과 타입 열거형
enum TraitEffectType {
  none,
  increaseTraitSlot,
  gainWeakStackPeriodically,
  gainWeakAndHasteStackPeriodically,
  gainBlindStackPeriodically,
  modifyVitalityAndStaminaRegen,
  modifyPersuasionChance,
  modifySanityAndBattleBuff,
}

/// 특성 클래스
class Trait implements GameContent {
  @override
  final String id;
  final String name;
  final String description;
  final List<String> oppositeIds;
  final int slotModifier;
  final TraitEffectType effectType;
  final Map<String, dynamic>? effectParams;

  const Trait({
    required this.id,
    required this.name,
    required this.description,
    this.oppositeIds = const [],
    this.slotModifier = 0,
    this.effectType = TraitEffectType.none,
    this.effectParams,
  });
}

/// 플레이어 캐릭터 클래스
/// 
/// ## 🎯 중요: RPG 스탯과 전투 스탯의 분리
/// 
/// Player 클래스의 능력치는 **전투 스탯에 직접 영향을 주지 않습니다**:
/// - **strength, agility, intelligence, charisma**: 
///   → 선택지 확률 보정 (skill check)
///   → 인카운터 등장 조건 체크
///   → 대화 분기 조건
/// 
/// - **vitality, sanity**: 
///   → vitality: 전투 시작 시 HP 계산에만 사용 (vitality * 25)
///   → sanity: 게임 오버 조건, 특정 이벤트 트리거
/// 
/// 실제 전투 스탯(attackPower, accuracy, defenseRate 등)은 
/// **인벤토리의 배치된 아이템에서만 결정**됩니다.
/// → `InventoryAdapter.createPlayerCharacter()` 참고
class Player {
  // ====== 기본 능력치 (3-7 범위) ======
  final int strength;     // 힘 (전투 외 선택지/조건에만 사용)
  final int agility;      // 민첩 (전투 외 선택지/조건에만 사용)
  final int intelligence; // 지능 (전투 외 선택지/조건에만 사용)
  final int charisma;     // 매력 (전투 외 선택지/조건에만 사용)
  
  // ====== 생명력/정신력 (3-5 범위) ======
  final int vitality;     // 현재 생명력 (전투 시작 HP 계산에 사용)
  final int sanity;       // 현재 정신력 (게임 오버 조건)
  final int maxVitality;  // 최대 생명력
  final int maxSanity;    // 최대 정신력
  
  // ====== 특성 시스템 ======
  final List<Trait> traits;

  const Player({
    required this.strength,
    required this.agility, 
    required this.intelligence,
    required this.charisma,
    required this.vitality,
    required this.sanity,
    required this.maxVitality,
    required this.maxSanity,
    required this.traits,
  });

  /// 팩토리 생성자 - 랜덤 스탯으로 생성
  factory Player.createRandom({Random? random}) {
    random ??= Random();
    
    // 1. 기본 능력치 생성 (3-7 범위, 가중치 확률)
    final str = _randomAbilityStat(random);
    final agi = _randomAbilityStat(random);
    final intel = _randomAbilityStat(random);
    final cha = _randomAbilityStat(random);
    
    // 2. 생명력/정신력 생성 (3-5 범위, 기존 확률)
    final vit = _randomVitalityStat(random);
    final san = _randomVitalityStat(random);
    
    return Player(
      strength: str,
      agility: agi,
      intelligence: intel, 
      charisma: cha,
      vitality: vit,
      sanity: san,
      maxVitality: vit,    // 최대 체력으로 시작
      maxSanity: san,      // 최대 정신력으로 시작
      traits: [],          // 특성은 별도로 추가
    );
  }

  /// 기본 능력치용 가중치 기반 랜덤 (3-7 범위)
  /// 15%, 40%, 30%, 10%, 5% 확률
  static int _randomAbilityStat([Random? random]) {
    random ??= Random();
    double roll = random.nextDouble();
    
    if (roll < 0.15) return 3;        // 15%
    if (roll < 0.55) return 4;        // 40% (0.15 + 0.40)
    if (roll < 0.85) return 5;        // 30% (0.55 + 0.30)
    if (roll < 0.95) return 6;        // 10% (0.85 + 0.10)
    return 7;                         // 5%  (0.95 + 0.05)
  }

  /// 생명력/정신력용 기존 랜덤 (3-5 범위)  
  /// 25%, 50%, 25% 확률
  static int _randomVitalityStat([Random? random]) {
    random ??= Random();
    double roll = random.nextDouble();
    if (roll < 0.25) return 3;      // 25%
    if (roll < 0.75) return 4;      // 50%
    return 5;                       // 25%
  }

  /// 능력치별 성공 확률 계산
  static double getSuccessRate(int statValue) {
    switch (statValue) {
      case 3: return 0.35; // 35%
      case 4: return 0.40; // 40%
      case 5: return 0.45; // 45% (기준)
      case 6: return 0.50; // 50%
      case 7: return 0.55; // 55%
      default: return 0.45; // 기본값
    }
  }

  /// 특성 추가된 새 플레이어 반환
  Player withTraits(List<Trait> newTraits) {
    return Player(
      strength: strength,
      agility: agility,
      intelligence: intelligence,
      charisma: charisma,
      traits: newTraits,
      vitality: vitality,
      sanity: sanity,
      maxVitality: maxVitality,
      maxSanity: maxSanity,
    );
  }

  /// 부분 복사 메서드 (생명력/정신력 변경 등)
  Player copyWith({
    int? strength,
    int? agility,
    int? intelligence,
    int? charisma,
    int? vitality,
    int? sanity,
    int? maxVitality,
    int? maxSanity,
    List<Trait>? traits,
  }) {
    return Player(
      strength: strength ?? this.strength,
      agility: agility ?? this.agility,
      intelligence: intelligence ?? this.intelligence,
      charisma: charisma ?? this.charisma,
      vitality: vitality ?? this.vitality,
      sanity: sanity ?? this.sanity,
      maxVitality: maxVitality ?? this.maxVitality,
      maxSanity: maxSanity ?? this.maxSanity,
      traits: traits ?? this.traits,
    );
  }

  /// 특성 보유 여부 확인
  bool hasTrait(String traitId) {
    return traits.any((trait) => trait.id == traitId);
  }

  /// 게임 오버 상태 확인
  bool get isGameOver => vitality <= 0 || sanity <= 0;
}


