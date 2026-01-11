import 'package:flutter/widgets.dart';
import 'grid_constants.dart';

/// 그리드 레이아웃 계산 헬퍼
class GridLayoutHelper {
  /// LayoutBuilder constraints로부터 셀 크기를 계산합니다.
  /// 
  /// - gridWidth / gridHeight: 그리드의 가로/세로 셀 개수
  /// - gridLineWidth: 셀 사이 그리드 선 두께 (기본값 1.0)
  /// 
  /// 계산 공식:
  /// availableWidth = maxWidth - (gridWidth - 1) * gridLineWidth
  /// cellWidth = availableWidth / gridWidth
  static Size calculateCellSize(
    BoxConstraints constraints,
    int gridWidth,
    int gridHeight, {
    double gridLineWidth = GridConstants.defaultLineWidth,
  }) {
    final availableWidth =
        constraints.maxWidth - (gridWidth - 1) * gridLineWidth;
    final availableHeight =
        constraints.maxHeight - (gridHeight - 1) * gridLineWidth;

    return Size(
      availableWidth / gridWidth,
      availableHeight / gridHeight,
    );
  }
}


















