import 'dart:math';
import 'dart:convert';

/// 특성 효과 타입 열거형 (확장 가능)
enum TraitEffectType {
  none,                        // 기본: 효과 없음
  increaseTraitSlot,           // 특성 슬롯 증가 (예: 천재)
  gainWeakStackPeriodically,   // 일정 주기마다 약화 스택 획득 (곱추)
  gainWeakAndHasteStackPeriodically, // 일정 주기마다 약화+가속 스택 획득 (난쟁이)
  gainBlindStackPeriodically,  // 기존 예시 (실명 스택)
  modifyVitalityAndStaminaRegen, // 바이탈/스태미나 회복 속도 동시 조정
  modifyPersuasionChance, // 설득 확률 증감
  modifySanityAndBattleBuff, // 정신력 및 전투 버프 효과
}

/// 특성 클래스
class Trait {
  final String id;
  final String name;
  final String description;
  final List<String> oppositeIds; // 상반되는 특성 ID 목록

  // 선택적 추가 필드들 (게임 시스템에서 활용하기 위해 확장)
  final int slotModifier;               // 특성 슬롯 증감치 (예: +2)
  final TraitEffectType effectType;     // 특성 효과 타입
  final Map<String, dynamic>? effectParams; // 효과 파라미터 (주기, 스택 수 등)

  Trait({
    required this.id,
    required this.name,
    required this.description,
    this.oppositeIds = const [],
    this.slotModifier = 0,
    this.effectType = TraitEffectType.none,
    this.effectParams,
  });
}

// ────✅ 추가: 전투 중 특성 반응용 TraitSystem ────
class TraitSystem {
  final List<Trait> _activeTraits = [];

  TraitSystem({List<Trait>? initialTraits}) {
    if (initialTraits != null) _activeTraits.addAll(initialTraits);
  }

  // 특성 관리 -------------------------------------------------
  void addTrait(Trait trait) => _activeTraits.add(trait);
  void removeTrait(String id) =>
      _activeTraits.removeWhere((t) => t.id == id);
  bool hasTrait(String id) =>
      _activeTraits.any((t) => t.id == id);

  // 전투 이벤트 훅 -------------------------------------------
  /// 피해를 받았을 때 호출
  void onDamageTaken(Object entity, int damage) {
    // TODO: 특성별 반응 로직을 구현하세요.
  }

  /// 추후 필요 시 onHeal, onTick 등 추가 가능
}
// ──────────────────────────────────────────

/// 천부적 특성 부여 시스템
class InnateTraitSystem {
  final List<Trait> traitPool;
  final Random _random;
  
  // 확률 상수
  static const double FIRST_TRAIT_CHANCE = 0.55; // 55%
  static const double SECOND_TRAIT_CHANCE = 0.12; // 12%
  static const double THIRD_TRAIT_CHANCE = 0.01; // 1%
  static const double REROLL_CHANCE = 0.15; // 15%

  InnateTraitSystem({
    required this.traitPool,
    Random? random,
  }) : _random = random ?? Random();

  /// 이야기 시작 시 특성 부여
  List<Trait> assignInitialTraits() {
    List<Trait> assignedTraits = [];
    List<Trait> availableTraits = List.from(traitPool);
    
    // 첫 번째 특성 부여 시도 (55%)
    bool firstTraitSuccess = _checkProbability(FIRST_TRAIT_CHANCE);
    
    if (!firstTraitSuccess) {
      // 첫 번째 특성 부여 실패 시 리롤 기회 (15%)
      bool rerollSuccess = _checkProbability(REROLL_CHANCE);
      
      if (rerollSuccess) {
        // 리롤 성공 시 첫 번째 특성 부여
        Trait? trait = _selectRandomTrait(availableTraits);
        if (trait != null) {
          assignedTraits.add(trait);
        }
      }
      
      // 첫 번째 특성 부여 실패 시 종료 (두 번째 특성 부여 기회 없음)
      return assignedTraits;
    }
    
    // 첫 번째 특성 부여 성공
    Trait? firstTrait = _selectRandomTrait(availableTraits);
    if (firstTrait == null) return assignedTraits;
    
    assignedTraits.add(firstTrait);
    _removeTraitAndOpposites(availableTraits, firstTrait);
    
    // 두 번째 특성 부여 시도 (12%)
    if (_checkProbability(SECOND_TRAIT_CHANCE)) {
      Trait? secondTrait = _selectRandomTrait(availableTraits);
      if (secondTrait == null) return assignedTraits;
      
      assignedTraits.add(secondTrait);
      _removeTraitAndOpposites(availableTraits, secondTrait);
      
      // 세 번째 특성 부여 시도 (1%)
      if (_checkProbability(THIRD_TRAIT_CHANCE)) {
        Trait? thirdTrait = _selectRandomTrait(availableTraits);
        if (thirdTrait != null) {
          assignedTraits.add(thirdTrait);
        }
      }
    }
    
    return assignedTraits;
  }
  
  /// 확률 체크
  bool _checkProbability(double probability) {
    return _random.nextDouble() < probability;
  }
  
  /// 랜덤 특성 선택
  Trait? _selectRandomTrait(List<Trait> pool) {
    if (pool.isEmpty) return null;
    return pool[_random.nextInt(pool.length)];
  }
  
  /// 특성과 그 특성의 상반 특성들을 풀에서 제거
  void _removeTraitAndOpposites(List<Trait> pool, Trait trait) {
    // 해당 특성 제거
    pool.removeWhere((t) => t.id == trait.id);
    
    // 상반 특성들 제거
    for (String oppositeId in trait.oppositeIds) {
      pool.removeWhere((t) => t.id == oppositeId);
    }
  }
}

// 예시 특성 데이터
final List<Trait> innateTraitPool = [
  Trait(
    id: 'brave',
    name: '용감함',
    description: '위험한 상황에서도 두려움을 느끼지 않습니다.',
    oppositeIds: ['coward'],
  ),
  Trait(
    id: 'coward',
    name: '겁쟁이',
    description: '위험한 상황에서 쉽게 두려움을 느낍니다.',
    oppositeIds: ['brave'],
  ),
  Trait(
    id: 'altruistic',
    name: '이타적',
    description: '자신보다 타인을 먼저 생각합니다.',
    oppositeIds: ['selfish'],
  ),
  Trait(
    id: 'selfish',
    name: '이기적',
    description: '타인보다 자신의 이익을 우선시합니다.',
    oppositeIds: ['altruistic'],
  ),
  Trait(
    id: 'optimistic',
    name: '낙천적',
    description: '어떤 상황에서도 희망을 발견합니다.',
    oppositeIds: ['pessimistic'],
  ),
  Trait(
    id: 'pessimistic',
    name: '비관적',
    description: '상황의 부정적인 면을 먼저 봅니다.',
    oppositeIds: ['optimistic'],
  ),
  Trait(
    id: 'hunchback',
    name: '곱추',
    description: '4.2초마다 약화 1스택을 획득합니다.',
    oppositeIds: [],
    effectType: TraitEffectType.gainWeakStackPeriodically,
    effectParams: {
      'interval': 4.2,
      'weakStacks': 1,
      'hasteStacks': 0,
    },
  ),
  Trait(
    id: 'dwarf',
    name: '난쟁이',
    description: '4.2초마다 약화 1스택, 가속 1스택을 획득합니다.',
    oppositeIds: [],
    effectType: TraitEffectType.gainWeakAndHasteStackPeriodically,
    effectParams: {
      'interval': 4.2,
      'weakStacks': 1,
      'hasteStacks': 1,
    },
  ),
  Trait(
    id: 'frail',
    name: '허약함',
    description: '최대 생명력 -1, 스태미나 회복 속도 -0.5',
    oppositeIds: ['champion'],
    effectType: TraitEffectType.modifyVitalityAndStaminaRegen,
    effectParams: {
      'maxVitalityDelta': -1,
      'staminaRegenDelta': -0.5,
    },
  ),
  Trait(
    id: 'champion',
    name: '천하장사',
    description: '최대 생명력 +1, 스태미나 회복 속도 +0.5',
    oppositeIds: ['frail'],
    effectType: TraitEffectType.modifyVitalityAndStaminaRegen,
    effectParams: {
      'maxVitalityDelta': 1,
      'staminaRegenDelta': 0.5,
    },
  ),   
  Trait(
    id: 'ugly',
    name: '혐오스러운 외모',
    description: '선택지에서 설득 확률 -5%',
    oppositeIds: ['beautiful'],
    effectType: TraitEffectType.modifyPersuasionChance,
    effectParams: {
      'persuasionDelta': -0.05,
    },
  ),
  Trait(
    id: 'beautiful',
    name: '아름다운 외모',
    description: '선택지에서 설득 확률 +5%',
    oppositeIds: ['ugly'],
    effectType: TraitEffectType.modifyPersuasionChance,
    effectParams: {
      'persuasionDelta': 0.05,
    },
  ),
  Trait(
    id: 'blessed',
    name: '축복받은 자',
    description: '전투 시작 시 1스택씩 7번, 매번 랜덤 효과를 부여합니다.',
    oppositeIds: [],
    effectType: TraitEffectType.modifySanityAndBattleBuff,
    effectParams: {
      'battleEffectType': 'random', // 랜덤 효과 또는 특정 효과
      'battleEffectStacks': 7,
    },
  ),
];

class Player {
  final List<String> traits = [];
  int _baseMaxTraitCount = 5;
  int _traitSlotModifier = 0;

  int vitality;
  int sanity;
  int maxVitality;
  int maxSanity;

  Player({Random? random})
      : vitality = _randomStat(random),
        sanity = _randomStat(random),
        maxVitality = 0,
        maxSanity = 0
  {
    maxVitality = vitality;
    maxSanity = sanity;
  }

  static int _randomStat([Random? random]) {
    random ??= Random();
    double roll = random.nextDouble();
    if (roll < 0.25) return 3;      // 25%
    if (roll < 0.75) return 4;      // 50%
    return 5;                       // 25%
  }

  void consumeVitality(int amount) {
    vitality = (vitality - amount).clamp(0, maxVitality);
  }

  void consumeSanity(int amount) {
    sanity = (sanity - amount).clamp(0, maxSanity);
  }

  void recoverVitality(int amount) {
    vitality = (vitality + amount).clamp(0, maxVitality);
  }

  void recoverSanity(int amount) {
    sanity = (sanity + amount).clamp(0, maxSanity);
  }

  bool get isGameOver => vitality <= 0 || sanity <= 0;
}

// 테스트용 메인 함수
void main() {
  final traitSystem = InnateTraitSystem(traitPool: innateTraitPool);
  
  // 100번 시뮬레이션하여 특성 부여 결과 확인
  Map<int, int> distribution = {0: 0, 1: 0, 2: 0, 3: 0};
  
  for (int i = 0; i < 100; i++) {
    List<Trait> traits = traitSystem.assignInitialTraits();
    distribution[traits.length] = (distribution[traits.length] ?? 0) + 1;
    
    print('시뮬레이션 #${i+1}: ${traits.length}개 특성 - ${traits.map((t) => t.name).join(', ')}');
  }
  
  // 분포 출력
  print('\n특성 개수 분포:');
  distribution.forEach((count, instances) {
    print('$count개 특성: $instances회 (${instances}%)');
  });

  // 여러 번 생성해보면 확률 분포를 확인할 수 있습니다.
  for (int i = 0; i < 10; i++) {
    final player = Player();
    print('생명력: ${player.vitality}, 정신력: ${player.sanity}');
  }
} 
