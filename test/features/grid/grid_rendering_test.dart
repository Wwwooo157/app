import 'package:bead_light_board/data/models/bead_pattern.dart';
import 'package:bead_light_board/features/grid/domain/grid_style.dart';
import 'package:bead_light_board/features/grid/domain/grid_transform.dart';
import 'package:bead_light_board/features/grid/domain/peg_metrics.dart';
import 'package:bead_light_board/features/grid/domain/sample_patterns.dart';
import 'package:bead_light_board/features/grid/presentation/grid_canvas.dart';
import 'package:bead_light_board/features/grid/presentation/grid_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 每格 10 逻辑像素，便于心算。
const PegMetrics kMetrics = PegMetrics(pxPerMmX: 2, pxPerMmY: 2, pitchMm: 5);

const List<Color> kColors = <Color>[
  Color(0xFF202124),
  Color(0xFF4A5057),
  Color(0xFF8A9099),
  Color(0xFFC9CDD2),
  Color(0xFFB4574F),
  Color(0xFF5F8F6A),
  Color(0xFF4F7396),
  Color(0xFFC9A75B),
];

/// 把画家放进一个固定尺寸的画布并真正绘制一帧。
Future<void> pumpPainter(
  WidgetTester tester,
  GridPainter painter, {
  required Size size,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: CustomPaint(painter: painter),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('只画可见范围', () {
    testWidgets('窗口模式下只画与画布相交的格子', (WidgetTester tester) async {
      final BeadPattern pattern = BeadPattern.filled(
        rows: 52,
        cols: 52,
        paletteId: 'test_fixture',
      );
      final GridPainter painter = GridPainter(
        pattern: pattern,
        transform: const GridTransform(origin: Offset.zero, metrics: kMetrics),
        style: GridStyle.eyeCare(),
        paletteColors: kColors,
      );

      // 100x60 的画布，每格 10px -> 10 列 x 6 行
      await pumpPainter(tester, painter, size: const Size(100, 60));

      expect(painter.debugCellsPainted, 60);
      // 7 条横线 + 11 条竖线
      expect(painter.debugLinesPainted, 18);
      expect(tester.takeException(), isNull);
    });

    testWidgets('总览模式（fit）会画完整张图', (WidgetTester tester) async {
      final BeadPattern pattern = buildSyntheticPattern(rows: 8, cols: 8);
      final GridPainter painter = GridPainter(
        pattern: pattern,
        transform: GridTransform.fit(
          canvasSize: const Size(400, 300),
          rows: 8,
          cols: 8,
          metrics: kMetrics,
          padding: 12,
        ),
        style: GridStyle.eyeCare(),
        paletteColors: kColors,
      );

      await pumpPainter(tester, painter, size: const Size(400, 300));

      expect(painter.debugCellsPainted, 64);
      expect(tester.takeException(), isNull);
    });
  });

  group('各种尺寸都能渲染', () {
    for (final ({int rows, int cols}) size in <({int rows, int cols})>[
      (rows: 29, cols: 29),
      (rows: 52, cols: 52),
      (rows: 20, cols: 30),
      (rows: 1, cols: 1),
      (rows: 100, cols: 100),
    ]) {
      testWidgets('${size.rows}x${size.cols}', (WidgetTester tester) async {
        final BeadPattern pattern = buildSyntheticPattern(
          rows: size.rows,
          cols: size.cols,
        );
        final GridPainter painter = GridPainter(
          pattern: pattern,
          transform: GridTransform.fit(
            canvasSize: const Size(800, 600),
            rows: size.rows,
            cols: size.cols,
            metrics: kMetrics,
          ),
          style: GridStyle.eyeCare(cellStyle: PegCellStyle.filled),
          paletteColors: kColors,
        );

        await pumpPainter(tester, painter, size: const Size(800, 600));

        expect(tester.takeException(), isNull);
        expect(painter.debugCellsPainted, size.rows * size.cols);
      });
    }
  });

  group('健壮性', () {
    testWidgets('色卡索引越界时画告警色而不是崩溃', (WidgetTester tester) async {
      final BeadPattern pattern = BeadPattern.filled(
        rows: 3,
        cols: 3,
        paletteId: 'test_fixture',
        colorIndex: 5, // 但下面只给 1 个颜色
      );
      final GridPainter painter = GridPainter(
        pattern: pattern,
        transform: const GridTransform(origin: Offset.zero, metrics: kMetrics),
        style: GridStyle.eyeCare(),
        paletteColors: const <Color>[Color(0xFF112233)],
      );

      await pumpPainter(tester, painter, size: const Size(100, 100));

      expect(tester.takeException(), isNull);
      expect(painter.debugCellsPainted, 9);
      expect(GridPainter.outOfPaletteColor, const Color(0xFFFF00FF));
    });

    testWidgets('完全没有配色时不崩溃', (WidgetTester tester) async {
      final BeadPattern pattern = BeadPattern.filled(
        rows: 2,
        cols: 2,
        paletteId: 'test_fixture',
      );
      final GridPainter painter = GridPainter(
        pattern: pattern,
        transform: const GridTransform(origin: Offset.zero, metrics: kMetrics),
        style: GridStyle.eyeCare(),
        paletteColors: const <Color>[],
      );

      await pumpPainter(tester, painter, size: const Size(50, 50));
      expect(tester.takeException(), isNull);
    });

    testWidgets('图纸完全移出画布也能安全绘制', (WidgetTester tester) async {
      final BeadPattern pattern = BeadPattern.filled(
        rows: 5,
        cols: 5,
        paletteId: 'test_fixture',
      );
      final GridPainter painter = GridPainter(
        pattern: pattern,
        transform: const GridTransform(
          origin: Offset(-1000, -1000),
          metrics: kMetrics,
        ),
        style: GridStyle.eyeCare(),
        paletteColors: kColors,
      );

      await pumpPainter(tester, painter, size: const Size(200, 200));
      expect(painter.debugCellsPainted, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('标尺叠加层能画出来', (WidgetTester tester) async {
      final BeadPattern pattern = BeadPattern.filled(
        rows: 5,
        cols: 5,
        paletteId: 'test_fixture',
      );
      final GridPainter painter = GridPainter(
        pattern: pattern,
        transform: const GridTransform(origin: Offset.zero, metrics: kMetrics),
        style: GridStyle.eyeCare(),
        paletteColors: kColors,
        showScaleRuler: true,
      );

      await pumpPainter(tester, painter, size: const Size(400, 300));
      expect(tester.takeException(), isNull);
    });
  });

  group('shouldRepaint', () {
    final BeadPattern pattern = BeadPattern.filled(
      rows: 5,
      cols: 5,
      paletteId: 'test_fixture',
    );
    GridPainter makePainter({
      Offset origin = Offset.zero,
      double lineWidth = 0.6,
      GridCell? selected,
    }) => GridPainter(
      pattern: pattern,
      transform: GridTransform(origin: origin, metrics: kMetrics),
      style: GridStyle.eyeCare(lineWidth: lineWidth),
      paletteColors: kColors,
      selectedCell: selected,
    );

    test('完全相同时不重绘', () {
      expect(makePainter().shouldRepaint(makePainter()), isFalse);
    });

    test('平移后要重绘', () {
      expect(
        makePainter(origin: const Offset(5, 5)).shouldRepaint(makePainter()),
        isTrue,
      );
    });

    test('线宽变化要重绘', () {
      expect(makePainter(lineWidth: 1.5).shouldRepaint(makePainter()), isTrue);
    });

    test('选中格变化要重绘', () {
      expect(
        makePainter(selected: const GridCell(row: 1, col: 1))
            .shouldRepaint(makePainter()),
        isTrue,
      );
    });
  });

  group('GridCanvas 命中测试（经 widget 层）', () {
    testWidgets('点格内返回该格，点图纸外返回 null', (WidgetTester tester) async {
      final BeadPattern pattern = BeadPattern.filled(
        rows: 5,
        cols: 5,
        paletteId: 'test_fixture',
      );
      final List<GridCell?> taps = <GridCell?>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              height: 100,
              child: GridCanvas(
                pattern: pattern,
                transform: const GridTransform(
                  origin: Offset(20, 10),
                  metrics: kMetrics,
                ),
                style: GridStyle.eyeCare(),
                paletteColors: kColors,
                onCellTap: taps.add,
              ),
            ),
          ),
        ),
      );

      // 800x600 的测试窗口内居中：画布左上角在 (300, 250)
      // 目标格 (2,3) 的中心：局部 (20+35, 10+25) = (55, 35)
      await tester.tapAt(const Offset(355, 285));
      await tester.pump();
      // 图纸右侧之外：局部 (75, 15) -> 第 5 列，越界
      await tester.tapAt(const Offset(375, 265));
      await tester.pump();
      // 图纸左上方之外：局部 (0, 0)
      await tester.tapAt(const Offset(300, 250));
      await tester.pump();

      expect(taps, <GridCell?>[const GridCell(row: 2, col: 3), null, null]);
    });

    testWidgets('单指拖动回调位移，且 scale 恒为 1（与纯拖动行为一致）', (WidgetTester tester) async {
      final BeadPattern pattern = BeadPattern.filled(
        rows: 5,
        cols: 5,
        paletteId: 'test_fixture',
      );
      final List<Offset> pans = <Offset>[];
      final List<double> scales = <double>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              height: 100,
              child: GridCanvas(
                pattern: pattern,
                transform: const GridTransform(
                  origin: Offset.zero,
                  metrics: kMetrics,
                ),
                style: GridStyle.eyeCare(),
                paletteColors: kColors,
                onScaleStart: (ScaleStartDetails details) {},
                onScaleUpdate: (ScaleUpdateDetails details) {
                  pans.add(details.focalPointDelta);
                  scales.add(details.scale);
                },
                onScaleEnd: (ScaleEndDetails details) {},
              ),
            ),
          ),
        ),
      );

      await tester.drag(find.byType(GridCanvas), const Offset(30, -20));
      await tester.pump();

      expect(pans, isNotEmpty);
      final Offset total = pans.fold(
        Offset.zero,
        (Offset a, Offset b) => a + b,
      );
      expect(total.dx, closeTo(30, 0.01));
      expect(total.dy, closeTo(-20, 0.01));
      expect(
        scales.every((double s) => (s - 1).abs() < 1e-6),
        isTrue,
        reason: '单指拖动时 ScaleUpdateDetails.scale 应恒为 1',
      );
    });

    testWidgets('锁定时（不给任何回调）手势与点击都完全不触发', (WidgetTester tester) async {
      final BeadPattern pattern = BeadPattern.filled(
        rows: 5,
        cols: 5,
        paletteId: 'test_fixture',
      );
      final List<GridCell?> taps = <GridCell?>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              height: 100,
              child: GridCanvas(
                pattern: pattern,
                transform: const GridTransform(
                  origin: Offset.zero,
                  metrics: kMetrics,
                ),
                style: GridStyle.eyeCare(),
                paletteColors: kColors,
                // 锁定：所有回调为 null
              ),
            ),
          ),
        ),
      );

      await tester.drag(find.byType(GridCanvas), const Offset(30, -20));
      await tester.tapAt(const Offset(355, 285));
      await tester.pump();

      expect(taps, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
