import 'package:bead_light_board/data/models/bead_pattern.dart';
import 'package:bead_light_board/features/edit/domain/pattern_editor.dart';
import 'package:flutter_test/flutter_test.dart';

BeadPattern blank({int rows = 4, int cols = 5, int colorIndex = 0}) =>
    BeadPattern.filled(
      rows: rows,
      cols: cols,
      paletteId: 'test_fixture',
      colorIndex: colorIndex,
    );

void main() {
  group('对称展开', () {
    test('无对称：只有自己', () {
      expect(
        PatternEditor.symmetricCells(
          row: 1,
          col: 1,
          rows: 4,
          cols: 5,
          symmetry: SymmetryMode.none,
        ),
        <({int row, int col})>[(row: 1, col: 1)],
      );
    });

    test('左右对称：5 列时 0 ↔ 4', () {
      final List<({int row, int col})> cells = PatternEditor.symmetricCells(
        row: 2,
        col: 0,
        rows: 4,
        cols: 5,
        symmetry: SymmetryMode.leftRight,
      );
      expect(
        cells,
        containsAll(<({int row, int col})>[(row: 2, col: 0), (row: 2, col: 4)]),
      );
      expect(cells, hasLength(2));
    });

    test('落在对称轴上时不会重复', () {
      expect(
        PatternEditor.symmetricCells(
          row: 1,
          col: 2, // 5 列的中轴
          rows: 4,
          cols: 5,
          symmetry: SymmetryMode.leftRight,
        ),
        hasLength(1),
      );
      expect(
        PatternEditor.symmetricCells(
          row: 1,
          col: 1,
          rows: 4,
          cols: 5,
          symmetry: SymmetryMode.topBottom,
        ),
        hasLength(2),
      );
    });

    test('上下对称：4 行时 0 ↔ 3', () {
      final List<({int row, int col})> cells = PatternEditor.symmetricCells(
        row: 0,
        col: 1,
        rows: 4,
        cols: 5,
        symmetry: SymmetryMode.topBottom,
      );
      expect(
        cells,
        containsAll(<({int row, int col})>[(row: 0, col: 1), (row: 3, col: 1)]),
      );
      expect(cells, hasLength(2));
    });

    test('四向：一般位置得到 4 格', () {
      expect(
        PatternEditor.symmetricCells(
          row: 0,
          col: 0,
          rows: 4,
          cols: 5,
          symmetry: SymmetryMode.quad,
        ),
        hasLength(4),
      );
    });

    test('四向：正中心只得到 1 格（5x5 的中心）', () {
      expect(
        PatternEditor.symmetricCells(
          row: 2,
          col: 2,
          rows: 5,
          cols: 5,
          symmetry: SymmetryMode.quad,
        ),
        hasLength(1),
      );
    });
  });

  group('画笔', () {
    test('改一格并返回改动', () {
      final BeadPattern pattern = blank();
      final List<CellChange> changes = PatternEditor.paint(
        pattern,
        row: 1,
        col: 2,
        colorIndex: 7,
      );

      expect(pattern.colorIndexAt(1, 2), 7);
      expect(changes, <CellChange>[
        const CellChange(row: 1, col: 2, before: 0, after: 7),
      ]);
    });

    test('已经是目标色时视为没改动（不污染撤销栈）', () {
      final BeadPattern pattern = blank(colorIndex: 7);
      expect(
        PatternEditor.paint(pattern, row: 0, col: 0, colorIndex: 7),
        isEmpty,
      );
    });

    test('越界返回空改动，且不抛异常', () {
      final BeadPattern pattern = blank();
      expect(
        PatternEditor.paint(pattern, row: -1, col: 0, colorIndex: 3),
        isEmpty,
      );
      expect(
        PatternEditor.paint(pattern, row: 0, col: 99, colorIndex: 3),
        isEmpty,
      );
    });

    test('带左右对称时同时改两格', () {
      final BeadPattern pattern = blank();
      final List<CellChange> changes = PatternEditor.paint(
        pattern,
        row: 0,
        col: 0,
        colorIndex: 4,
        symmetry: SymmetryMode.leftRight,
      );

      expect(changes, hasLength(2));
      expect(pattern.colorIndexAt(0, 0), 4);
      expect(pattern.colorIndexAt(0, 4), 4);
      // 中间不受影响
      expect(pattern.colorIndexAt(0, 2), 0);
    });

    test('四向对称一次改四格', () {
      final BeadPattern pattern = blank();
      PatternEditor.paint(
        pattern,
        row: 0,
        col: 0,
        colorIndex: 9,
        symmetry: SymmetryMode.quad,
      );
      expect(pattern.colorIndexAt(0, 0), 9);
      expect(pattern.colorIndexAt(0, 4), 9);
      expect(pattern.colorIndexAt(3, 0), 9);
      expect(pattern.colorIndexAt(3, 4), 9);
    });
  });

  group('拖动插值（Bresenham）', () {
    test('水平直线覆盖每一格，中间不留空', () {
      final List<({int row, int col})> points = PatternEditor.bresenham(
        fromRow: 1,
        fromCol: 0,
        toRow: 1,
        toCol: 4,
      );
      expect(points, <({int row, int col})>[
        (row: 1, col: 0),
        (row: 1, col: 1),
        (row: 1, col: 2),
        (row: 1, col: 3),
        (row: 1, col: 4),
      ]);
    });

    test('垂直线同理', () {
      expect(
        PatternEditor.bresenham(fromRow: 0, fromCol: 2, toRow: 3, toCol: 2),
        hasLength(4),
      );
    });

    test('对角线也是连续格点', () {
      final List<({int row, int col})> points = PatternEditor.bresenham(
        fromRow: 0,
        fromCol: 0,
        toRow: 3,
        toCol: 3,
      );
      expect(points, <({int row, int col})>[
        (row: 0, col: 0),
        (row: 1, col: 1),
        (row: 2, col: 2),
        (row: 3, col: 3),
      ]);
    });

    test('起点终点相同只返回一个点', () {
      expect(
        PatternEditor.bresenham(fromRow: 2, fromCol: 2, toRow: 2, toCol: 2),
        hasLength(1),
      );
    });

    test('反向拖动路径与正向互为倒序', () {
      final List<({int row, int col})> forward = PatternEditor.bresenham(
        fromRow: 0,
        fromCol: 0,
        toRow: 3,
        toCol: 5,
      );
      final List<({int row, int col})> backward = PatternEditor.bresenham(
        fromRow: 3,
        fromCol: 5,
        toRow: 0,
        toCol: 0,
      );
      expect(backward.reversed.toList(), forward);
    });

    test('快速划一条长线也不会漏格', () {
      final BeadPattern pattern = blank(rows: 6, cols: 6);
      final List<CellChange> changes = PatternEditor.paintLine(
        pattern,
        fromRow: 0,
        fromCol: 0,
        toRow: 0,
        toCol: 5,
        colorIndex: 2,
      );
      expect(changes, hasLength(6));
      for (int col = 0; col < 6; col++) {
        expect(pattern.colorIndexAt(0, col), 2, reason: 'col=$col 不该漏');
      }
    });

    test('插值同样遵守对称模式', () {
      final BeadPattern pattern = blank();
      PatternEditor.paintLine(
        pattern,
        fromRow: 0,
        fromCol: 0,
        toRow: 3,
        toCol: 0,
        colorIndex: 5,
        symmetry: SymmetryMode.leftRight,
      );
      for (int row = 0; row < 4; row++) {
        expect(pattern.colorIndexAt(row, 0), 5, reason: '左列 row=$row');
        expect(pattern.colorIndexAt(row, 4), 5, reason: '右列 row=$row');
      }
      expect(pattern.colorIndexAt(0, 2), 0, reason: '中间列不该被改');
    });
  });

  group('油漆桶', () {
    test('填充连通的同色区域', () {
      final BeadPattern pattern = blank(rows: 3, cols: 3)
        // 中间竖着一条不同色，把左右隔开
        ..setColorIndexAt(0, 1, 9)
        ..setColorIndexAt(1, 1, 9)
        ..setColorIndexAt(2, 1, 9);

      final List<CellChange> changes = PatternEditor.floodFill(
        pattern,
        row: 0,
        col: 0,
        colorIndex: 3,
      );

      // 左列 3 格
      expect(changes, hasLength(3));
      expect(pattern.colorIndexAt(0, 0), 3);
      expect(pattern.colorIndexAt(1, 0), 3);
      expect(pattern.colorIndexAt(2, 0), 3);
      // 隔开的右列与分隔色不受影响
      expect(pattern.colorIndexAt(0, 2), 0);
      expect(pattern.colorIndexAt(0, 1), 9);
    });

    test('只认四连通，对角不算连通', () {
      final BeadPattern pattern = blank(rows: 2, cols: 2)
        ..setColorIndexAt(0, 0, 1)
        ..setColorIndexAt(0, 1, 2)
        ..setColorIndexAt(1, 0, 2)
        ..setColorIndexAt(1, 1, 1);

      final List<CellChange> changes = PatternEditor.floodFill(
        pattern,
        row: 0,
        col: 0,
        colorIndex: 5,
      );
      expect(changes, hasLength(1));
      expect(pattern.colorIndexAt(1, 1), 1, reason: '对角那格不该被填');
    });

    test('填充色与目标色相同时什么都不做', () {
      final BeadPattern pattern = blank(colorIndex: 4);
      expect(
        PatternEditor.floodFill(pattern, row: 0, col: 0, colorIndex: 4),
        isEmpty,
      );
    });

    test('越界不崩', () {
      final BeadPattern pattern = blank();
      expect(
        PatternEditor.floodFill(pattern, row: 10, col: 10, colorIndex: 1),
        isEmpty,
      );
    });

    test('能把整张图一次填满（52x52 的最大规模）', () {
      final BeadPattern pattern = blank(rows: 52, cols: 52);
      final List<CellChange> changes = PatternEditor.floodFill(
        pattern,
        row: 0,
        col: 0,
        colorIndex: 6,
      );
      expect(changes, hasLength(52 * 52));
      expect(pattern.usageByColorIndex.keys, <int>[6]);
    });
  });

  group('吸管与写回', () {
    test('吸管读到颜色；越界返回 null', () {
      final BeadPattern pattern = blank()..setColorIndexAt(2, 3, 8);
      expect(PatternEditor.pick(pattern, 2, 3), 8);
      expect(PatternEditor.pick(pattern, -1, 0), isNull);
      expect(PatternEditor.pick(pattern, 0, 99), isNull);
    });

    test('applyChanges 写回 before（撤销）', () {
      final BeadPattern pattern = blank();
      final List<CellChange> changes = PatternEditor.paint(
        pattern,
        row: 0,
        col: 0,
        colorIndex: 7,
      );
      expect(pattern.colorIndexAt(0, 0), 7);

      PatternEditor.applyChanges(pattern, changes, useBefore: true);
      expect(pattern.colorIndexAt(0, 0), 0);
    });

    test('applyChanges 写回 after（重做）', () {
      final BeadPattern pattern = blank();
      final List<CellChange> changes = PatternEditor.paint(
        pattern,
        row: 0,
        col: 0,
        colorIndex: 7,
      );
      PatternEditor.applyChanges(pattern, changes, useBefore: true);
      PatternEditor.applyChanges(pattern, changes, useBefore: false);
      expect(pattern.colorIndexAt(0, 0), 7);
    });

    test('写回时越界的改动被安全忽略', () {
      final BeadPattern pattern = blank();
      PatternEditor.applyChanges(pattern, const <CellChange>[
        CellChange(row: 99, col: 99, before: 1, after: 2),
        CellChange(row: 0, col: 0, before: 1, after: 2),
      ], useBefore: false);
      expect(pattern.colorIndexAt(0, 0), 2);
    });
  });
}
