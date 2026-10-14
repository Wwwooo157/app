import 'dart:typed_data';

import 'package:bead_light_board/data/models/bead_pattern.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('构造与校验', () {
    test('filled 用同一个色号铺满', () {
      final BeadPattern pattern = BeadPattern.filled(
        rows: 3,
        cols: 4,
        paletteId: 'demo',
        colorIndex: 2,
      );
      expect(pattern.rows, 3);
      expect(pattern.cols, 4);
      expect(pattern.length, 12);
      expect(pattern.colorIndexAt(0, 0), 2);
      expect(pattern.colorIndexAt(2, 3), 2);
      expect(pattern.usageByColorIndex, <int, int>{2: 12});
    });

    test('filled 默认色号索引为 0', () {
      final BeadPattern pattern = BeadPattern.filled(
        rows: 2,
        cols: 2,
        paletteId: 'demo',
      );
      expect(pattern.colorIndexAt(1, 1), 0);
    });

    test('rows/cols 非正数直接拒绝', () {
      expect(
        () => BeadPattern.filled(rows: 0, cols: 5, paletteId: 'demo'),
        throwsArgumentError,
      );
      expect(
        () => BeadPattern.filled(rows: 5, cols: -1, paletteId: 'demo'),
        throwsArgumentError,
      );
    });

    test('fromColorIndex 长度必须等于 rows*cols', () {
      expect(
        () => BeadPattern.fromColorIndex(
          rows: 2,
          cols: 2,
          paletteId: 'demo',
          colorIndex: Uint16List(3),
        ),
        throwsArgumentError,
      );
    });

    test('fromColorIndex 会复制一份，外部后续改动不影响图纸', () {
      final Uint16List external = Uint16List.fromList(<int>[1, 2, 3, 4]);
      final BeadPattern pattern = BeadPattern.fromColorIndex(
        rows: 2,
        cols: 2,
        paletteId: 'demo',
        colorIndex: external,
      );
      external[0] = 9;
      expect(pattern.colorIndexAt(0, 0), 1);
    });
  });

  group('索引换算与越界', () {
    test('indexAt 按行优先换算', () {
      final BeadPattern pattern = BeadPattern.filled(
        rows: 3,
        cols: 4,
        paletteId: 'demo',
      );
      expect(pattern.indexAt(0, 0), 0);
      expect(pattern.indexAt(0, 3), 3);
      expect(pattern.indexAt(1, 0), 4);
      expect(pattern.indexAt(2, 3), 11);
    });

    test('越界访问抛 RangeError', () {
      final BeadPattern pattern = BeadPattern.filled(
        rows: 2,
        cols: 2,
        paletteId: 'demo',
      );
      expect(() => pattern.colorIndexAt(2, 0), throwsRangeError);
      expect(() => pattern.colorIndexAt(0, 2), throwsRangeError);
      expect(() => pattern.colorIndexAt(-1, 0), throwsRangeError);
      expect(() => pattern.setColorIndexAt(0, 5, 1), throwsRangeError);
    });

    test('写入非法色号索引抛 RangeError', () {
      final BeadPattern pattern = BeadPattern.filled(
        rows: 2,
        cols: 2,
        paletteId: 'demo',
      );
      expect(() => pattern.setColorIndexAt(0, 0, -1), throwsRangeError);
      expect(() => pattern.setColorIndexAt(0, 0, 70000), throwsRangeError);
    });
  });

  group('统计', () {
    test('countOf 与 usageByColorIndex 按用量降序、同量按索引升序', () {
      // 初始 6 格全是色号 0；改前三格后：色号 0 有 3 颗、色号 2 有 2 颗、色号 1 有 1 颗
      final BeadPattern pattern =
          BeadPattern.filled(rows: 2, cols: 3, paletteId: 'demo')
            ..setColorIndexAt(0, 0, 1)
            ..setColorIndexAt(0, 1, 2)
            ..setColorIndexAt(0, 2, 2);

      expect(pattern.countOf(0), 3);
      expect(pattern.countOf(1), 1);
      expect(pattern.countOf(2), 2);
      expect(pattern.countOf(99), 0);

      expect(pattern.usageByColorIndex.keys.toList(), <int>[
        0,
        2,
        1,
      ], reason: '先按颗数降序：0(3颗) > 2(2颗) > 1(1颗)');
      expect(pattern.usedColorCount, 3);
    });

    test('颗数相同时按色号索引升序，保证顺序稳定', () {
      final BeadPattern pattern =
          BeadPattern.filled(rows: 1, cols: 4, paletteId: 'demo')
            ..setColorIndexAt(0, 0, 7)
            ..setColorIndexAt(0, 1, 3)
            ..setColorIndexAt(0, 2, 5)
            ..setColorIndexAt(0, 3, 9);
      expect(pattern.usageByColorIndex.keys.toList(), <int>[3, 5, 7, 9]);
    });
  });

  group('拷贝', () {
    test('copy 是深拷贝，互不影响', () {
      final BeadPattern original = BeadPattern.filled(
        rows: 2,
        cols: 2,
        paletteId: 'demo',
      );
      final BeadPattern clone = original.copy()..setColorIndexAt(1, 1, 5);

      expect(original.colorIndexAt(1, 1), 0);
      expect(clone.colorIndexAt(1, 1), 5);
    });

    test('colorIndexView 暴露的缓冲与内部数据一致', () {
      final BeadPattern pattern = BeadPattern.filled(
        rows: 2,
        cols: 2,
        paletteId: 'demo',
        colorIndex: 4,
      );
      final Uint16List view = pattern.colorIndexView;
      expect(view.length, 4);
      expect(view.every((int value) => value == 4), isTrue);
    });
  });
}
