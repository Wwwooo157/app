import 'package:bead_light_board/features/guide/domain/beading_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('构造与边界', () {
    test('尺寸必须为正', () {
      expect(() => BeadingProgress(rows: 0, cols: 5), throwsArgumentError);
      expect(() => BeadingProgress(rows: 5, cols: -1), throwsArgumentError);
    });

    test('越界访问抛 RangeError', () {
      final BeadingProgress progress = BeadingProgress(rows: 2, cols: 2);
      expect(() => progress.isPlacedDirectly(2, 0), throwsRangeError);
      expect(() => progress.togglePlaced(0, 5), throwsRangeError);
      expect(
        () => progress.setColorCompleted(-1, completed: true),
        throwsRangeError,
      );
    });

    test('初始状态：没有已放、没有已完成', () {
      final BeadingProgress progress = BeadingProgress(rows: 3, cols: 3);
      expect(progress.directlyPlacedCount, 0);
      expect(progress.completedColorCount, 0);
      expect(progress.completedColors, isEmpty);
      expect(progress.isCellPlaced(0, 0, 0), isFalse);
    });
  });

  group('逐格标记', () {
    test('toggle / set 都能正确读写', () {
      final BeadingProgress progress = BeadingProgress(rows: 2, cols: 3)
        ..togglePlaced(0, 0);

      expect(progress.isPlacedDirectly(0, 0), isTrue);
      progress.togglePlaced(0, 0);
      expect(progress.isPlacedDirectly(0, 0), isFalse);

      progress.setPlaced(1, 2, placed: true);
      expect(progress.isPlacedDirectly(1, 2), isTrue);
      expect(progress.directlyPlacedCount, 1);
    });

    test('行列索引不串位（行优先）', () {
      final BeadingProgress progress = BeadingProgress(rows: 3, cols: 4)
        ..setPlaced(2, 3, placed: true);
      expect(progress.isPlacedDirectly(2, 3), isTrue);
      expect(progress.isPlacedDirectly(0, 0), isFalse);
      expect(progress.isPlacedDirectly(1, 3), isFalse);
      expect(progress.isPlacedDirectly(2, 2), isFalse);
    });
  });

  group('逐色标记（板子盖住屏幕时的主力方式）', () {
    test('整色完成会让该色所有格子都算已放', () {
      final BeadingProgress progress = BeadingProgress(rows: 2, cols: 2);
      expect(progress.isCellPlaced(5, 0, 0), isFalse);

      progress.setColorCompleted(5, completed: true);
      expect(progress.isCellPlaced(5, 0, 0), isTrue);
      expect(progress.isCellPlaced(5, 1, 1), isTrue);
      // 其它颜色不受影响
      expect(progress.isCellPlaced(6, 0, 0), isFalse);
    });

    test('取消整色完成会同时撤销隐含的已放', () {
      final BeadingProgress progress = BeadingProgress(rows: 2, cols: 2)
        ..setColorCompleted(3, completed: true);
      expect(progress.isCellPlaced(3, 0, 0), isTrue);

      progress.setColorCompleted(3, completed: false);
      expect(progress.isCellPlaced(3, 0, 0), isFalse);
      expect(progress.completedColors, isEmpty);
    });

    test('toggleColorCompleted 在两种状态间切换', () {
      final BeadingProgress progress = BeadingProgress(rows: 1, cols: 1);
      expect(progress.isColorCompleted(2), isFalse);
      progress.toggleColorCompleted(2);
      expect(progress.isColorCompleted(2), isTrue);
      progress.toggleColorCompleted(2);
      expect(progress.isColorCompleted(2), isFalse);
    });

    test('单格标记与整色完成可以叠加：整色完成后单格标记仍在', () {
      final BeadingProgress progress = BeadingProgress(rows: 2, cols: 2)
        ..setPlaced(0, 0, placed: true)
        ..setColorCompleted(7, completed: true);
      expect(progress.directlyPlacedCount, 1);
      expect(progress.completedColorCount, 1);
      expect(progress.isCellPlaced(7, 1, 1), isTrue);
    });

    test('completedColors 返回只读快照，外部改不动内部', () {
      final BeadingProgress progress = BeadingProgress(rows: 1, cols: 1)
        ..setColorCompleted(1, completed: true);
      final Set<int> snapshot = progress.completedColors;
      expect(() => snapshot.add(99), throwsUnsupportedError);
    });
  });

  group('重置', () {
    test('reset 清空全部进度', () {
      final BeadingProgress progress = BeadingProgress(rows: 3, cols: 3)
        ..togglePlaced(0, 0)
        ..togglePlaced(2, 2)
        ..toggleColorCompleted(4);
      expect(progress.directlyPlacedCount, 2);
      expect(progress.completedColorCount, 1);

      progress.reset();
      expect(progress.directlyPlacedCount, 0);
      expect(progress.completedColorCount, 0);
      expect(progress.isCellPlaced(4, 0, 0), isFalse);
    });
  });
}
