/// 전투 중 인벤토리 잠금 관리 시스템
class CombatLockSystem {
  bool _isInCombat = false;
  String? _currentCombatId;
  DateTime? _combatStartTime;
  
  /// 전투 상태 확인
  bool get isInCombat => _isInCombat;
  bool get isInventoryLocked => _isInCombat;
  String? get currentCombatId => _currentCombatId;
  
  /// 전투 시작 - 인벤토리 잠금
  void startCombat(String combatId) {
    _isInCombat = true;
    _currentCombatId = combatId;
    _combatStartTime = DateTime.now();
  }
  
  /// 전투 종료 - 인벤토리 잠금 해제
  void endCombat() {
    _isInCombat = false;
    _currentCombatId = null;
    _combatStartTime = null;
  }
  
  /// 인벤토리 액션 허용 여부 확인
  bool canPerformInventoryAction(String actionType) {
    if (!_isInCombat) return true;
    
    // 전투 중 허용되는 액션들 (읽기 전용)
    const allowedActions = {
      'view', 'inspect', 'tooltip', 'highlight', 'select'
    };
    
    return allowedActions.contains(actionType);
  }
  
  /// 잠금된 액션 시도 시 에러 메시지
  String getLockMessage(String actionType) {
    return switch (actionType) {
      'move' => '전투 중에는 아이템을 이동할 수 없습니다.',
      'rotate' => '전투 중에는 아이템을 회전할 수 없습니다.',
      'enhance' => '전투 중에는 아이템을 강화할 수 없습니다.',
      'delete' => '전투 중에는 아이템을 삭제할 수 없습니다.',
      'add' => '전투 중에는 아이템을 추가할 수 없습니다.',
      _ => '전투 중에는 이 작업을 수행할 수 없습니다.',
    };
  }
  
  /// 전투 시간 반환
  Duration? get combatDuration {
    if (_combatStartTime == null) return null;
    return DateTime.now().difference(_combatStartTime!);
  }
}

/// 인벤토리 잠금 예외
class InventoryLockedException implements Exception {
  final String message;
  final String actionType;
  
  const InventoryLockedException(this.message, this.actionType);
  
  @override
  String toString() => 'InventoryLockedException: $message';
}
