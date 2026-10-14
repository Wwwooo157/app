import 'dart:ui' show Offset, Rect, Size;

import 'package:bead_light_board/features/grid/domain/grid_transform.dart';
import 'package:bead_light_board/features/grid/domain/peg_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

/// 简单可控的度量：每格 10x10 逻辑像素，便于心算。
const PegMetrics kMetrics = PegMetrics(pxPerMmX: 2, pxPerMmY: 2, pitchMm: 5);

void main() {
  group('cellAt 命中测试', () {
    const GridTransform transform = GridTransform(
      origin: Offset(100, 50),
      metrics: kMetrics,
    );

    test('格子内部任意点都命中该格', () {
      expect(
        transform.cellAt(const Offset(105, 55), rows: 10, cols: 10),
        const GridCell(row: 0, col: 0),
      );
      expect(
        transform.cellAt(const Offset(124.9, 69.9), rows: 10, cols: 10),
        const GridCell(row: 1, col: 2),
      );
    });

    test('格子边界点归入右下方的格子（左闭右开）', () {
      // 正好落在 (0,0) 与 (0,1) 的交界上
      expect(
        transform.cellAt(const Offset(110, 55), rows: 10, cols: 10),
        const GridCell(row: 0, col: 1),
      );
      // 正好落在 (0,0) 左上角
      expect(
        transform.cellAt(const Offset(100, 50), rows: 10, cols: 10),
        const GridCell(row: 0, col: 0),
      );
    });

    test('点在图纸左上方之外返回 null', () {
      expect(
        transform.cellAt(const Offset(99.9, 55), rows: 10, cols: 10),
        isNull,
      );
      expect(
        transform.cellAt(const Offset(105, 49.9), rows: 10, cols: 10),
        isNull,
      );
    });

    test('点在图纸右下方之外（超出行列数）返回 null', () {
      expect(
        transform.cellAt(const Offset(200, 55), rows: 10, cols: 10),
        isNull,
      );
      expect(
        transform.cellAt(const Offset(105, 150), rows: 10, cols: 10),
        isNull,
      );
      // 最后一行最后一格仍然有效
      expect(
        transform.cellAt(const Offset(199.9, 149.9), rows: 10, cols: 10),
        const GridCell(row: 9, col: 9),
      );
    });
  });

  group('几何换算', () {
    const GridTransform transform = GridTransform(
      origin: Offset(10, 20),
      metrics: kMetrics,
    );

    test('cellRect 位置与大小', () {
      expect(transform.cellRect(2, 3), const Rect.fromLTWH(40, 40, 10, 10));
    });

    test('patternSize / patternRect', () {
      expect(transform.patternSize(29, 52), const Size(520, 290));
      expect(
        transform.patternRect(29, 52),
        const Rect.fromLTWH(10, 20, 520, 290),
      );
    });
  });

  group('visibleRange 可见范围', () {
    const GridTransform transform = GridTransform(
      origin: Offset(0, 0),
      metrics: kMetrics,
    );

    test('画布比图纸大时，可见范围就是整张图纸', () {
      final GridRange range = transform.visibleRange(
        const Size(1000, 1000),
        rows: 29,
        cols: 29,
      );
      expect(range.firstRow, 0);
      expect(range.lastRow, 28);
      expect(range.firstCol, 0);
      expect(range.lastCol, 28);
      expect(range.cellCount, 841);
    });

    test('画布比图纸小时，只报告可见的那部分（窗口模式）', () {
      final GridRange range = transform.visibleRange(
        const Size(45, 25),
        rows: 52,
        cols: 52,
      );
      expect(range.firstRow, 0);
      expect(range.firstCol, 0);
      expect(range.lastCol, 4); // 45/10 = 4.5 -> 列 0..4
      expect(range.lastRow, 2); // 25/10 = 2.5 -> 行 0..2
      expect(range.cellCount, 15);
    });

    test('平移后可见范围跟着移动', () {
      final GridTransform panned = transform.panBy(const Offset(-100, -50));
      final GridRange range = panned.visibleRange(
        const Size(45, 25),
        rows: 52,
        cols: 52,
      );
      expect(range.firstCol, 10);
      expect(range.firstRow, 5);
      expect(range.lastCol, 14);
      expect(range.lastRow, 7);
    });

    test('图纸完全移出画布时返回空范围', () {
      final GridTransform panned = transform.panBy(const Offset(-1000, -1000));
      final GridRange range = panned.visibleRange(
        const Size(45, 25),
        rows: 52,
        cols: 52,
      );
      expect(range.isEmpty, isTrue);
      expect(range.cellCount, 0);
    });

    test('图纸在画布右下方之外（origin 为正且很大）也返回空', () {
      const GridTransform far = GridTransform(
        origin: Offset(500, 500),
        metrics: kMetrics,
      );
      final GridRange range = far.visibleRange(
        const Size(45, 25),
        rows: 52,
        cols: 52,
      );
      expect(range.isEmpty, isTrue);
    });
  });

  group('构造与平移', () {
    test('panBy 只改 origin', () {
      const GridTransform t = GridTransform(
        origin: Offset(0, 0),
        metrics: kMetrics,
      );
      final GridTransform moved = t.panBy(const Offset(12, -3));
      expect(moved.origin, const Offset(12, -3));
      expect(moved.pxPerPegX, t.pxPerPegX);
    });

    test('alignedToTopLeft 用于 1:1 初始位置', () {
      final GridTransform t = GridTransform.alignedToTopLeft(
        metrics: kMetrics,
        margin: 6,
      );
      expect(t.origin, const Offset(6, 6));
      expect(t.pxPerPegX, kMetrics.pxPerPegX);
    });

    test('fit 把整图缩到画布内并居中，且不再是 1:1', () {
      final GridTransform t = GridTransform.fit(
        canvasSize: const Size(400, 300),
        rows: 52,
        cols: 52,
        metrics: kMetrics,
        padding: 0,
      );
      final Size size = t.patternSize(52, 52);
      expect(size.width, lessThanOrEqualTo(400.0001));
      expect(size.height, lessThanOrEqualTo(300.0001));
      // 取较小的缩放比：300/520 = 0.5769...
      expect(t.pxPerPegX, closeTo(10 * (300 / 520), 1e-6));
      // 居中
      expect(t.origin.dx, closeTo((400 - size.width) / 2, 1e-6));
      expect(t.origin.dy, closeTo((300 - size.height) / 2, 1e-6));
    });

    test('fit 对 29x29 在宽屏上按高度受限缩放', () {
      final GridTransform t = GridTransform.fit(
        canvasSize: const Size(1000, 290),
        rows: 29,
        cols: 29,
        metrics: kMetrics,
        padding: 0,
      );
      expect(t.patternSize(29, 29).height, closeTo(290, 1e-6));
      expect(t.pxPerPegX, closeTo(10, 1e-6));
    });

    test('fit 拒绝非法的行列数', () {
      expect(
        () => GridTransform.fit(
          canvasSize: const Size(100, 100),
          rows: 0,
          cols: 10,
          metrics: kMetrics,
        ),
        throwsArgumentError,
      );
    });
  });
}
