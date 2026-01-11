/// XP (Experience Points) 서비스
/// 
/// 숨은 XP를 관리하며 UI에 노출되지 않습니다.
/// 인카운터 종료 시에만 XP가 증가합니다.

import 'package:flutter/foundation.dart';

/// XP 증가 소스 타입
enum XpSource {
  encounter,      // 인카운터 완료
  combat,         // 전투 승리
  quest,          // 퀘스트 완료
  exploration,    // 탐험
  other,          // 기타
}

/// XP 변경 기록 (디버깅용)
class XpChange {
  final int previousXp;
  final int newXp;
  final int delta;
  final XpSource source;
  final String? detail;
  final DateTime timestamp;

  const XpChange({
    required this.previousXp,
    required this.newXp,
    required this.delta,
    required this.source,
    this.detail,
    required this.timestamp,
  });

  @override
  String toString() =>
      'XpChange($previousXp → $newXp, +$delta from ${source.name}${detail != null ? ': $detail' : ''})';
}

/// XP 서비스 - 싱글톤
class XpService {
  static XpService? _instance;
  static XpService get instance => _instance ??= XpService._();
  
  XpService._();

  /// 숨은 XP (UI에 노출 금지!)
  int _hiddenXp = 0;

  /// XP 변경 히스토리 (디버깅용, 개발 빌드에서만)
  final List<XpChange> _history = [];

  /// 최대 히스토리 크기
  static const int _maxHistorySize = 100;

  /// 현재 XP 조회
  int get() => _hiddenXp;

  /// XP 직접 설정 (로드/리셋용)
  void set(int value) {
    assert(value >= 0, 'XP cannot be negative');
    if (kDebugMode) {
      debugPrint('[XpService] Set XP: $_hiddenXp → $value');
    }
    _hiddenXp = value.clamp(0, 999999);
  }

  /// XP 추가
  /// 
  /// [source]: XP 획득 소스
  /// [amount]: 추가할 XP 양 (음수 불가)
  /// [detail]: 상세 설명 (선택)
  /// 
  /// Returns: 이전 XP와 새 XP
  (int previous, int now) addXp(
    XpSource source,
    int amount, {
    String? detail,
  }) {
    assert(amount >= 0, 'XP amount must be non-negative');

    final prev = _hiddenXp;
    _hiddenXp += amount;

    // 히스토리 기록 (디버그 빌드)
    if (kDebugMode) {
      final change = XpChange(
        previousXp: prev,
        newXp: _hiddenXp,
        delta: amount,
        source: source,
        detail: detail,
        timestamp: DateTime.now(),
      );
      
      _history.add(change);
      
      // 히스토리 크기 제한
      if (_history.length > _maxHistorySize) {
        _history.removeAt(0);
      }

      debugPrint('[XpService] $change');
    }

    return (prev, _hiddenXp);
  }

  /// 인카운터 결과 기반 XP 계산 및 추가
  /// 
  /// [encounterId]: 인카운터 ID
  /// [outcome]: 인카운터 결과 (success, failure, escaped 등)
  /// 
  /// Returns: (이전 XP, 새 XP, 획득 XP)
  (int previous, int now, int gained) onEncounterResolved(
    String encounterId,
    Map<String, dynamic> outcome,
  ) {
    final xpGained = _calculateEncounterXp(encounterId, outcome);
    final (prev, now) = addXp(
      XpSource.encounter,
      xpGained,
      detail: encounterId,
    );
    
    return (prev, now, xpGained);
  }

  /// 인카운터 XP 계산 (기본 로직)
  /// 
  /// 커스텀 계산 로직이 필요하면 오버라이드 가능
  int _calculateEncounterXp(String encounterId, Map<String, dynamic> outcome) {
    // 기본값
    int baseXp = 10;

    // outcome에서 XP 추출 (있으면)
    if (outcome.containsKey('xp')) {
      final xpValue = outcome['xp'];
      if (xpValue is int) {
        return xpValue;
      }
    }

    // success 여부에 따라 조정
    final success = outcome['success'] == true;
    if (!success) {
      baseXp = (baseXp * 0.5).round(); // 실패 시 50%
    }

    // difficulty 기반 조정 (있으면)
    final difficulty = outcome['difficulty'];
    if (difficulty != null) {
      if (difficulty == 'easy') {
        baseXp = (baseXp * 0.8).round();
      } else if (difficulty == 'hard') {
        baseXp = (baseXp * 1.5).round();
      }
    }

    return baseXp.clamp(1, 100);
  }

  /// XP 리셋 (챕터 종료 시)
  void reset() {
    if (kDebugMode) {
      debugPrint('[XpService] Reset XP from $_hiddenXp to 0');
    }
    _hiddenXp = 0;
    _history.clear();
  }

  /// 히스토리 조회 (디버깅용)
  List<XpChange> getHistory() => List.unmodifiable(_history);

  /// 히스토리 초기화
  void clearHistory() {
    _history.clear();
  }

  /// 상태 저장용 데이터
  Map<String, dynamic> toJson() => {
    'hiddenXp': _hiddenXp,
  };

  /// 상태 복원
  void fromJson(Map<String, dynamic> json) {
    _hiddenXp = json['hiddenXp'] as int? ?? 0;
    if (kDebugMode) {
      debugPrint('[XpService] Loaded XP: $_hiddenXp');
    }
  }
}

