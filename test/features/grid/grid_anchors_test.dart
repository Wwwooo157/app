import 'package:bead_light_board/data/models/bead_pattern.dart';
import 'package:bead_light_board/features/grid/domain/grid_style.dart';
import 'package:bead_light_board/features/grid/domain/grid_transform.dart';
import 'package:bead_light_board/features/grid/domain/peg_metrics.dart';
import 'package:bead_light_board/features/grid/presentation/grid_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const PegMetrics kMetrics = PegMetrics(pxPerMmX: 2, pxPerMmY: 2, pitchMm: 5);

const List<Color> kColors = <Color>[Color(0xFF202124), Color(0xFF4A5057)];

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
  final BeadPattern pattern = BeadPattern.filled(
    rows: 10,
    cols: 10,
    paletteId: 'test_fixture',
  );

  GridPainter makePainter({bool showAnchors = false}) => GridPainter(
    pattern: pattern,
    transform: const GridTransform(origin: Offset.zero, metrics: kMetrics),
    style: GridStyle.eyeCare(),
    paletteColors: kColors,
    showAnchors: showAnchors,
  );

  group('四角锚点', () {
    testWidgets('开启后能正常绘制且不影响格子数', (WidgetTester tester) async {
      final GridPainter painter = makePainter(showAnchors: true);
      await pumpPainter(tester, painter, size: const Size(400, 300));

      expect(tester.takeException(), isNull);
      // 锚点只是叠加层，不应改变画了多少格：400/10 = 40 列但图纸只有 10 列 -> 10x10
      expect(painter.debugCellsPainted, 100);
    });

    testWidgets('极小画布（比锚点臂长还短）也不能崩', (WidgetTester tester) async {
      final GridPainter painter = makePainter(showAnchors: true);
      await pumpPainter(tester, painter, size: const Size(20, 16));
      expect(tester.takeException(), isNull);
    });

    test('锚点臂长/内缩是常量，便于测试与文档引用', () {
      expect(GridPainter.anchorInset, greaterThan(0));
      expect(GridPainter.anchorArmLength, greaterThan(GridPainter.anchorInset));
      expect(GridPainter.anchorThickness, greaterThan(0));
    });
  });

  group('shouldRepaint 覆盖新增开关', () {
    test('四角锚点开关变化要重绘', () {
      expect(
        makePainter(showAnchors: true).shouldRepaint(makePainter()),
        isTrue,
      );
      expect(
        makePainter(showAnchors: true)
            .shouldRepaint(makePainter(showAnchors: true)),
        isFalse,
      );
    });
  });
}
