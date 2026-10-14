import 'package:bead_light_board/data/models/bead_pattern.dart';
import 'package:bead_light_board/features/grid/domain/sample_patterns.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('合成图纸的基本约束', () {
    for (final SyntheticKind kind in SyntheticKind.values) {
      test('${kind.name}: 尺寸正确且不越界', () {
        final BeadPattern pattern = buildSyntheticPattern(
          rows: 29,
          cols: 52,
          kind: kind,
        );
        expect(pattern.rows, 29);
        expect(pattern.cols, 52);
        expect(pattern.length, 29 * 52);
        for (final int index in pattern.colorIndexView) {
          expect(index, lessThan(8));
        }
        expect(pattern.usedColorCount, greaterThan(1));
      });
    }

    test('确定性：同样输入产生完全相同的图纸', () {
      final BeadPattern a = buildSyntheticPattern(rows: 20, cols: 30);
      final BeadPattern b = buildSyntheticPattern(rows: 20, cols: 30);
      expect(a.colorIndexView, equals(b.colorIndexView));
    });

    test('paletteSize 非法时拒绝', () {
      expect(
        () => buildSyntheticPattern(rows: 5, cols: 5, paletteSize: 0),
        throwsArgumentError,
      );
    });
  });

  group('diagonalCross 的形状（用于肉眼校验 1:1 对齐）', () {
    final BeadPattern pattern = buildSyntheticPattern(rows: 21, cols: 21);

    test('边框用色号 0', () {
      expect(pattern.colorIndexAt(0, 0), 0);
      expect(pattern.colorIndexAt(0, 10), 0);
      expect(pattern.colorIndexAt(10, 0), 0);
      expect(pattern.colorIndexAt(20, 20), 0);
    });

    test('中心十字用色号 1', () {
      expect(pattern.colorIndexAt(10, 5), 1);
      expect(pattern.colorIndexAt(5, 10), 1);
    });

    test('中心点同时属于十字与对角线，取十字优先', () {
      expect(pattern.colorIndexAt(10, 10), 1);
    });

    test('对角线附近用色号 2 或 3（存在斜线）', () {
      final Set<int> diagonalColors = <int>{
        pattern.colorIndexAt(3, 3),
        pattern.colorIndexAt(17, 17),
        pattern.colorIndexAt(3, 17),
        pattern.colorIndexAt(17, 3),
      };
      expect(diagonalColors, containsAll(<int>[2, 3]));
    });
  });

  group('bands 与 checker', () {
    test('bands：色号随行号单调不减', () {
      final BeadPattern pattern = buildSyntheticPattern(
        rows: 8,
        cols: 4,
        kind: SyntheticKind.bands,
      );
      int previous = -1;
      for (int row = 0; row < 8; row++) {
        final int index = pattern.colorIndexAt(row, 0);
        expect(index, greaterThanOrEqualTo(previous));
        previous = index;
        // 同一行内颜色一致
        expect(pattern.colorIndexAt(row, 3), index);
      }
    });

    test('checker：2x2 为一组，相邻组颜色不同', () {
      final BeadPattern pattern = buildSyntheticPattern(
        rows: 8,
        cols: 8,
        kind: SyntheticKind.checker,
      );
      expect(pattern.colorIndexAt(0, 0), pattern.colorIndexAt(1, 1));
      expect(pattern.colorIndexAt(0, 0), pattern.colorIndexAt(1, 0));
      expect(pattern.colorIndexAt(0, 0), isNot(pattern.colorIndexAt(0, 2)));
    });
  });
}
