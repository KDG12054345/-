/// 엔딩 해결 서비스
/// 
/// 시작 테마와 플레이어 플래그를 기반으로 엔딩을 결정하고 라우팅합니다.

import 'package:flutter/foundation.dart';

/// 엔딩 정보
class Ending {
  final String id;
  final String title;
  final String description;
  final Map<String, dynamic> conditions;

  const Ending({
    required this.id,
    required this.title,
    required this.description,
    this.conditions = const {},
  });

  factory Ending.fromJson(Map<String, dynamic> json) {
    return Ending(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      conditions: json['conditions'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
  String toString() => 'Ending($id: $title)';
}

/// 엔딩 해결 서비스 - 싱글톤
class EndingResolver {
  static EndingResolver? _instance;
  static EndingResolver get instance => _instance ??= EndingResolver._();

  EndingResolver._();

  /// 엔딩 목록 (설정에서 로드)
  final Map<String, Ending> _endings = {};

  /// 기본 엔딩
  static const String _defaultEndingId = 'default_ending';

  /// 엔딩 설정 로드
  void loadEndings(Map<String, dynamic> endingsConfig) {
    _endings.clear();

    endingsConfig.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        _endings[key] = Ending.fromJson({...value, 'id': key});
      }
    });

    if (kDebugMode) {
      debugPrint('[EndingResolver] Loaded ${_endings.length} endings');
    }
  }

  /// 엔딩 해결
  /// 
  /// [startThemeKey]: 시작 테마 키 (예: 'start_knight', 'start_mage')
  /// [playerFlags]: 플레이어 플래그 (게임 중 수집된 결정들)
  /// 
  /// Returns: 엔딩 ID
  String resolveEnding(String startThemeKey, Map<String, bool> playerFlags) {
    if (kDebugMode) {
      debugPrint('[EndingResolver] Resolving ending: theme=$startThemeKey, flags=$playerFlags');
    }

    // 1. 조건 매칭 (우선순위 높은 순)
    for (final ending in _endings.values) {
      if (_matchesConditions(ending.conditions, startThemeKey, playerFlags)) {
        if (kDebugMode) {
          debugPrint('[EndingResolver] Matched ending: ${ending.id}');
        }
        return ending.id;
      }
    }

    // 2. 시작 테마 기반 기본 엔딩
    final themeEnding = '$startThemeKey\_ending';
    if (_endings.containsKey(themeEnding)) {
      if (kDebugMode) {
        debugPrint('[EndingResolver] Using theme ending: $themeEnding');
      }
      return themeEnding;
    }

    // 3. 전역 기본 엔딩
    if (kDebugMode) {
      debugPrint('[EndingResolver] Using default ending');
    }
    return _defaultEndingId;
  }

  /// 조건 매칭
  bool _matchesConditions(
    Map<String, dynamic> conditions,
    String startThemeKey,
    Map<String, bool> playerFlags,
  ) {
    if (conditions.isEmpty) return false;

    // 시작 테마 체크
    final requiredTheme = conditions['startTheme'];
    if (requiredTheme != null && requiredTheme != startThemeKey) {
      return false;
    }

    // 플래그 체크
    final requiredFlags = conditions['flags'];
    if (requiredFlags is Map<String, dynamic>) {
      for (final entry in requiredFlags.entries) {
        final flagName = entry.key;
        final requiredValue = entry.value;

        if (requiredValue is bool) {
          final actualValue = playerFlags[flagName] ?? false;
          if (actualValue != requiredValue) {
            return false;
          }
        }
      }
    }

    // 최소 플래그 수 체크
    final minFlags = conditions['minFlags'];
    if (minFlags is int) {
      final trueCount = playerFlags.values.where((v) => v).length;
      if (trueCount < minFlags) {
        return false;
      }
    }

    return true;
  }

  /// 엔딩 경로 가져오기
  /// 
  /// Returns: 엔딩 파일 경로
  String getEndingPath(String endingId) {
    // 엔딩 파일은 별도 폴더에 위치
    return 'assets/dialogue/endings/$endingId.json';
  }

  /// 엔딩 정보 조회
  Ending? getEnding(String endingId) {
    return _endings[endingId];
  }

  /// 모든 엔딩 목록
  List<Ending> getAllEndings() {
    return _endings.values.toList();
  }

  /// 디버그 정보
  String debugInfo() {
    return '''
EndingResolver Debug:
  Total Endings: ${_endings.length}
  Endings: ${_endings.keys.toList()}
''';
  }
}

