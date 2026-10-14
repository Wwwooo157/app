import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:bead_light_board/features/grid/domain/peg_metrics.dart';

/// 一个格子（图纸坐标，单位是格子而不是像素）。
final class GridCell {
  const GridCell({required this.row, required this.col});

  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is GridCell && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'GridCell($row, $col)';
}

/// 一段可见的格子范围（闭区间，含首含尾）。
final class GridRange {
  const GridRange({
    required this.firstRow,
    required this.lastRow,
    required this.firstCol,
    required this.lastCol,
  });

  static const GridRange empty = GridRange(
    firstRow: 0,
    lastRow: -1,
    firstCol: 0,
    lastCol: -1,
  );

  final int firstRow;
  final int lastRow;
  final int firstCol;
  final int lastCol;

  bool get isEmpty => lastRow < firstRow || lastCol < firstCol;

  int get rowCount => isEmpty ? 0 : lastRow - firstRow + 1;

  int get colCount => isEmpty ? 0 : lastCol - firstCol + 1;

  /// 范围内格子总数（渲染时用来核对画了多少格）。
  int get cellCount => rowCount * colCount;

  @override
  bool operator ==(Object other) =>
      other is GridRange &&
      other.firstRow == firstRow &&
      other.lastRow == lastRow &&
      other.firstCol == firstCol &&
      other.lastCol == lastCol;

  @override
  int get hashCode => Object.hash(firstRow, lastRow, firstCol, lastCol);

  @override
  String toString() =>
      'GridRange(rows $firstRow..$lastRow, cols $firstCol..$lastCol)';
}

/// 网格在画布上的放置方式：把格子坐标映射到画布坐标。
///
/// 只由两件事决定：[origin]（格子 (0,0) 左上角在画布上的位置）
/// 与 [metrics]（每格多少逻辑像素）。平移窗口 = 改 [origin]；
/// 校准 = 微调 [origin] 与 [metrics]。
final class GridTransform {
  const GridTransform({required this.origin, required this.metrics});

  /// 格子 (0,0) 的左上角在画布坐标系中的位置（逻辑像素）。
  final Offset origin;

  final PegMetrics metrics;

  double get pxPerPegX => metrics.pxPerPegX;

  double get pxPerPegY => metrics.pxPerPegY;

  /// 整张图纸的逻辑尺寸。
  Size patternSize(int rows, int cols) =>
      Size(cols * pxPerPegX, rows * pxPerPegY);

  /// 某个格子的矩形区域。
  Rect cellRect(int row, int col) => Rect.fromLTWH(
    origin.dx + col * pxPerPegX,
    origin.dy + row * pxPerPegY,
    pxPerPegX,
    pxPerPegY,
  );

  /// 整张图纸的矩形区域（用于画边框、判断是否需要平移）。
  Rect patternRect(int rows, int cols) =>
      Rect.fromLTWH(origin.dx, origin.dy, cols * pxPerPegX, rows * pxPerPegY);

  /// 命中测试：画布坐标 -> 格子；点在图纸外时返回 null。
  GridCell? cellAt(Offset position, {required int rows, required int cols}) {
    final double fx = (position.dx - origin.dx) / pxPerPegX;
    final double fy = (position.dy - origin.dy) / pxPerPegY;
    if (fx < 0 || fy < 0) {
      return null;
    }
    final int col = fx.floor();
    final int row = fy.floor();
    if (row >= rows || col >= cols) {
      return null;
    }
    return GridCell(row: row, col: col);
  }

  /// 落在画布内、且属于图纸的格子范围。渲染时只画这个范围。
  GridRange visibleRange(
    Size canvasSize, {
    required int rows,
    required int cols,
  }) {
    final double x0 = (0 - origin.dx) / pxPerPegX;
    final double x1 = (canvasSize.width - origin.dx) / pxPerPegX;
    final double y0 = (0 - origin.dy) / pxPerPegY;
    final double y1 = (canvasSize.height - origin.dy) / pxPerPegY;

    // 与画布相交的格子：左端按 floor，右端按 ceil-1。
    // 右端若也用 floor，会多算一列（恰好落在右边界之外的下一格其实不可见）。
    final int rawFirstCol = x0.floor();
    final int rawLastCol = x1.ceil() - 1;
    final int rawFirstRow = y0.floor();
    final int rawLastRow = y1.ceil() - 1;

    if (rawLastCol < 0 || rawFirstCol > cols - 1) {
      return GridRange.empty;
    }
    if (rawLastRow < 0 || rawFirstRow > rows - 1) {
      return GridRange.empty;
    }

    return GridRange(
      firstRow: rawFirstRow.clamp(0, rows - 1),
      lastRow: rawLastRow.clamp(0, rows - 1),
      firstCol: rawFirstCol.clamp(0, cols - 1),
      lastCol: rawLastCol.clamp(0, cols - 1),
    );
  }

  /// 平移（拖动窗口）。
  GridTransform panBy(Offset delta) =>
      GridTransform(origin: origin + delta, metrics: metrics);

  /// 直接把 origin 放到指定位置。
  GridTransform withOrigin(Offset newOrigin) =>
      GridTransform(origin: newOrigin, metrics: metrics);

  /// 换一套尺寸参数（校准 / 切换 1:1 与总览）。
  GridTransform withMetrics(PegMetrics newMetrics) =>
      GridTransform(origin: origin, metrics: newMetrics);

  /// 1:1 模式下的初始位置：格子 (0,0) 左上角对齐到画布左上角 + [margin]。
  factory GridTransform.alignedToTopLeft({
    required PegMetrics metrics,
    double margin = 0,
  }) => GridTransform(origin: Offset(margin, margin), metrics: metrics);

  /// 把整张图纸缩放到画布内并居中（总览模式，**不是 1:1**）。
  factory GridTransform.fit({
    required Size canvasSize,
    required int rows,
    required int cols,
    required PegMetrics metrics,
    double padding = 8,
  }) {
    if (rows <= 0 || cols <= 0) {
      throw ArgumentError('rows/cols 必须大于 0，实际为 $rows x $cols');
    }
    final double availableW = math.max(1, canvasSize.width - padding * 2);
    final double availableH = math.max(1, canvasSize.height - padding * 2);
    final double factor = math.min(
      availableW / (cols * metrics.pxPerPegX),
      availableH / (rows * metrics.pxPerPegY),
    );
    final PegMetrics scaled = metrics.scaled(factor);
    final double width = cols * scaled.pxPerPegX;
    final double height = rows * scaled.pxPerPegY;
    return GridTransform(
      origin: Offset(
        (canvasSize.width - width) / 2,
        (canvasSize.height - height) / 2,
      ),
      metrics: scaled,
    );
  }

  @override
  String toString() =>
      'GridTransform(origin=$origin, pxPerPeg=${pxPerPegX.toStringAsFixed(2)}x'
      '${pxPerPegY.toStringAsFixed(2)})';
}
