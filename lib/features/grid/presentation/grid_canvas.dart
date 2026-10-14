import 'package:bead_light_board/data/models/bead_pattern.dart';
import 'package:bead_light_board/features/grid/domain/grid_style.dart';
import 'package:bead_light_board/features/grid/domain/grid_transform.dart';
import 'package:bead_light_board/features/grid/presentation/grid_painter.dart';
import 'package:bead_light_board/features/guide/domain/beading_progress.dart';
import 'package:bead_light_board/features/guide/domain/guide_style.dart';
import 'package:flutter/material.dart';

/// 网格画布：负责手势与绘制，**不持有任何状态**。
///
/// 状态（窗口原点、缩放、选中格、是否锁定）都由上层 `GridScreen` 持有，
/// 这样校准逻辑能被单测覆盖。
///
/// 手势用 `onScale*` 而不是 `onPan*`：Scale 手势同时给出**平移量**
/// （[ScaleUpdateDetails.focalPointDelta]）和**缩放比**（[ScaleUpdateDetails.scale]），
/// 而 GestureDetector 不允许 pan 与 scale 同时生效。
/// 单指拖动时 `scale` 恒为 1，因此平移行为与纯拖动一致。
class GridCanvas extends StatelessWidget {
  const GridCanvas({
    super.key,
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
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.onCellTap,
  });

  final BeadPattern pattern;
  final GridTransform transform;
  final GridStyle style;
  final List<Color> paletteColors;
  final GridCell? selectedCell;
  final bool showScaleRuler;
  final int rulerPegSpan;

  /// 是否在屏幕四角画对齐锚点（帮使用者把透明板摆正）。
  final bool showAnchors;

  /// 引导高亮配色。
  final GuideStyle guideStyle;

  /// 当前引导的色号；null = 无引导。
  final int? activeColorIndex;

  /// 非当前色隐藏（true）还是压暗（false）。
  final bool hideOtherColors;

  /// 拼豆进度。
  final BeadingProgress? progress;

  /// 闪烁动画（同时作为重绘触发器）。
  final Animation<double>? blink;

  /// 手势回调。**锁定时由上层传 null**，从而彻底禁用手势（防误触）。
  final GestureScaleStartCallback? onScaleStart;
  final GestureScaleUpdateCallback? onScaleUpdate;
  final GestureScaleEndCallback? onScaleEnd;

  /// 点击：回调命中的格子；点在图纸外时为 null。锁定时传 null。
  final ValueChanged<GridCell?>? onCellTap;

  @override
  Widget build(BuildContext context) {
    final bool gesturesEnabled =
        onScaleStart != null || onScaleUpdate != null || onScaleEnd != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: gesturesEnabled ? onScaleStart : null,
      onScaleUpdate: gesturesEnabled ? onScaleUpdate : null,
      onScaleEnd: gesturesEnabled ? onScaleEnd : null,
      onTapUp: onCellTap == null
          ? null
          : (TapUpDetails details) => onCellTap!(
              transform.cellAt(
                details.localPosition,
                rows: pattern.rows,
                cols: pattern.cols,
              ),
            ),
      child: SizedBox.expand(
        child: CustomPaint(
          painter: GridPainter(
            pattern: pattern,
            transform: transform,
            style: style,
            paletteColors: paletteColors,
            selectedCell: selectedCell,
            showScaleRuler: showScaleRuler,
            rulerPegSpan: rulerPegSpan,
            showAnchors: showAnchors,
            guideStyle: guideStyle,
            activeColorIndex: activeColorIndex,
            hideOtherColors: hideOtherColors,
            progress: progress,
            blink: blink,
          ),
        ),
      ),
    );
  }
}
