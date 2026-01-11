import 'package:flutter/widgets.dart';
import 'grid_constants.dart';
import 'vector2_int.dart';

/// 그리드 좌표 변환 헬퍼
///
/// 좌표계 기준:
/// - 로컬 (0,0) = 그리드 좌상단 셀 (0,0)
/// - gridLineWidth: 셀 사이의 그리드 선(간격) 두께
class GridCoordinateTransformer {
  final Size cellSize;
  final double gridLineWidth;

  const GridCoordinateTransformer({
    required this.cellSize,
    this.gridLineWidth = GridConstants.defaultLineWidth,
  });

  /// 그리드 셀을 로컬 좌표로 변환
  Offset cellToLocal(Vector2Int cell) {
    return Offset(
      cell.x * (cellSize.width + gridLineWidth),
      cell.y * (cellSize.height + gridLineWidth),
    );
  }

  /// 로컬 좌표를 그리드 셀로 변환
  ///
  /// 경계 처리 정책:
  /// - floor()를 사용하여 아래/왼쪽 셀에 할당
  /// - 음수 좌표 또는 그리드 범위 밖 좌표에 대해서는
  ///   음수 또는 범위 밖 인덱스를 반환하며,
  ///   유효성 검사는 호출자가 수행해야 함.
  Vector2Int localToCell(Offset local) {
    final colSpacing = cellSize.width + gridLineWidth;
    final rowSpacing = cellSize.height + gridLineWidth;

    final col = (local.dx / colSpacing).floor();
    final row = (local.dy / rowSpacing).floor();

    return Vector2Int(col, row);
  }

  /// 단일 셀의 Rect 반환
  Rect cellToRect(Vector2Int cell) {
    final topLeft = cellToLocal(cell);
    return Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      cellSize.width,
      cellSize.height,
    );
  }

  /// 아이템이 여러 셀을 차지하는 경우의 Rect 반환
  /// 
  /// width, height는 셀 개수입니다.
  /// 실제 픽셀 크기 = width * cellSize.width + (width - 1) * gridLineWidth
  Rect itemToRect(Vector2Int position, int width, int height) {
    final topLeft = cellToLocal(position);
    final itemWidth = width * cellSize.width + (width - 1) * gridLineWidth;
    final itemHeight = height * cellSize.height + (height - 1) * gridLineWidth;
    return Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      itemWidth,
      itemHeight,
    );
  }

  /// Footprint 셀들을 Rect 리스트로 변환
  List<Rect> footprintToRects(Iterable<Vector2Int> cells) {
    return cells.map(cellToRect).toList();
  }

  /// 미니맵/프리뷰용 스케일 적용 버전 생성
  GridCoordinateTransformer scaled(double scale) {
    return GridCoordinateTransformer(
      cellSize: Size(
        cellSize.width * scale,
        cellSize.height * scale,
      ),
      gridLineWidth: gridLineWidth * scale,
    );
  }
}

