import 'dart:math' as math;

/// 전투용 시드 기반 RNG (재현성 보장)
/// 
/// 동일한 seed로 생성하면 동일한 난수 시퀀스를 생성합니다.
/// 전투 재현, 디버깅, 테스트에 활용됩니다.
/// 
/// 사용 예시:
/// ```dart
/// final rng = CombatRng(seed: 12345);
/// final damage = rng.rollDamageRange(4, 5);  // 4 또는 5
/// ```
class CombatRng {
  late final math.Random _random;
  final int? seed;
  
  /// 시드 기반 RNG 생성
  /// 
  /// [seed]가 null이면 시간 기반 랜덤 시드 사용 (비재현성)
  CombatRng({this.seed}) {
    _random = seed != null ? math.Random(seed) : math.Random();
  }
  
  /// 0.0 ~ 1.0 범위의 double 반환
  double nextDouble() => _random.nextDouble();
  
  /// 0 ~ max-1 범위의 int 반환
  int nextInt(int max) => _random.nextInt(max);
  
  /// 확률 판정 (0.0 ~ 1.0 범위의 chance)
  /// 
  /// [chance] 확률로 true 반환
  bool rollChance(double chance) => _random.nextDouble() <= chance;
  
  /// 데미지 범위 롤 (정수 범위, inclusive)
  /// 
  /// [min]과 [max] 사이의 정수를 균등 분포로 반환합니다.
  /// - min == max인 경우: RNG 호출 없이 min 반환
  /// - min > max인 경우: 경고 후 swap하여 처리
  /// - 음수인 경우: 0으로 clamp
  /// 
  /// 예시:
  /// ```dart
  /// rollDamageRange(4, 5)  // 4 또는 5
  /// rollDamageRange(5, 5)  // 항상 5 (RNG 호출 없음)
  /// ```
  int rollDamageRange(int min, int max) {
    // 음수 clamp
    min = min < 0 ? 0 : min;
    max = max < 0 ? 0 : max;
    
    // min > max 처리: swap
    if (min > max) {
      assert(false, '[CombatRng] damageRange.min($min) > max($max), swapping');
      final temp = min;
      min = max;
      max = temp;
    }
    
    // 단일값 (RNG 호출 생략)
    if (min == max) {
      return min;
    }
    
    // min ~ max inclusive 범위에서 랜덤
    // nextInt(n)은 0 ~ n-1을 반환하므로 (max - min + 1) 사용
    return min + _random.nextInt(max - min + 1);
  }
  
  /// 데미지 범위 롤 (double 입력, 정수 출력)
  /// 
  /// 소수점이 있으면 경고 후 반올림하여 처리합니다.
  int rollDamageRangeDouble(double min, double max) {
    // 소수점 체크 및 경고
    if (min != min.roundToDouble() || max != max.roundToDouble()) {
      assert(false, '[CombatRng] damageRange에 소수점 입력됨: min=$min, max=$max (정수로 반올림)');
    }
    
    return rollDamageRange(min.round(), max.round());
  }
}

/// 데미지 범위 정의 (불변)
/// 
/// JSON 파싱 및 무기 스펙에서 사용합니다.
class DamageRange {
  final int min;
  final int max;
  
  const DamageRange({required this.min, required this.max});
  
  /// JSON에서 파싱
  /// 
  /// 예시 JSON:
  /// ```json
  /// { "min": 4, "max": 5 }
  /// ```
  factory DamageRange.fromJson(Map<String, dynamic> json) {
    final minVal = (json['min'] as num?)?.toInt() ?? 0;
    final maxVal = (json['max'] as num?)?.toInt() ?? 0;
    
    // 소수점 경고
    if (json['min'] is double && (json['min'] as double) != (json['min'] as double).roundToDouble()) {
      assert(false, '[DamageRange] min에 소수점 입력됨: ${json['min']} (정수로 반올림)');
    }
    if (json['max'] is double && (json['max'] as double) != (json['max'] as double).roundToDouble()) {
      assert(false, '[DamageRange] max에 소수점 입력됨: ${json['max']} (정수로 반올림)');
    }
    
    return DamageRange(min: minVal, max: maxVal);
  }
  
  /// 단일값 생성 (baseDamage fallback용)
  factory DamageRange.single(int value) {
    return DamageRange(min: value, max: value);
  }
  
  /// 유효성 검증 (개발 환경용)
  bool get isValid => min <= max && min >= 0;
  
  /// 단일값 여부
  bool get isSingle => min == max;
  
  /// UI 표시용 문자열
  /// 
  /// - 단일값: "5"
  /// - 범위: "4–5"
  String toDisplayString() {
    if (isSingle) {
      return '$min';
    }
    return '$min–$max';
  }
  
  /// 평균 데미지 (밸런스 계산용)
  double get average => (min + max) / 2.0;
  
  @override
  String toString() => 'DamageRange($min-$max)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DamageRange && min == other.min && max == other.max;
  
  @override
  int get hashCode => min.hashCode ^ max.hashCode;
}
