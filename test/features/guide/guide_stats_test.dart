import 'package:bead_light_board/data/models/bead_pattern.dart';
import 'package:bead_light_board/features/grid/domain/sample_patterns.dart';
import 'package:bead_light_board/features/guide/domain/beading_progress.dart';
import 'package:bead_light_board/features/guide/domain/guide_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 4x4 的确定性图纸：左上 4 格是色号 0，其余 12 格是色号 1。
  BeadPattern twoColorPattern() {
    final BeadPattern pattern =
        BeadPattern.filled(
            rows: 4,
            cols: 4,
            paletteId: 'test_fixture',
            colorIndex: 1,
          )
          ..setColorIndexAt(0, 0, 0)
          ..setColorIndexAt(0, 1, 0)
          ..setColorIndexAt(1, 0, 0)
          ..setColorIndexAt(1, 1, 0);
    return pattern;
  }

  group('基本统计', () {
    test('初始进度为 0，当前色剩余＝总数', () {
      final BeadPattern pattern = twoColorPattern();
      final BeadingProgress progress = BeadingProgress(rows: 4, cols: 4);

      final GuideStats stats = computeGuideStats(
        pattern: pattern,
        progress: progress,
        activeColorIndex: 0,
      );

      expect(stats.totalCells, 16);
      expect(stats.placedCells, 0);
      expect(stats.percent, 0);
      expect(stats.fraction, 0);
      expect(stats.usedColorCount, 2);
      expect(stats.completedUsedColorCount, 0);
      expect(stats.activeColorTotal, 4);
      expect(stats.activeColorPlaced, 0);
      expect(stats.activeColorRemaining, 4);
      expect(stats.isComplete, isFalse);
    });

    test('逐格标记会同时反映到总进度与当前色剩余', () {
      final BeadPattern pattern = twoColorPattern();
      final BeadingProgress progress = BeadingProgress(rows: 4, cols: 4)
        ..togglePlaced(0, 0)
        ..togglePlaced(1, 1);

      final GuideStats stats = computeGuideStats(
        pattern: pattern,
        progress: progress,
        activeColorIndex: 0,
      );

      expect(stats.placedCells, 2);
      expect(stats.activeColorPlaced, 2);
      expect(stats.activeColorRemaining, 2);
      expect(stats.percent, 13); // 2/16 = 12.5% -> 四舍五入 13
    });

    test('整色完成会一次算满该色的所有格子', () {
      final BeadPattern pattern = twoColorPattern();
      final BeadingProgress progress = BeadingProgress(rows: 4, cols: 4)
        ..setColorCompleted(1, completed: true);

      final GuideStats stats = computeGuideStats(
        pattern: pattern,
        progress: progress,
        activeColorIndex: 1,
      );

      expect(stats.placedCells, 12);
      expect(stats.percent, 75);
      expect(stats.completedUsedColorCount, 1);
      expect(stats.activeColorRemaining, 0);
      // 色号 0 还没做
      expect(stats.activeColorIndex, 1);
      expect(
        computeGuideStats(
          pattern: pattern,
          progress: progress,
          activeColorIndex: 0,
        ).activeColorRemaining,
        4,
      );
    });

    test('全部完成时 isComplete 为真、百分比为 100', () {
      final BeadPattern pattern = twoColorPattern();
      final BeadingProgress progress = BeadingProgress(rows: 4, cols: 4)
        ..setColorCompleted(0, completed: true)
        ..setColorCompleted(1, completed: true);

      final GuideStats stats = computeGuideStats(
        pattern: pattern,
        progress: progress,
        activeColorIndex: null,
      );

      expect(stats.placedCells, 16);
      expect(stats.percent, 100);
      expect(stats.isComplete, isTrue);
      expect(stats.completedUsedColorCount, 2);
      // 未选色时当前色相关字段为 0，且不参与剩余计算
      expect(stats.activeColorTotal, 0);
      expect(stats.activeColorRemaining, 0);
    });

    test('未选色时不影响总进度', () {
      final BeadPattern pattern = twoColorPattern();
      final BeadingProgress progress = BeadingProgress(rows: 4, cols: 4)
        ..togglePlaced(2, 2);

      final GuideStats withActive = computeGuideStats(
        pattern: pattern,
        progress: progress,
        activeColorIndex: 0,
      );
      final GuideStats withoutActive = computeGuideStats(
        pattern: pattern,
        progress: progress,
        activeColorIndex: null,
      );

      expect(withoutActive.placedCells, withActive.placedCells);
      expect(withoutActive.percent, withActive.percent);
    });

    test('尺寸不一致时明确报错，而不是算出可疑数字', () {
      final BeadPattern pattern = twoColorPattern();
      final BeadingProgress progress = BeadingProgress(rows: 3, cols: 3);
      expect(
        () => computeGuideStats(
          pattern: pattern,
          progress: progress,
          activeColorIndex: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('真实合成图纸上的统计自洽', () {
    test('用量最多的颜色，其总数等于 usageByColorIndex 的第一个值', () {
      final BeadPattern pattern = buildSyntheticPattern(rows: 21, cols: 21);
      final BeadingProgress progress = BeadingProgress(rows: 21, cols: 21);
      final Map<int, int> usage = pattern.usageByColorIndex;
      final int topColor = usage.keys.first;

      final GuideStats stats = computeGuideStats(
        pattern: pattern,
        progress: progress,
        activeColorIndex: topColor,
      );

      expect(stats.activeColorTotal, usage[topColor]);
      expect(stats.usedColorCount, usage.length);
      expect(stats.totalCells, 21 * 21);
    });

    test('把用到的颜色全部标记完成后，进度正好 100%', () {
      final BeadPattern pattern = buildSyntheticPattern(rows: 21, cols: 21);
      final BeadingProgress progress = BeadingProgress(rows: 21, cols: 21);
      for (final int colorIndex in pattern.usageByColorIndex.keys) {
        progress.setColorCompleted(colorIndex, completed: true);
      }

      final GuideStats stats = computeGuideStats(
        pattern: pattern,
        progress: progress,
        activeColorIndex: null,
      );
      expect(stats.placedCells, stats.totalCells);
      expect(stats.percent, 100);
      expect(stats.completedUsedColorCount, stats.usedColorCount);
    });
  });
}
