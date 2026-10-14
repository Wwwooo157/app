import 'dart:math' as math;

import 'package:bead_light_board/data/models/bead_pattern.dart';
import 'package:bead_light_board/features/grid/domain/grid_style.dart';
import 'package:bead_light_board/features/grid/domain/grid_transform.dart';
import 'package:bead_light_board/features/guide/domain/beading_progress.dart';
import 'package:bead_light_board/features/guide/domain/guide_style.dart';
import 'package:flutter/material.dart';

/// 网格绘制器。
///
/// 关键设计：**只画可见范围**（[GridTransform.visibleRange]），
/// 所以 52×52 在窗口模式下每帧只画约 47×29 格，不会因为整图大而掉帧。
/// 而且整张网只用一个 `CustomPaint`，不堆 widget。
class GridPainter extends CustomPainter {
  GridPainter({
    required this.pattern,
    required this.transform,
    required this.style,
    required this.paletteColors,
    this.selectedCell,
    this.showScaleRuler = false,
    this.rulerPegSpan = 10,
    this.showAnchors = false,
    this.guideStyle = const GuideStyle(),
    this.activeColorIndex,
    this.hideOtherColors = false,
    this.progress,
    this.blink,
  }) : super(repaint: blink);

  /// 引导高亮配色。
  final GuideStyle guideStyle;

  /// 当前引导的色号；null = 无引导（正常显示全部颜色）。
  final int? activeColorIndex;

  /// 非当前色是"隐藏"还是"压暗"。
  final bool hideOtherColors;

  /// 拼豆进度（用于把已完成的格子/颜色画成灰色）。
  final BeadingProgress? progress;

  /// 闪烁动画（0..1）。既作为 `repaint` 触发器（避免每帧重建整棵 widget 树），
  /// 也用于计算高亮脉动；为 null 时高亮为稳定色。
  final Animation<double>? blink;

  final BeadPattern pattern;
  final GridTransform transform;
  final GridStyle style;

  /// 色卡索引 -> 颜色。索引越界时会画成醒目的洋红色，而不是悄悄取模，
  /// 这样"图纸数据与色卡不匹配"会立刻暴露，不会变成一张看着正常的错图。
  final List<Color> paletteColors;

  /// 被选中的格子（画一圈高亮，用于真机验证命中测试）。
  final GridCell? selectedCell;

  /// 是否叠加"标尺校验"辅助线（用实体尺子量屏幕验证是不是真 1:1）。
  final bool showScaleRuler;

  /// 标尺默认跨多少个钉位。
  final int rulerPegSpan;

  /// 是否在屏幕四角画对齐锚点。
  final bool showAnchors;

  /// 锚点距屏幕边缘的内缩距离与臂长（逻辑像素）。
  static const double anchorInset = 8;
  static const double anchorArmLength = 34;
  static const double anchorThickness = 3;

  /// 上一次 [paint] 实际画了多少格／多少条网格线。仅供测试核对。
  int debugCellsPainted = 0;
  int debugLinesPainted = 0;

  /// 索引越界时的告警色。
  static const Color outOfPaletteColor = Color(0xFFFF00FF);

  @override
  void paint(Canvas canvas, Size size) {
    debugCellsPainted = 0;
    debugLinesPainted = 0;

    final Paint background = Paint()..color = style.backgroundColor;
    canvas.drawRect(Offset.zero & size, background);

    final GridRange range = transform.visibleRange(
      size,
      rows: pattern.rows,
      cols: pattern.cols,
    );

    _paintCells(canvas, range);
    _paintGridLines(canvas, range);
    _paintPatternBorder(canvas);
    _paintSelection(canvas);

    if (style.labelsVisibleAt(transform.metrics.pxPerPeg)) {
      _paintLabels(canvas, size, range);
    }
    if (showScaleRuler) {
      _paintScaleRuler(canvas, size);
    }
    if (showAnchors) {
      _paintAnchors(canvas, size);
    }
  }

  /// 四角 L 形对齐锚点：把透明板的对应角贴到锚点上，就能快速摆正。
  void _paintAnchors(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = style.patternBorderColor
      ..strokeWidth = anchorThickness
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    const double inset = anchorInset;
    const double arm = anchorArmLength;
    final double right = size.width - inset;
    final double bottom = size.height - inset;

    canvas
      // 左上
      ..drawLine(
        const Offset(inset, inset),
        const Offset(inset + arm, inset),
        paint,
      )
      ..drawLine(
        const Offset(inset, inset),
        const Offset(inset, inset + arm),
        paint,
      )
      // 右上
      ..drawLine(Offset(right - arm, inset), Offset(right, inset), paint)
      ..drawLine(Offset(right, inset), Offset(right, inset + arm), paint)
      // 左下
      ..drawLine(Offset(inset, bottom - arm), Offset(inset, bottom), paint)
      ..drawLine(Offset(inset, bottom), Offset(inset + arm, bottom), paint)
      // 右下
      ..drawLine(Offset(right - arm, bottom), Offset(right, bottom), paint)
      ..drawLine(Offset(right, bottom - arm), Offset(right, bottom), paint);
  }

  Color _colorFor(int colorIndex) {
    if (colorIndex < 0 || colorIndex >= paletteColors.length) {
      return outOfPaletteColor;
    }
    return paletteColors[colorIndex];
  }

  /// 解析某格实际要画的颜色。返回 null 表示这一格不画（隐藏模式下的非当前色）。
  ///
  /// 优先级：**已完成（整色完成或单格已放）> 当前引导色 > 隐藏/压暗**。
  Color? _resolveCellColor(int row, int col) {
    final int colorIndex = pattern.colorIndexAt(row, col);
    final bool placed = progress?.isCellPlaced(colorIndex, row, col) ?? false;
    if (placed) {
      return guideStyle.completedColor;
    }

    final int? active = activeColorIndex;
    if (active == null) {
      return _colorFor(colorIndex);
    }
    if (colorIndex == active) {
      final Animation<double>? animation = blink;
      if (animation == null) {
        return guideStyle.highlightColor;
      }
      return Color.lerp(
        guideStyle.highlightColor,
        guideStyle.highlightPulseColor,
        animation.value,
      );
    }
    if (hideOtherColors) {
      return null;
    }
    return guideStyle.dimTowards(_colorFor(colorIndex), style.backgroundColor);
  }

  /// 供测试断言单格颜色的解析结果（高亮／压暗／隐藏／已完成）。
  @visibleForTesting
  Color? debugResolveCellColor(int row, int col) => _resolveCellColor(row, col);

  void _paintCells(Canvas canvas, GridRange range) {
    if (range.isEmpty) {
      return;
    }
    final Paint paint = Paint()..isAntiAlias = true;

    switch (style.cellStyle) {
      case PegCellStyle.filled:
        for (int row = range.firstRow; row <= range.lastRow; row++) {
          for (int col = range.firstCol; col <= range.lastCol; col++) {
            final Color? color = _resolveCellColor(row, col);
            if (color == null) {
              continue;
            }
            paint.color = color;
            canvas.drawRect(transform.cellRect(row, col), paint);
            debugCellsPainted++;
          }
        }
      case PegCellStyle.centeredDot:
        final double radius =
            math.min(transform.pxPerPegX, transform.pxPerPegY) *
            style.dotDiameterFactor /
            2;
        for (int row = range.firstRow; row <= range.lastRow; row++) {
          for (int col = range.firstCol; col <= range.lastCol; col++) {
            final Color? color = _resolveCellColor(row, col);
            if (color == null) {
              continue;
            }
            paint.color = color;
            canvas.drawCircle(
              transform.cellRect(row, col).center,
              radius,
              paint,
            );
            debugCellsPainted++;
          }
        }
    }
  }

  void _paintGridLines(Canvas canvas, GridRange range) {
    if (range.isEmpty || style.lineWidth <= 0) {
      return;
    }
    final double x0 =
        transform.origin.dx + range.firstCol * transform.pxPerPegX;
    final double x1 =
        transform.origin.dx + (range.lastCol + 1) * transform.pxPerPegX;
    final double y0 =
        transform.origin.dy + range.firstRow * transform.pxPerPegY;
    final double y1 =
        transform.origin.dy + (range.lastRow + 1) * transform.pxPerPegY;

    final Path path = Path();
    for (int row = range.firstRow; row <= range.lastRow + 1; row++) {
      final double y = transform.origin.dy + row * transform.pxPerPegY;
      path
        ..moveTo(x0, y)
        ..lineTo(x1, y);
      debugLinesPainted++;
    }
    for (int col = range.firstCol; col <= range.lastCol + 1; col++) {
      final double x = transform.origin.dx + col * transform.pxPerPegX;
      path
        ..moveTo(x, y0)
        ..lineTo(x, y1);
      debugLinesPainted++;
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = style.lineColor
        ..strokeWidth = style.lineWidth
        ..style = PaintingStyle.stroke
        ..isAntiAlias = false,
    );
  }

  void _paintPatternBorder(Canvas canvas) {
    canvas.drawRect(
      transform.patternRect(pattern.rows, pattern.cols),
      Paint()
        ..color = style.patternBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _paintSelection(Canvas canvas) {
    final GridCell? cell = selectedCell;
    if (cell == null) {
      return;
    }
    if (cell.row < 0 ||
        cell.col < 0 ||
        cell.row >= pattern.rows ||
        cell.col >= pattern.cols) {
      return;
    }
    canvas.drawRect(
      transform.cellRect(cell.row, cell.col).deflate(1),
      Paint()
        ..color = style.patternBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  void _paintLabels(Canvas canvas, Size size, GridRange range) {
    if (range.isEmpty) {
      return;
    }
    final Color color = style.labelColor ?? style.lineColor;
    // 贴着画布上沿/左沿画坐标条，不占用网格区域。
    for (int col = range.firstCol; col <= range.lastCol; col++) {
      final double x = transform.origin.dx + (col + 0.5) * transform.pxPerPegX;
      _paintText(canvas, '$col', Offset(x, 3), color, alignCenterX: true);
    }
    for (int row = range.firstRow; row <= range.lastRow; row++) {
      final double y = transform.origin.dy + (row + 0.5) * transform.pxPerPegY;
      _paintText(
        canvas,
        '$row',
        Offset(size.width - 3, y),
        color,
        alignRight: true,
      );
    }
  }

  void _paintScaleRuler(Canvas canvas, Size size) {
    // 用实体尺子量这段长度，就能验证"屏幕上的 5mm 是否真的是 5mm"。
    final double unitX = transform.pxPerPegX;
    final double unitY = transform.pxPerPegY;
    const double left = 12;
    final double maxSpanX = (size.width - left - 12) / unitX;
    final int spanX = math.max(1, math.min(rulerPegSpan, maxSpanX.floor()));
    final double baselineY = size.height - 46;
    final double maxSpanY = (baselineY - 40) / unitY;
    final int spanY = math.max(1, math.min(rulerPegSpan, maxSpanY.floor()));

    final Paint mark = Paint()
      ..color = style.patternBorderColor
      ..strokeWidth = 2;

    // 水平标尺
    final double right = left + spanX * unitX;
    canvas.drawLine(Offset(left, baselineY), Offset(right, baselineY), mark);
    for (int i = 0; i <= spanX; i++) {
      final double x = left + i * unitX;
      canvas.drawLine(
        Offset(x, baselineY - 6),
        Offset(x, baselineY + 6),
        mark..strokeWidth = i % 5 == 0 ? 2 : 1,
      );
    }
    final double spanMmX = transform.metrics.pxToMmX(spanX * unitX);
    _paintText(
      canvas,
      '$spanX 格 = ${spanMmX.toStringAsFixed(1)} mm（用尺子量这段）',
      Offset(left, baselineY + 10),
      style.patternBorderColor,
    );

    // 垂直标尺（顺便能看出 x/y 两个方向的微小差异）
    final double baseX = size.width - 24;
    canvas.drawLine(
      Offset(baseX, baselineY),
      Offset(baseX, baselineY - spanY * unitY),
      mark,
    );
    for (int i = 0; i <= spanY; i++) {
      final double y = baselineY - i * unitY;
      canvas.drawLine(Offset(baseX - 6, y), Offset(baseX + 6, y), mark);
    }
    final double spanMmY = transform.metrics.pxToMmY(spanY * unitY);
    _paintText(
      canvas,
      '${spanMmY.toStringAsFixed(1)} mm',
      Offset(baseX - 92, baselineY - spanY * unitY - 20),
      style.patternBorderColor,
    );
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset position,
    Color color, {
    bool alignCenterX = false,
    bool alignRight = false,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 12, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    double dx = position.dx;
    if (alignCenterX) {
      dx -= painter.width / 2;
    } else if (alignRight) {
      dx -= painter.width;
    }
    painter.paint(canvas, Offset(dx, position.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return !identical(oldDelegate.pattern, pattern) ||
        oldDelegate.transform.origin != transform.origin ||
        oldDelegate.transform.pxPerPegX != transform.pxPerPegX ||
        oldDelegate.transform.pxPerPegY != transform.pxPerPegY ||
        oldDelegate.style.lineWidth != style.lineWidth ||
        oldDelegate.style.lineColor != style.lineColor ||
        oldDelegate.style.backgroundColor != style.backgroundColor ||
        oldDelegate.style.patternBorderColor != style.patternBorderColor ||
        oldDelegate.style.cellStyle != style.cellStyle ||
        oldDelegate.style.dotDiameterFactor != style.dotDiameterFactor ||
        oldDelegate.style.showLabels != style.showLabels ||
        oldDelegate.paletteColors.length != paletteColors.length ||
        oldDelegate.selectedCell != selectedCell ||
        oldDelegate.showScaleRuler != showScaleRuler ||
        oldDelegate.showAnchors != showAnchors ||
        oldDelegate.rulerPegSpan != rulerPegSpan ||
        oldDelegate.activeColorIndex != activeColorIndex ||
        oldDelegate.hideOtherColors != hideOtherColors ||
        !identical(oldDelegate.progress, progress) ||
        oldDelegate.blink != blink;
  }
}
