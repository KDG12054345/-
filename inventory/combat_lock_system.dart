/// 전투 중 인벤토리 조작 제한 시스템
/// 
/// 전투가 시작되면 인벤토리를 잠금 상태로 전환하여
/// 아이템 이동, 회전, 추가, 제거 등을 차단합니다.
library;

import 'dart:async';

enum InventoryLockReason {
  combat('전투 중'),
  dialogue('대화 중'),
  cutscene('이벤트 진행 중'),
  other('제한됨');

  final String description;
  const InventoryLockReason(this.description);
}

class InventoryLockInfo {
  final InventoryLockReason reason;
  final DateTime lockedAt;
  final String? additionalInfo;

  InventoryLockInfo({
    required this.reason,
    DateTime? lockedAt,
    this.additionalInfo,
  }) : lockedAt = lockedAt ?? DateTime.now();

  @override
  String toString() => 'Locked: ${reason.description}${additionalInfo != null ? " - $additionalInfo" : ""}';
}

class CombatLockSystem {
  bool _isLocked = false;
  bool _isInCombat = false;
  InventoryLockInfo? _lockInfo;
  
  // 잠금 상태 변경 알림 스트림
  final _lockStateController = StreamController<bool>.broadcast();
  Stream<bool> get onLockStateChanged => _lockStateController.stream;

  /// 현재 잠금 상태
  bool get isLocked => _isLocked;
  
  /// 전투 중 여부
  bool get isInCombat => _isInCombat;
  
  /// 잠금 정보
  InventoryLockInfo? get lockInfo => _lockInfo;

  /// 인벤토리 잠금 (전투 시작 등)
  void lock({
    InventoryLockReason reason = InventoryLockReason.combat,
    String? additionalInfo,
  }) {
    if (_isLocked) {
      print('[CombatLockSystem] Already locked: $_lockInfo');
      return;
    }

    _isLocked = true;
    _lockInfo = InventoryLockInfo(
      reason: reason,
      additionalInfo: additionalInfo,
    );
    
    _lockStateController.add(true);
    print('[CombatLockSystem] Inventory locked: $_lockInfo');
  }

  /// 인벤토리 잠금 해제 (전투 종료 등)
  void unlock() {
    if (!_isLocked) {
      print('[CombatLockSystem] Already unlocked');
      return;
    }

    final previousLock = _lockInfo;
    _isLocked = false;
    _lockInfo = null;
    
    _lockStateController.add(false);
    print('[CombatLockSystem] Inventory unlocked (was: $previousLock)');
  }

  /// 전투 시작
  void startCombat([String? combatId]) {
    _isInCombat = true;
  }

  /// 전투 종료
  void endCombat() {
    _isInCombat = false;
  }

  /// 작업 허용 여부 확인 (에러 메시지 포함)
  LockCheckResult canPerformAction(String actionName) {
    if (!_isLocked) {
      return LockCheckResult.allowed();
    }

    return LockCheckResult.denied(
      reason: _lockInfo?.reason ?? InventoryLockReason.other,
      message: '${_lockInfo?.reason.description ?? "제한됨"} - $actionName을(를) 할 수 없습니다.',
    );
  }

  /// 특정 작업 실행 시도 (잠금 상태 자동 체크)
  T? tryPerform<T>(String actionName, T Function() action) {
    final check = canPerformAction(actionName);
    
    if (!check.allowed) {
      print('[CombatLockSystem] Action blocked: ${check.message}');
      return null;
    }

    return action();
  }

  /// 정리
  void dispose() {
    _lockStateController.close();
  }

  /// 디버그 정보
  String debugInfo() {
    return '''
=== CombatLockSystem ===
Locked: $_isLocked
Info: $_lockInfo
''';
  }
}

/// 잠금 체크 결과
class LockCheckResult {
  final bool allowed;
  final InventoryLockReason? reason;
  final String? message;

  const LockCheckResult._({
    required this.allowed,
    this.reason,
    this.message,
  });

  factory LockCheckResult.allowed() {
    return const LockCheckResult._(allowed: true);
  }

  factory LockCheckResult.denied({
    required InventoryLockReason reason,
    String? message,
  }) {
    return LockCheckResult._(
      allowed: false,
      reason: reason,
      message: message,
    );
  }

  @override
  String toString() => allowed ? 'Allowed' : 'Denied: $message';
}

