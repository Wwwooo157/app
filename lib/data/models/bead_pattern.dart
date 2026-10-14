import 'dart:typed_data';

/// 一张拼豆图纸。
///
/// 存储方式：把每个格子的颜色存成**色卡索引**（`Uint16List`），而不是直接存 RGB。
/// 好处：52x52 只有 2704 个 16 位整数（约 5KB），比较、统计、撤销都快，
/// 换色卡时也不用改数据结构。
final class BeadPattern {
  BeadPattern._(this.rows, this.cols, this.paletteId, this._colorIndex);

  /// 新建一张单色图纸（[colorIndex] 为整张纸填充的色卡索引）。
  factory BeadPattern.filled({
    required int rows,
    required int cols,
    required String paletteId,
    int colorIndex = 0,
  }) {
    _checkDimensions(rows, cols);
    final Uint16List buffer = Uint16List(rows * cols);
    if (colorIndex != 0) {
      buffer.fillRange(0, buffer.length, colorIndex);
    }
    return BeadPattern._(rows, cols, paletteId, buffer);
  }

  /// 用已有的索引数组构造（长度必须等于 rows * cols）。
  factory BeadPattern.fromColorIndex({
    required int rows,
    required int cols,
    required String paletteId,
    required Uint16List colorIndex,
  }) {
    _checkDimensions(rows, cols);
    if (colorIndex.length != rows * cols) {
      throw ArgumentError.value(
        colorIndex.length,
        'colorIndex.length',
        '必须等于 rows * cols = ${rows * cols}',
      );
    }
    // 复制一份，避免外部后续修改影响图纸内部状态。
    return BeadPattern._(
      rows,
      cols,
      paletteId,
      Uint16List.fromList(colorIndex),
    );
  }

  final int rows;
  final int cols;

  /// 该图纸使用的色卡 id。
  final String paletteId;

  final Uint16List _colorIndex;

  /// 格子总数。
  int get length => _colorIndex.length;

  /// 底层索引缓冲的直接视图（渲染时用它避免每帧复制）。
  ///
  /// 注意：这是**可变**视图，调用方只读、不要修改；要改请用 [setColorIndexAt]。
  Uint16List get colorIndexView => Uint16List.view(_colorIndex.buffer);

  static void _checkDimensions(int rows, int cols) {
    if (rows <= 0 || cols <= 0) {
      throw ArgumentError('rows/cols 必须大于 0，实际为 $rows x $cols');
    }
  }

  (int, int) _validatePosition(int row, int col) {
    RangeError.checkValueInInterval(row, 0, rows - 1, 'row');
    RangeError.checkValueInInterval(col, 0, cols - 1, 'col');
    return (row, col);
  }

  /// 行列转一维索引。
  int indexAt(int row, int col) {
    _validatePosition(row, col);
    return row * cols + col;
  }

  /// 取某格的色卡索引。
  int colorIndexAt(int row, int col) => _colorIndex[indexAt(row, col)];

  /// 写入某格的色卡索引。
  void setColorIndexAt(int row, int col, int colorIndex) {
    if (colorIndex < 0 || colorIndex > 0xFFFF) {
      throw RangeError.range(colorIndex, 0, 0xFFFF, 'colorIndex');
    }
    _colorIndex[indexAt(row, col)] = colorIndex;
  }

  /// 某色号（索引）在图纸里出现的次数。
  int countOf(int colorIndex) {
    int count = 0;
    for (final int value in _colorIndex) {
      if (value == colorIndex) {
        count++;
      }
    }
    return count;
  }

  /// 各色号用量统计：key 为色卡索引，value 为颗数。按颗数从多到少排序。
  Map<int, int> get usageByColorIndex {
    final Map<int, int> usage = <int, int>{};
    for (final int value in _colorIndex) {
      usage[value] = (usage[value] ?? 0) + 1;
    }
    final List<MapEntry<int, int>> entries = usage.entries.toList()
      ..sort((MapEntry<int, int> a, MapEntry<int, int> b) {
        final int byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return <int, int>{
      for (final MapEntry<int, int> entry in entries) entry.key: entry.value,
    };
  }

  /// 图纸中实际用到的色号数量。
  int get usedColorCount => usageByColorIndex.length;

  /// 深拷贝（S10 撤销/重做用）。
  BeadPattern copy() =>
      BeadPattern._(rows, cols, paletteId, Uint16List.fromList(_colorIndex));

  @override
  String toString() =>
      'BeadPattern(${rows}x$cols, palette=$paletteId, used=$usedColorCount)';
}
