import 'package:bead_light_board/data/models/bead_pattern.dart';
import 'package:bead_light_board/features/guide/domain/beading_progress.dart';

/// 引导用的统计快照。
final class GuideStats {
  const GuideStats({
    required this.totalCells,
    required this.placedCells,
    required this.usedColorCount,
    required this.completedUsedColorCount,
    required this.activeColorIndex,
    required this.activeColorTotal,
    required this.activeColorPlaced,
  });

  /// 图纸总格数。
  final int totalCells;

  /// 已放格数（含"整色已完成"带来的）。
  final int placedCells;

  /// 图纸实际用到的色号数量。
  final int usedColorCount;

  /// 已整体完成、且图纸确实用到的色号数量。
  final int completedUsedColorCount;

  /// 当前引导的色号索引（未选时为 null）。
  final int? activeColorIndex;

  /// 当前色在图纸里的总颗数。
  final int activeColorTotal;

  /// 当前色已放颗数。
  final int activeColorPlaced;

  /// 当前色还剩多少颗。
  int get activeColorRemaining => activeColorTotal - activeColorPlaced;

  /// 总进度 0.0 ~ 1.0。
  double get fraction => totalCells == 0 ? 0 : placedCells / totalCells;

  /// 总进度百分比（四舍五入）。
  int get percent => (fraction * 100).round();

  /// 是否全部完成。
  bool get isComplete => totalCells > 0 && placedCells >= totalCells;

  @override
  String toString() =>
      'GuideStats($placedCells/$totalCells, $percent%, '
      '当前色 ${activeColorIndex == null ? "-" : "$activeColorPlaced/$activeColorTotal"})';
}

/// 计算统计快照。
///
/// 一次遍历同时得到：各色总数、各色已放数、总已放数。52×52 只有 2704 次循环，
/// 每帧算一次也不会有性能问题（实际只在状态变化时算）。
GuideStats computeGuideStats({
  required BeadPattern pattern,
  required BeadingProgress progress,
  required int? activeColorIndex,
}) {
  if (progress.rows != pattern.rows || progress.cols != pattern.cols) {
    throw ArgumentError(
      '进度与图纸尺寸不一致：进度 ${progress.rows}x${progress.cols}，'
      '图纸 ${pattern.rows}x${pattern.cols}',
    );
  }

  final Map<int, int> totalByColor = <int, int>{};
  final Map<int, int> placedByColor = <int, int>{};
  int placedCells = 0;

  for (int row = 0; row < pattern.rows; row++) {
    for (int col = 0; col < pattern.cols; col++) {
      final int colorIndex = pattern.colorIndexAt(row, col);
      totalByColor[colorIndex] = (totalByColor[colorIndex] ?? 0) + 1;
      if (progress.isCellPlaced(colorIndex, row, col)) {
        placedByColor[colorIndex] = (placedByColor[colorIndex] ?? 0) + 1;
        placedCells++;
      }
    }
  }

  int completedUsed = 0;
  for (final int colorIndex in totalByColor.keys) {
    if (progress.isColorCompleted(colorIndex)) {
      completedUsed++;
    }
  }

  return GuideStats(
    totalCells: pattern.length,
    placedCells: placedCells,
    usedColorCount: totalByColor.length,
    completedUsedColorCount: completedUsed,
    activeColorIndex: activeColorIndex,
    activeColorTotal: activeColorIndex == null
        ? 0
        : (totalByColor[activeColorIndex] ?? 0),
    activeColorPlaced: activeColorIndex == null
        ? 0
        : (placedByColor[activeColorIndex] ?? 0),
  );
}
