import 'dart:typed_data';

/// 拼豆进度：**逐格"已放"**标记 + **逐色"已完成"**标记。
///
/// 为什么两种都要有：
/// - 透明板会把屏幕**完全盖住**（52×52 板 260mm > 屏幕 235×148mm），
///   拼豆过程中根本没法碰屏幕，所以逐格点击只能在**抬起板子**时补记；
///   实际拼豆时更自然的是"这一色拼完了"这种**整色标记**。
/// - 逐格标记用于纠错与补记。
///
/// 语义：[isCellPlaced] 认为"整色已完成的颜色，其所有格子都算已放"，
/// 这样整色标记后进度会立刻正确，不需要去逐格填。
final class BeadingProgress {
  BeadingProgress({required this.rows, required this.cols})
    : _placed = Uint8List(rows * cols) {
    if (rows <= 0 || cols <= 0) {
      throw ArgumentError('rows/cols 必须大于 0，实际为 $rows x $cols');
    }
  }

  final int rows;
  final int cols;

  final Uint8List _placed;
  final Set<int> _completedColors = <int>{};

  int _index(int row, int col) {
    RangeError.checkValueInInterval(row, 0, rows - 1, 'row');
    RangeError.checkValueInInterval(col, 0, cols - 1, 'col');
    return row * cols + col;
  }

  // ---------------------------------------------------------------- 逐格

  /// 该格是否被**单独**标记为已放（不含"整色已完成"带来的隐含标记）。
  bool isPlacedDirectly(int row, int col) => _placed[_index(row, col)] != 0;

  /// 设置某格的已放状态。
  void setPlaced(int row, int col, {required bool placed}) {
    _placed[_index(row, col)] = placed ? 1 : 0;
  }

  /// 切换某格的已放状态。
  void togglePlaced(int row, int col) =>
      setPlaced(row, col, placed: !isPlacedDirectly(row, col));

  /// 单独标记为已放的格数（不含整色完成带来的）。
  int get directlyPlacedCount {
    int count = 0;
    for (final int value in _placed) {
      if (value != 0) {
        count++;
      }
    }
    return count;
  }

  /// 某格是否算已放：单独标记过，**或**它所属颜色已整体完成。
  bool isCellPlaced(int colorIndex, int row, int col) =>
      isColorCompleted(colorIndex) || isPlacedDirectly(row, col);

  // ---------------------------------------------------------------- 逐色

  /// 该色是否已标记为整体完成。
  bool isColorCompleted(int colorIndex) =>
      _completedColors.contains(colorIndex);

  /// 设置某色的整体完成状态。
  void setColorCompleted(int colorIndex, {required bool completed}) {
    if (colorIndex < 0) {
      throw RangeError.value(colorIndex, 'colorIndex', '不能为负数');
    }
    if (completed) {
      _completedColors.add(colorIndex);
    } else {
      _completedColors.remove(colorIndex);
    }
  }

  /// 切换某色的整体完成状态。
  void toggleColorCompleted(int colorIndex) =>
      setColorCompleted(colorIndex, completed: !isColorCompleted(colorIndex));

  /// 已整体完成的色号集合（只读快照）。
  Set<int> get completedColors => Set<int>.unmodifiable(_completedColors);

  /// 已整体完成的颜色数量。
  int get completedColorCount => _completedColors.length;

  // ---------------------------------------------------------------- 其他

  /// 清空全部进度。
  void reset() {
    _placed.fillRange(0, _placed.length, 0);
    _completedColors.clear();
  }

  @override
  String toString() =>
      'BeadingProgress(${rows}x$cols, 单格已放=$directlyPlacedCount, '
      '整色完成=${_completedColors.length})';
}
