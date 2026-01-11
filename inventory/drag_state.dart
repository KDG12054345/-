import 'vector2_int.dart';
import 'inventory_item.dart';

enum DragStateType {
  none,       // 드래그 없음
  dragging,   // 드래그 중
  hovering,   // 마우스 호버
}

class DragState {
  DragStateType type;
  InventoryItem? draggedItem;
  Vector2Int? originalPosition;
  Vector2Int? currentHoverPosition;
  int wasOriginallyRotationDegrees;
  
  DragState({
    this.type = DragStateType.none,
    this.draggedItem,
    this.originalPosition,
    this.currentHoverPosition,
    this.wasOriginallyRotationDegrees = 0,
  });
  
  /// 드래그 시작
  void startDrag(InventoryItem item) {
    type = DragStateType.dragging;
    draggedItem = item;
    originalPosition = item.position;
    wasOriginallyRotationDegrees = item.currentRotation;
    currentHoverPosition = null;
  }
  
  /// 드래그 종료
  void endDrag() {
    type = DragStateType.none;
    draggedItem = null;
    originalPosition = null;
    currentHoverPosition = null;
    wasOriginallyRotationDegrees = 0;
  }
  
  /// 호버 위치 업데이트
  void updateHoverPosition(Vector2Int? position) {
    currentHoverPosition = position;
    if (type == DragStateType.none && position != null) {
      type = DragStateType.hovering;
    } else if (type == DragStateType.hovering && position == null) {
      type = DragStateType.none;
    }
  }
  
  /// 드래그 중인지 확인
  bool get isDragging => type == DragStateType.dragging;
  
  /// 호버 중인지 확인
  bool get isHovering => type == DragStateType.hovering;
  
  /// 활성 상태인지 확인
  bool get isActive => type != DragStateType.none;
  
  /// 드래그 취소 (원래 위치와 회전 상태로 복원)
  void cancelDrag() {
    if (draggedItem != null && originalPosition != null) {
      draggedItem!.position = originalPosition;
      draggedItem!.setRotationDegrees(wasOriginallyRotationDegrees);
    }
    endDrag();
  }
  
  /// 상태 초기화
  void reset() {
    type = DragStateType.none;
    draggedItem = null;
    originalPosition = null;
    currentHoverPosition = null;
    wasOriginallyRotationDegrees = 0;
  }
  
  @override
  String toString() {
    return 'DragState{type: $type, item: ${draggedItem?.id}, hover: $currentHoverPosition}';
  }
} 