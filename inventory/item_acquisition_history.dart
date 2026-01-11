import 'package:meta/meta.dart';

/// 아이템 획득 기록을 나타내는 클래스
@immutable
class ItemAcquisitionRecord {
  final String itemId;
  final DateTime timestamp;
  final String? location;      // 획득 장소
  final String? condition;     // 획득 조건 (e.g. "퀘스트 완료", "상자에서 발견")
  final Map<String, dynamic>? context;  // 추가 컨텍스트 정보

  const ItemAcquisitionRecord({
    required this.itemId,
    required this.timestamp,
    this.location,
    this.condition,
    this.context,
  });

  @override
  String toString() {
    return 'ItemAcquisitionRecord{itemId: $itemId, timestamp: $timestamp, location: $location, condition: $condition}';
  }
}

/// 아이템 획득 히스토리 관리 시스템
class ItemAcquisitionHistory {
  final List<ItemAcquisitionRecord> _records = [];

  /// 새로운 아이템 획득 기록 추가
  void recordAcquisition({
    required String itemId,
    String? location,
    String? condition,
    Map<String, dynamic>? context,
  }) {
    final record = ItemAcquisitionRecord(
      itemId: itemId,
      timestamp: DateTime.now(),
      location: location,
      condition: condition,
      context: context,
    );
    _records.add(record);
  }

  /// 특정 아이템을 획득한 적이 있는지 확인
  bool hasAcquiredItem(String itemId) {
    return _records.any((record) => record.itemId == itemId);
  }

  /// 여러 아이템을 특정 순서대로 획득했는지 확인
  bool checkAcquisitionOrder(List<String> itemIds) {
    if (itemIds.isEmpty) return true;
    if (_records.isEmpty) return false;

    int currentIndex = 0;
    for (final record in _records) {
      if (record.itemId == itemIds[currentIndex]) {
        currentIndex++;
        if (currentIndex == itemIds.length) {
          return true;
        }
      }
    }
    return false;
  }

  /// 전체 획득 히스토리 조회
  List<ItemAcquisitionRecord> getAcquisitionHistory() {
    return List.unmodifiable(_records);
  }

  /// 특정 아이템의 획득 기록만 조회
  List<ItemAcquisitionRecord> getItemAcquisitions(String itemId) {
    return _records.where((record) => record.itemId == itemId).toList();
  }

  /// 특정 기간 동안의 획득 기록 조회
  List<ItemAcquisitionRecord> getAcquisitionsByDateRange(DateTime start, DateTime end) {
    return _records.where((record) => 
      record.timestamp.isAfter(start) && record.timestamp.isBefore(end)
    ).toList();
  }

  /// 특정 위치에서의 획득 기록 조회
  List<ItemAcquisitionRecord> getAcquisitionsByLocation(String location) {
    return _records.where((record) => record.location == location).toList();
  }

  /// 특정 조건으로 획득한 기록 조회
  List<ItemAcquisitionRecord> getAcquisitionsByCondition(String condition) {
    return _records.where((record) => record.condition == condition).toList();
  }

  /// 가장 최근에 획득한 아이템 조회
  ItemAcquisitionRecord? getLatestAcquisition() {
    if (_records.isEmpty) return null;
    return _records.last;
  }

  /// 특정 아이템을 처음 획득한 시점 조회
  DateTime? getFirstAcquisitionTime(String itemId) {
    final acquisitions = getItemAcquisitions(itemId);
    if (acquisitions.isEmpty) return null;
    return acquisitions.first.timestamp;
  }

  /// 히스토리 초기화
  void clear() {
    _records.clear();
  }
} 