/// 더티 플래그 관리 시스템
class DirtyFlagSystem {
  final Set<String> _dirtyItemIds = <String>{};
  final Map<String, String> _dirtyReasons = <String, String>{};
  final Map<String, DateTime> _dirtyTimestamps = <String, DateTime>{};
  
  /// 아이템을 더티로 표시
  void markDirty(String itemId, String reason) {
    _dirtyItemIds.add(itemId);
    _dirtyReasons[itemId] = reason;
    _dirtyTimestamps[itemId] = DateTime.now();
  }
  
  /// 여러 아이템을 더티로 표시
  void markMultipleDirty(Set<String> itemIds, String reason) {
    final now = DateTime.now();
    for (final itemId in itemIds) {
      _dirtyItemIds.add(itemId);
      _dirtyReasons[itemId] = reason;
      _dirtyTimestamps[itemId] = now;
    }
  }
  
  /// 더티 상태 확인
  bool isDirty(String itemId) => _dirtyItemIds.contains(itemId);
  
  /// 전체 더티 상태 확인
  bool get hasAnyDirty => _dirtyItemIds.isNotEmpty;
  
  /// 더티 아이템 목록 반환
  Set<String> get dirtyItemIds => Set.unmodifiable(_dirtyItemIds);
  
  /// 특정 아이템의 더티 이유 반환
  String? getDirtyReason(String itemId) => _dirtyReasons[itemId];
  
  /// 더티 플래그 초기화
  void clearDirty(String itemId) {
    _dirtyItemIds.remove(itemId);
    _dirtyReasons.remove(itemId);
    _dirtyTimestamps.remove(itemId);
  }
  
  /// 모든 더티 플래그 초기화
  void clearAllDirty() {
    _dirtyItemIds.clear();
    _dirtyReasons.clear();
    _dirtyTimestamps.clear();
  }
  
  /// 네이버후드 더티 마킹 (주변 아이템들도 영향받음)
  void markNeighborhoodDirty(
    String centerItemId, 
    List<String> neighborItemIds, 
    String reason
  ) {
    markDirty(centerItemId, reason);
    for (final neighborId in neighborItemIds) {
      markDirty(neighborId, 'neighbor_of_$centerItemId');
    }
  }
}
