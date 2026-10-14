import 'package:bead_light_board/data/models/bead_pattern.dart';
import 'package:bead_light_board/features/grid/domain/grid_style.dart';
import 'package:bead_light_board/features/grid/domain/grid_transform.dart';
import 'package:bead_light_board/features/grid/domain/peg_metrics.dart';
import 'package:bead_light_board/features/grid/presentation/grid_painter.dart';
import 'package:bead_light_board/features/guide/domain/beading_progress.dart';
import 'package:bead_light_board/features/guide/domain/guide_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const PegMetrics kMetrics = PegMetrics(pxPerMmX: 2, pxPerMmY: 2, pitchMm: 5);

const List<Color> kColors = <Color>[Color(0xFF202124), Color(0xFF5F8F6A)];

const GuideStyle kGuide = GuideStyle();

/// 按 ARGB 通道比较颜色，容忍 2/255 的浮点误差。
void expectColorNear(Color actual, Color expected, {int tolerance = 2}) {
  final int a = actual.toARGB32();
  final int e = expected.toARGB32();
  for (final int shift in <int>[0, 8, 16, 24]) {
    final int channelA = (a >> shift) & 0xFF;
    final int channelE = (e >> shift) & 0xFF;
    expect(
      (channelA - channelE).abs(),
      lessThanOrEqualTo(tolerance),
      reason:
          '颜色不接近：actual=${a.toRadixString(16)} expected=${e.toRadixString(16)}',
    );
  }
}

void main() {
  /// 2x2：上排两格是色号 0，下排两格是色号 1。
  final BeadPattern sharedPattern =
      BeadPattern.filled(
          rows: 2,
          cols: 2,
          paletteId: 'test_fixture',
          colorIndex: 1,
        )
        ..setColorIndexAt(0, 0, 0)
        ..setColorIndexAt(0, 1, 0);

  GridPainter makePainter({
    int? active,
    bool hideOthers = false,
    BeadingProgress? progress,
    Animation<double>? blink,
  }) => GridPainter(
    pattern: sharedPattern,
    transform: const GridTransform(origin: Offset.zero, metrics: kMetrics),
    style: GridStyle.eyeCare(),
    paletteColors: kColors,
    activeColorIndex: active,
    hideOtherColors: hideOthers,
    progress: progress,
    blink: blink,
  );

  group('单格颜色解析', () {
    test('未选色：正常显示原色', () {
      final GridPainter painter = makePainter();
      expect(painter.debugResolveCellColor(0, 0), kColors[0]);
      expect(painter.debugResolveCellColor(1, 1), kColors[1]);
    });

    test('选中色号：该色所有格子都变成高亮色（不闪烁时是稳定色）', () {
      final GridPainter painter = makePainter(active: 0);
      expect(painter.debugResolveCellColor(0, 0), kGuide.highlightColor);
      expect(painter.debugResolveCellColor(0, 1), kGuide.highlightColor);
    });

    test('非当前色：默认压暗（既不是原色也不是高亮）', () {
      final Color? dimmed = makePainter(active: 0).debugResolveCellColor(1, 1);
      expect(dimmed, isNotNull);
      expect(dimmed, isNot(kColors[1]));
      expect(dimmed, isNot(kGuide.highlightColor));
    });

    test('开启隐藏其他色：非当前色返回 null（不绘制）', () {
      final GridPainter painter = makePainter(active: 0, hideOthers: true);
      expect(painter.debugResolveCellColor(1, 1), isNull);
      expect(painter.debugResolveCellColor(0, 0), kGuide.highlightColor);
    });

    test('闪烁：高亮色在基色与脉动色之间插值', () {
      expectColorNear(
        makePainter(
          active: 0,
          blink: const AlwaysStoppedAnimation<double>(0),
        ).debugResolveCellColor(0, 0)!,
        kGuide.highlightColor,
      );
      expectColorNear(
        makePainter(
          active: 0,
          blink: const AlwaysStoppedAnimation<double>(1),
        ).debugResolveCellColor(0, 0)!,
        kGuide.highlightPulseColor,
      );
      final Color mid = makePainter(
        active: 0,
        blink: const AlwaysStoppedAnimation<double>(0.5),
      ).debugResolveCellColor(0, 0)!;
      expect(mid, isNot(kGuide.highlightColor));
      expect(mid, isNot(kGuide.highlightPulseColor));
    });

    test('整色已完成：即使正在引导该色也画成完成色', () {
      final BeadingProgress progress = BeadingProgress(rows: 2, cols: 2)
        ..setColorCompleted(0, completed: true);
      expect(
        makePainter(active: 0, progress: progress).debugResolveCellColor(0, 0),
        kGuide.completedColor,
      );
    });

    test('单格已放：画成完成色，同色其它格不受影响', () {
      final BeadingProgress progress = BeadingProgress(rows: 2, cols: 2)
        ..setPlaced(1, 0, placed: true);
      final GridPainter painter = makePainter(progress: progress);
      expect(painter.debugResolveCellColor(1, 0), kGuide.completedColor);
      expect(painter.debugResolveCellColor(1, 1), kColors[1]);
    });
  });

  group('实际绘制行为', () {
    testWidgets('隐藏其他色后，实际绘制的格子数变少', (WidgetTester tester) async {
      Future<void> pump(GridPainter painter) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(painter: painter),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      final GridPainter normal = makePainter(active: 0);
      await pump(normal);
      expect(normal.debugCellsPainted, 4);

      final GridPainter hidden = makePainter(active: 0, hideOthers: true);
      await pump(hidden);
      expect(hidden.debugCellsPainted, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('带闪烁动画绘制不崩', (WidgetTester tester) async {
      final GridPainter painter = makePainter(
        active: 1,
        blink: const AlwaysStoppedAnimation<double>(0.7),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: CustomPaint(painter: painter),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(painter.debugCellsPainted, 4);
      expect(tester.takeException(), isNull);
    });
  });

  group('shouldRepaint', () {
    test('引导相关参数变化都要重绘', () {
      expect(makePainter(active: 0).shouldRepaint(makePainter()), isTrue);
      expect(
        makePainter(
          active: 0,
          hideOthers: true,
        ).shouldRepaint(makePainter(active: 0)),
        isTrue,
      );
      expect(
        makePainter(active: 0).shouldRepaint(makePainter(active: 1)),
        isTrue,
      );
    });

    test('参数完全相同时不重绘', () {
      expect(
        makePainter(active: 0).shouldRepaint(makePainter(active: 0)),
        isFalse,
      );
    });
  });
}
