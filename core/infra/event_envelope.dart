import 'dart:math';
import '../state/events.dart';

/// 이벤트 메타데이터 래퍼
/// 
/// - eventId: 고유 식별자
/// - parentEventId: 부모 이벤트 ID (파생 이벤트용)
/// - traceId: 트레이스 ID (UserEvent에서 생성, 파생 이벤트는 상속)
/// - origin: 발생 모듈명
/// - depth: 이벤트 체인 깊이
/// - timestamp: 발생 시각
class EventEnvelope {
  final String eventId;
  final String? parentEventId;
  final String? traceId;
  final String origin;
  final int depth;
  final DateTime timestamp;
  final GEvent event;
  
  EventEnvelope({
    required this.eventId,
    this.parentEventId,
    this.traceId,
    required this.origin,
    required this.depth,
    required this.timestamp,
    required this.event,
  });
  
  /// 새 이벤트 ID 생성
  static String generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return '${now}_$random';
  }
  
  /// 새 트레이스 ID 생성 (UserEvent용)
  static String generateTraceId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(100000);
    return 'trace_${now}_$random';
  }
  
  /// 루트 Envelope 생성 (UserEvent 또는 최상위 이벤트)
  factory EventEnvelope.root({
    required GEvent event,
    required String origin,
  }) {
    final eventId = generateId();
    // UserEvent에서만 새 traceId 생성
    final traceId = event.isUserEvent ? generateTraceId() : null;
    
    return EventEnvelope(
      eventId: eventId,
      parentEventId: null,
      traceId: traceId,
      origin: origin,
      depth: 0,
      timestamp: DateTime.now(),
      event: event,
    );
  }
  
  /// 자식 Envelope 생성 (파생 이벤트용)
  /// 
  /// - traceId는 부모로부터 상속
  /// - depth는 부모 + 1
  EventEnvelope child({
    required GEvent event,
    required String origin,
  }) {
    return EventEnvelope(
      eventId: generateId(),
      parentEventId: eventId,
      traceId: traceId,  // 부모로부터 상속
      origin: origin,
      depth: depth + 1,
      timestamp: DateTime.now(),
      event: event,
    );
  }
  
  /// 문맥 포함 보고용 Envelope 생성
  /// 
  /// CombatModule 등에서 저장된 부모 문맥으로 이벤트를 보고할 때 사용
  factory EventEnvelope.withContext({
    required GEvent event,
    required String origin,
    String? parentTraceId,
    String? parentEventId,
    int parentDepth = 0,
  }) {
    return EventEnvelope(
      eventId: generateId(),
      parentEventId: parentEventId,
      traceId: parentTraceId,  // 주입된 부모 traceId 상속
      origin: origin,
      depth: parentDepth + 1,
      timestamp: DateTime.now(),
      event: event,
    );
  }
  
  /// 로그 포맷 문자열
  String toLogString() {
    final traceStr = traceId ?? 'no-trace';
    return '[$traceStr:$depth] $eventId $origin → ${event.runtimeType}';
  }
  
  @override
  String toString() {
    return 'EventEnvelope('
           'id: $eventId, '
           'parent: $parentEventId, '
           'trace: $traceId, '
           'origin: $origin, '
           'depth: $depth, '
           'event: ${event.runtimeType})';
  }
}
