import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'vector2_int.dart';
import 'inventory_item.dart';

/// 그리드 레이아웃 관련 상수
class GridConstants {
  /// 셀 사이의 그리드 선 두께 (기본값 1.0 픽셀)
  static const double defaultLineWidth = 1.0;

  /// 디버그 계측/오버레이 토글 (런타임에서 true로 바꿔 사용)
  static bool debugGridMetrics = kDebugMode;
  static bool debugGridOverlay = false;

  /// PC 테스트용 키보드 컨트롤(회전) 토글
  /// - true일 때만 Ctrl 키로 드래그 중 아이템을 회전
  static bool debugKeyboardControls = kDebugMode;

  /// 키보드 입력 수신용 포커스 노드(디버그 컨트롤)
  /// - CombatInventoryGrid가 생성/해제 시 설정/정리한다.
  /// - RewardScreen 등에서 드래그 시작 시 requestFocus() 용도로만 사용한다.
  static FocusNode? keyboardFocusNode;

  /// "한 번만 출력"을 위한 키 저장소
  static final Set<String> _printedOnceKeys = <String>{};

  static void debugPrintOnce(String key, String message) {
    if (!debugGridMetrics) return;
    if (_printedOnceKeys.add(key)) {
      debugPrint(message);
    }
  }

  /// 서로 다른 레이아웃 영역의 메트릭을 교차 비교하기 위한 스냅샷(디버그용)
  static GridDebugSnapshot? lastRewardPreviewSnapshot;
  static GridDebugSnapshot? lastCombatInventorySnapshot;

  /// 현재 드래그 중인 아이템 식별자/참조 (키보드 회전용)
  /// - Reward 드래그는 RewardScreen에서 설정/해제
  /// - Inventory 내부 드래그는 (있다면) 해당 UI에서 설정하거나, InventorySystem.dragState를 사용
  static String? draggingItemId;
  static InventoryItem? draggingItemRef;
  static bool? draggingFromReward;

  /// Ctrl 회전 시, 드래그 프리뷰(overlay feedback) 갱신 트리거
  /// - Draggable.feedback는 드래그 시작 시 고정될 수 있으므로, ValueListenable로 내부 rebuild 유도
  static final ValueNotifier<int> keyboardRotateTick = ValueNotifier<int>(0);

  /// DragTarget(onMove)에서 기록하는 마지막 드롭 셀/원점 셀(디버그/로그용)
  static final Map<String, Vector2Int> lastDropCellByItemId = <String, Vector2Int>{};
  static final Map<String, Vector2Int> lastOriginCellByItemId = <String, Vector2Int>{};

  /// DragTarget(onMove/onWillAccept)에서 계산한 마지막 "배치 가능 여부"(프리뷰 오버레이용)
  /// - 드래그 중에는 절대 gridMap을 mutate하지 않고, 판정 결과만 상태로 보관한다.
  static final Map<String, bool> lastCanPlaceByItemId = <String, bool>{};

  /// Reward → Inventory 드롭 시, "드래그 시작점이 아이템 로컬에서 어느 셀인지" 저장
  /// - key: itemId
  /// - value: anchor cell within item local mask coords
  static final Map<String, Vector2Int> rewardDragAnchorCellByItemId =
      <String, Vector2Int>{};

  /// Reward 드래그 트랜잭션 식별자 (itemId -> seq)
  /// - Draggable.wasAccepted 불일치 디버깅/SSOT 판정용
  static final Map<String, int> rewardDragSeqByItemId = <String, int>{};

  /// DragTarget에서 기록하는 최종 배치 결과(SSOT) (itemId -> placed)
  static final Map<String, bool> rewardDropPlacedByItemId = <String, bool>{};

  /// 드롭 디버그(1회)용: 마지막으로 로그한 dropCell (itemId -> cell)
  static final Map<String, Vector2Int> rewardDropLastLoggedCellByItemId =
      <String, Vector2Int>{};
}

class GridDebugSnapshot {
  final String source;
  final double maxWidth;
  final double maxHeight;
  final Size cellSize;
  final double gridLineWidth;

  const GridDebugSnapshot({
    required this.source,
    required this.maxWidth,
    required this.maxHeight,
    required this.cellSize,
    required this.gridLineWidth,
  });

  double get pitchW => cellSize.width + gridLineWidth;
  double get pitchH => cellSize.height + gridLineWidth;
}


















