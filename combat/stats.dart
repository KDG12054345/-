// (import 문 불필요 – 사용하지 않는 모듈 모두 제거)

// 기본 스탯 (치명타 관련 속성 제거)
class BaseStats {
  final int maxHealth;
  final int baseAttackPower;
  final int baseAccuracy;

  const BaseStats({
    required this.maxHealth,
    required this.baseAttackPower,
    required this.baseAccuracy,
  });
}

// 전투 스탯 (치명타 관련 속성 제거)
class CombatStats {
  /// 빈 스탯(모든 값 0) – 아이템/기본값 용
  static final empty = CombatStats(maxHealth: 0, attackPower: 0, accuracy: 0, defenseRate: 0.0);

  /// 임시
  int _maxHealth;
  int _currentHealth;
  final int attackPower;
  final int accuracy;
  final double defenseRate;  // 방어율 0.0 ~ 1.0 (0% ~ 100%)

  CombatStats({
    int maxHealth = 100,
    int? currentHealth,
    this.attackPower = 0,
    this.accuracy = 0,
    this.defenseRate = 0.0,  // 기본값 0% (방어 없음)
  })  : _maxHealth = maxHealth,
        _currentHealth = currentHealth ?? maxHealth;

  // 현재 체력
  int get maxHealth => _maxHealth;

  int get currentHealth => _currentHealth;
  set currentHealth(int value) =>
      _currentHealth = value.clamp(0, _maxHealth);

  // 최대 체력 수정
  void modifyMaxHealth(int amount) {
    _maxHealth = (_maxHealth + amount).clamp(0, 1 << 31);
    if (_currentHealth > _maxHealth) _currentHealth = _maxHealth;
  }

  // 스탯 합산
  CombatStats operator +(CombatStats other) => CombatStats(
        maxHealth: _maxHealth + other._maxHealth,
        currentHealth: _currentHealth,            // 현재 체력은 유지
        attackPower: attackPower + other.attackPower,
        accuracy: accuracy + other.accuracy,
        defenseRate: (defenseRate + other.defenseRate).clamp(0.0, 0.75),  // 최대 75% 제한
      );

  // 부분 복사
  CombatStats copyWith({
    int? maxHealth,
    int? currentHealth,
    int? attackPower,
    int? accuracy,
    double? defenseRate,
  }) =>
      CombatStats(
        maxHealth: maxHealth ?? _maxHealth,
        currentHealth: currentHealth ?? _currentHealth,
        attackPower: attackPower ?? this.attackPower,
        accuracy: accuracy ?? this.accuracy,
        defenseRate: defenseRate ?? this.defenseRate,
      );
} 