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
    this.revision = 0,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.onCellTap,
    this.onPaintCell,
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

  /// 图纸/进度内容版本号（就地修改时靠它触发重绘）。
  final int revision;

  /// 手势回调。**锁定时由上层传 null**，从而彻底禁用手势（防误触）。
  final GestureScaleStartCallback? onScaleStart;
  final GestureScaleUpdateCallback? onScaleUpdate;
  final GestureScaleEndCallback? onScaleEnd;

  /// 点击：回调命中的格子；点在图纸外时为 null。锁定时传 null。
  final ValueChanged<GridCell?>? onCellTap;

  /// 编辑模式：**单指**绘制回调（落笔与每次移动都会回调命中的格子）。
  ///
  /// 传 null = 非编辑模式。传了它以后，单指不再平移，
  /// 而**双指仍然平移缩放** —— 这是画图类应用的通行手感。
  final ValueChanged<GridCell>? onPaintCell;

  @override
  Widget build(BuildContext context) {
    final bool gesturesEnabled =
        onScaleStart != null || onScaleUpdate != null || onScaleEnd != null;

    /// 单指时把落点换算成格子并回调；返回是否被绘制接管。
    bool paintAt(Offset position, int pointerCount) {
      final ValueChanged<GridCell>? paint = onPaintCell;
      if (paint == null || pointerCount != 1) {
        return false;
      }
      final GridCell? cell = transform.cellAt(
        position,
        rows: pattern.rows,
        cols: pattern.cols,
      );
      if (cell == null) {
        return false;
      }
      paint(cell);
      return true;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // onScaleStart 一律转发：万一手势中途从单指变双指（加了一根手指），
      // 平移缩放要有一个正确的起点，否则会跳一下。
      // 另外**落笔也要在这里画**：单纯点一下不会触发 onScaleUpdate，
      // 只在 update 里画会导致"点一下没反应"。
      onScaleStart: gesturesEnabled
          ? (ScaleStartDetails details) {
              paintAt(details.localFocalPoint, details.pointerCount);
              onScaleStart?.call(details);
            }
          : null,
      onScaleUpdate: gesturesEnabled
          ? (ScaleUpdateDetails details) {
              if (paintAt(details.localFocalPoint, details.pointerCount)) {
                return;
              }
              onScaleUpdate?.call(details);
            }
          : null,
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
            revision: revision,
          ),
        ),
      ),
    );
  }
}
