import 'package:bead_light_board/data/models/bead_pattern.dart';

/// **开发预览与测试专用**的合成图纸。
///
/// 为什么需要它：S2/S3（图片导入与颜色量化）还没做，而网格渲染是最高风险、
/// 最该先打通的部分。这些函数用夹具色卡（`test_fixture.json`，T01–T08，
/// **非真实色号**）生成确定性的图案，让网格渲染与对齐可以先独立验证。
///
/// 严禁把这些图案当成真实图纸展示给使用者。
enum SyntheticKind {
  /// 边框 + 十字 + 两条对角线：**最适合肉眼校验 1:1 对齐**，
  /// 因为斜线一旦错位会立刻看出来。
  diagonalCross,

  /// 横向色带：便于检查行高是否均匀。
  bands,

  /// 棋盘格：便于检查格子边界与线宽。
  checker,
}

/// 生成一张合成图纸。
///
/// [paletteSize] 为夹具色卡的色号数量（默认 8，对应 T01–T08）。
BeadPattern buildSyntheticPattern({
  required int rows,
  required int cols,
  SyntheticKind kind = SyntheticKind.diagonalCross,
  int paletteSize = 8,
}) {
  if (paletteSize <= 0) {
    throw ArgumentError.value(paletteSize, 'paletteSize', '必须大于 0');
  }
  final BeadPattern pattern = BeadPattern.filled(
    rows: rows,
    cols: cols,
    paletteId: 'test_fixture',
  );

  for (int row = 0; row < rows; row++) {
    for (int col = 0; col < cols; col++) {
      final int index = switch (kind) {
        SyntheticKind.diagonalCross => _diagonalCrossIndex(
          row,
          col,
          rows,
          cols,
        ),
        SyntheticKind.bands => (row * paletteSize) ~/ rows,
        SyntheticKind.checker => ((row ~/ 2) + (col ~/ 2)) % paletteSize,
      };
      pattern.setColorIndexAt(row, col, index % paletteSize);
    }
  }
  return pattern;
}

int _diagonalCrossIndex(int row, int col, int rows, int cols) {
  const int border = 0;
  const int cross = 1;
  const int diagA = 2;
  const int diagB = 3;
  const int background = 4;

  if (row == 0 || col == 0 || row == rows - 1 || col == cols - 1) {
    return border;
  }
  final int centerRow = rows ~/ 2;
  final int centerCol = cols ~/ 2;
  if (row == centerRow || col == centerCol) {
    return cross;
  }
  // 两条对角线：用交叉相乘判断"落在对角线上"，避免浮点误差。
  final int dx = col * (rows - 1);
  final int dy = row * (cols - 1);
  final int tolerance = (rows + cols) ~/ 2;
  if ((dx - dy).abs() <= tolerance) {
    return diagA;
  }
  if ((dx + dy - (cols - 1) * (rows - 1)).abs() <= tolerance) {
    return diagB;
  }
  return background;
}
