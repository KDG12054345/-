import 'dart:math';
import 'character_models.dart';

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
      
      // 첫 번째 특성 부여 실패 시 종료
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

/// 캐릭터 생성 서비스
class CharacterCreationService {
  final InnateTraitSystem _traitSystem;

  CharacterCreationService({required InnateTraitSystem traitSystem})
      : _traitSystem = traitSystem;

  /// 새 캐릭터 생성
  Player createNewCharacter({Random? random}) {
    // 1. 기본 스탯으로 플레이어 생성 (named parameter로 수정)
    final basePlayer = Player.createRandom(random: random);
    
    // 2. 특성 부여
    final traits = _traitSystem.assignInitialTraits();
    
    // 3. 특성이 적용된 플레이어 반환
    return basePlayer.withTraits(traits);
  }
}

/// 기본 특성 풀 (임시 데이터)
final List<Trait> defaultTraitPool = [
  const Trait(
    id: 'brave',
    name: '용감함',
    description: '위험한 상황에서도 두려움을 느끼지 않습니다.',
    oppositeIds: ['coward'],
  ),
  const Trait(
    id: 'coward',
    name: '겁쟁이',
    description: '위험한 상황에서 쉽게 두려움을 느낍니다.',
    oppositeIds: ['brave'],
  ),
  const Trait(
    id: 'altruistic',
    name: '이타적',
    description: '자신보다 타인을 먼저 생각합니다.',
    oppositeIds: ['selfish'],
  ),
  const Trait(
    id: 'selfish',
    name: '이기적',
    description: '타인보다 자신의 이익을 우선시합니다.',
    oppositeIds: ['altruistic'],
  ),
  const Trait(
    id: 'obsessive',
    name: '결벽증',
    description: '게임 시작 시 랜덤 가방을 하나 받습니다.',
    oppositeIds: [],
  ),
];
