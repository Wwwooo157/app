import 'package:bead_light_board/data/models/bead_pattern.dart';

/// 对称绘制模式。
///
/// 拼豆图纸大量使用对称图案（爱心、星星、logo），逐格点两遍很折磨人。
enum SymmetryMode {
  none('无'),
  leftRight('左右'),
  topBottom('上下'),
  quad('四向');

  const SymmetryMode(this.label);

  final String label;
}

/// 一次格子改动：撤销/重做的最小单位。
final class CellChange {
  const CellChange({
    required this.row,
    required this.col,
    required this.before,
    required this.after,
  });

  final int row;
  final int col;
  final int before;
  final int after;

  /// 反向改动（撤销时写回 before，重做时写回 after）。
  CellChange get reversed =>
      CellChange(row: row, col: col, before: after, after: before);

  @override
  bool operator ==(Object other) =>
      other is CellChange &&
      other.row == row &&
      other.col == col &&
      other.before == before &&
      other.after == after;

  @override
  int get hashCode => Object.hash(row, col, before, after);

  @override
  String toString() => 'Cell($row,$col: $before -> $after)';
}

/// 图纸编辑操作。
///
/// 全部是**纯函数**：就地修改 [BeadPattern]，并把"实际发生的改动"作为
/// [CellChange] 列表返回 —— 这样撤销栈只存稀疏差异，不必整图快照。
abstract final class PatternEditor {
  /// 把一个格子按对称模式展开成所有对应格子（已去重）。
  static List<({int row, int col})> symmetricCells({
    required int row,
    required int col,
    required int rows,
    required int cols,
    required SymmetryMode symmetry,
  }) {
    final int mirrorCol = cols - 1 - col;
    final int mirrorRow = rows - 1 - row;
    final List<({int row, int col})> cells = <({int row, int col})>[
      (row: row, col: col),
    ];
    void add(int r, int c) {
      for (final ({int row, int col}) existing in cells) {
        if (existing.row == r && existing.col == c) {
          return; // 落在对称轴上时会重复，去重
        }
      }
      cells.add((row: r, col: c));
    }

    switch (symmetry) {
      case SymmetryMode.none:
        break;
      case SymmetryMode.leftRight:
        add(row, mirrorCol);
      case SymmetryMode.topBottom:
        add(mirrorRow, col);
      case SymmetryMode.quad:
        add(row, mirrorCol);
        add(mirrorRow, col);
        add(mirrorRow, mirrorCol);
    }
    return cells;
  }

  /// 画笔：把一格（含对称点）改成 [colorIndex]。
  ///
  /// 返回**实际发生变化**的格子；已经是目标色的格不计入，
  /// 免得撤销栈里堆满"什么都没改"的空操作。
  static List<CellChange> paint(
    BeadPattern pattern, {
    required int row,
    required int col,
    required int colorIndex,
    SymmetryMode symmetry = SymmetryMode.none,
  }) {
    if (!_inBounds(pattern, row, col)) {
      return const <CellChange>[];
    }
    final List<CellChange> changes = <CellChange>[];
    for (final ({int row, int col}) cell in symmetricCells(
      row: row,
      col: col,
      rows: pattern.rows,
      cols: pattern.cols,
      symmetry: symmetry,
    )) {
      final int before = pattern.colorIndexAt(cell.row, cell.col);
      if (before == colorIndex) {
        continue;
      }
      pattern.setColorIndexAt(cell.row, cell.col, colorIndex);
      changes.add(
        CellChange(
          row: cell.row,
          col: cell.col,
          before: before,
          after: colorIndex,
        ),
      );
    }
    return changes;
  }

  /// 拖动画笔：在两点之间**插值**后绘制。
  ///
  /// 手指快速划过时，两次回调之间可能隔着好几格；不插值就会出现
  /// "断断续续的点"。用 Bresenham 保证笔画连续。
  static List<CellChange> paintLine(
    BeadPattern pattern, {
    required int fromRow,
    required int fromCol,
    required int toRow,
    required int toCol,
    required int colorIndex,
    SymmetryMode symmetry = SymmetryMode.none,
  }) {
    final List<CellChange> changes = <CellChange>[];
    for (final ({int row, int col}) point in bresenham(
      fromRow: fromRow,
      fromCol: fromCol,
      toRow: toRow,
      toCol: toCol,
    )) {
      changes.addAll(
        paint(
          pattern,
          row: point.row,
          col: point.col,
          colorIndex: colorIndex,
          symmetry: symmetry,
        ),
      );
    }
    return changes;
  }

  /// 两点之间的整数格点（Bresenham 直线）。
  static List<({int row, int col})> bresenham({
    required int fromRow,
    required int fromCol,
    required int toRow,
    required int toCol,
  }) {
    final List<({int row, int col})> points = <({int row, int col})>[];
    int row = fromRow;
    int col = fromCol;
    final int deltaRow = (toRow - fromRow).abs();
    final int deltaCol = (toCol - fromCol).abs();
    final int stepRow = fromRow < toRow ? 1 : -1;
    final int stepCol = fromCol < toCol ? 1 : -1;
    int error = deltaCol - deltaRow;

    while (true) {
      points.add((row: row, col: col));
      if (row == toRow && col == toCol) {
        break;
      }
      // 防止传进来的坐标异常时死循环
      if (points.length > 100000) {
        break;
      }
      final int doubled = error * 2;
      if (doubled > -deltaRow) {
        error -= deltaRow;
        col += stepCol;
      }
      if (doubled < deltaCol) {
        error += deltaCol;
        row += stepRow;
      }
    }
    return points;
  }

  /// 油漆桶：把与起点**四连通且同色**的区域整体改成 [colorIndex]。
  static List<CellChange> floodFill(
    BeadPattern pattern, {
    required int row,
    required int col,
    required int colorIndex,
  }) {
    if (!_inBounds(pattern, row, col)) {
      return const <CellChange>[];
    }
    final int target = pattern.colorIndexAt(row, col);
    if (target == colorIndex) {
      return const <CellChange>[];
    }

    final List<CellChange> changes = <CellChange>[];
    final List<({int row, int col})> stack = <({int row, int col})>[
      (row: row, col: col),
    ];
    while (stack.isNotEmpty) {
      final ({int row, int col}) cell = stack.removeLast();
      if (!_inBounds(pattern, cell.row, cell.col)) {
        continue;
      }
      if (pattern.colorIndexAt(cell.row, cell.col) != target) {
        continue; // 已改过或本来就不是这个色
      }
      pattern.setColorIndexAt(cell.row, cell.col, colorIndex);
      changes.add(
        CellChange(
          row: cell.row,
          col: cell.col,
          before: target,
          after: colorIndex,
        ),
      );
      stack
        ..add((row: cell.row - 1, col: cell.col))
        ..add((row: cell.row + 1, col: cell.col))
        ..add((row: cell.row, col: cell.col - 1))
        ..add((row: cell.row, col: cell.col + 1));
    }
    return changes;
  }

  /// 吸管：读某格的颜色（越界返回 null）。
  static int? pick(BeadPattern pattern, int row, int col) =>
      _inBounds(pattern, row, col) ? pattern.colorIndexAt(row, col) : null;

  /// 把一批改动写回图纸（撤销用 before，重做用 after）。
  static void applyChanges(
    BeadPattern pattern,
    Iterable<CellChange> changes, {
    required bool useBefore,
  }) {
    for (final CellChange change in changes) {
      if (!_inBounds(pattern, change.row, change.col)) {
        continue;
      }
      pattern.setColorIndexAt(
        change.row,
        change.col,
        useBefore ? change.before : change.after,
      );
    }
  }

  static bool _inBounds(BeadPattern pattern, int row, int col) =>
      row >= 0 && row < pattern.rows && col >= 0 && col < pattern.cols;
}
