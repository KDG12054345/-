import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/item/item_manager_extended.dart';
import '../../core/item/combat_lock_system.dart';
import '../../inventory/vector2_int.dart';

/// 인벤토리 UI 컨트롤러
class InventoryController extends ChangeNotifier {
  final TickAlignedItemManager itemManager;
  
  // UI 상태
  String? selectedItemId;
  String? errorMessage;
  bool showLockIndicator = false;
  bool isDragging = false;
  String? draggedItemId;
  Vector2Int? dragOffset;
  
  InventoryController({required this.itemManager});
  
  /// 전투 상태 확인
  bool get isInventoryLocked => itemManager.combatLock.isInCombat;
  
  /// 선택된 아이템 정보
  get selectedItem => selectedItemId != null ? itemManager.getItem(selectedItemId!) : null;
  
  /// 모든 아이템 목록
  get allItems => itemManager.getAllItems();
  
  /// 아이템 선택
  void selectItem(String? itemId) {
    selectedItemId = itemId;
    notifyListeners();
  }
  
  /// 아이템 이동 시도
  void tryMoveItem(String itemId, Vector2Int newPosition) {
    try {
      itemManager.moveItem(itemId, newPosition);
      errorMessage = null;
    } on InventoryLockedException catch (e) {
      errorMessage = e.message;
      _showLockFeedback();
    } catch (e) {
      errorMessage = '아이템 이동에 실패했습니다: $e';
      _showErrorFeedback();
    }
    notifyListeners();
  }
  
  /// 아이템 회전 시도
  void tryRotateItem(String itemId) {
    try {
      itemManager.rotateItem(itemId);
      errorMessage = null;
    } on InventoryLockedException catch (e) {
      errorMessage = e.message;
      _showLockFeedback();
    } catch (e) {
      errorMessage = '아이템 회전에 실패했습니다: $e';
      _showErrorFeedback();
    }
    notifyListeners();
  }
  
  /// 아이템 강화 시도
  void tryEnhanceItem(String itemId, int level) {
    try {
      itemManager.enhanceItem(itemId, level);
      errorMessage = null;
    } on InventoryLockedException catch (e) {
      errorMessage = e.message;
      _showLockFeedback();
    } catch (e) {
      errorMessage = '아이템 강화에 실패했습니다: $e';
      _showErrorFeedback();
    }
    notifyListeners();
  }
  
  /// 아이템 삭제 시도
  void tryRemoveItem(String itemId) {
    try {
      final success = itemManager.removeItem(itemId);
      if (success) {
        if (selectedItemId == itemId) {
          selectedItemId = null;
        }
        errorMessage = null;
      } else {
        errorMessage = '아이템을 찾을 수 없습니다.';
        _showErrorFeedback();
      }
    } on InventoryLockedException catch (e) {
      errorMessage = e.message;
      _showLockFeedback();
    } catch (e) {
      errorMessage = '아이템 삭제에 실패했습니다: $e';
      _showErrorFeedback();
    }
    notifyListeners();
  }
  
  /// 드래그 시작
  void startDrag(String itemId, Vector2Int offset) {
    if (isInventoryLocked) {
      errorMessage = '전투 중에는 아이템을 이동할 수 없습니다.';
      _showLockFeedback();
      return;
    }
    
    isDragging = true;
    draggedItemId = itemId;
    dragOffset = offset;
    notifyListeners();
  }
  
  /// 드래그 종료
  void endDrag(Vector2Int dropPosition) {
    if (isDragging && draggedItemId != null) {
      final adjustedPosition = Vector2Int(
        dropPosition.x - (dragOffset?.x ?? 0),
        dropPosition.y - (dragOffset?.y ?? 0),
      );
      
      tryMoveItem(draggedItemId!, adjustedPosition);
    }
    
    isDragging = false;
    draggedItemId = null;
    dragOffset = null;
    notifyListeners();
  }
  
  /// 드래그 취소
  void cancelDrag() {
    isDragging = false;
    draggedItemId = null;
    dragOffset = null;
    notifyListeners();
  }
  
  /// 잠금 피드백 표시
  void _showLockFeedback() {
    showLockIndicator = true;
    
    Timer(Duration(seconds: 2), () {
      showLockIndicator = false;
      errorMessage = null;
      notifyListeners();
    });
  }
  
  /// 에러 피드백 표시
  void _showErrorFeedback() {
    Timer(Duration(seconds: 3), () {
      errorMessage = null;
      notifyListeners();
    });
  }
  
  /// 에러 메시지 초기화
  void clearError() {
    errorMessage = null;
    showLockIndicator = false;
    notifyListeners();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
}
