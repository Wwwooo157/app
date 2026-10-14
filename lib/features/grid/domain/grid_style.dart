import 'dart:ui' show Color;

/// 格子的画法。
enum PegCellStyle {
  /// 整格填色。看得清配色，但透明板只有孔能透光，实际会偏暗。
  filled,

  /// 只在格子中心画一个圆点（约等于钉子/孔的位置）。
  /// 透明板盖上去后，光只从孔里透出来，这种画法通常更清楚。
  centeredDot,
}

/// 网格外观。颜色**必须**由调用方传入，避免在领域层重复定义主题色。
///
/// [eyeCare] 提供的默认值与 `lib/core/theme/app_theme.dart` 里的 `AppColors` 一致，
/// 并有单测防止两边漂移（项目要求：屏幕当灯板，避免纯白纯黑与高反光配色）。
final class GridStyle {
  const GridStyle({
    required this.lineColor,
    required this.backgroundColor,
    required this.patternBorderColor,
    this.lineWidth = 0.6,
    this.cellStyle = PegCellStyle.centeredDot,
    this.dotDiameterFactor = 0.42,
    this.showLabels = false,
    this.labelColor,
    this.minPxPerPegForLabels = 16,
  });

  /// 网格线颜色。
  final Color lineColor;

  /// 网格线宽度（逻辑像素）。使用者可调。
  final double lineWidth;

  /// 画布底色。
  final Color backgroundColor;

  /// 图纸外框颜色（帮使用者看清图纸边界在哪）。
  final Color patternBorderColor;

  /// 格子画法。
  final PegCellStyle cellStyle;

  /// 圆点直径相对钉位跨度的比例（[PegCellStyle.centeredDot] 时生效）。
  final double dotDiameterFactor;

  /// 是否显示行列号。
  final bool showLabels;

  /// 行列号颜色，默认取 [lineColor]。
  final Color? labelColor;

  /// 钉位跨度小于该值时自动不画行列号（否则字会糊成一团）。
  final double minPxPerPegForLabels;

  /// 与 AppColors 对齐的护眼默认配色。
  factory GridStyle.eyeCare({
    double lineWidth = 0.6,
    PegCellStyle cellStyle = PegCellStyle.centeredDot,
    bool showLabels = false,
  }) => GridStyle(
    lineColor: const Color(0xFF4A5057),
    backgroundColor: const Color(0xFF1B1D1F),
    patternBorderColor: const Color(0xFF7FB3A3),
    lineWidth: lineWidth,
    cellStyle: cellStyle,
    showLabels: showLabels,
  );

  GridStyle copyWith({
    Color? lineColor,
    double? lineWidth,
    Color? backgroundColor,
    Color? patternBorderColor,
    PegCellStyle? cellStyle,
    double? dotDiameterFactor,
    bool? showLabels,
    Color? labelColor,
    double? minPxPerPegForLabels,
  }) => GridStyle(
    lineColor: lineColor ?? this.lineColor,
    lineWidth: lineWidth ?? this.lineWidth,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    patternBorderColor: patternBorderColor ?? this.patternBorderColor,
    cellStyle: cellStyle ?? this.cellStyle,
    dotDiameterFactor: dotDiameterFactor ?? this.dotDiameterFactor,
    showLabels: showLabels ?? this.showLabels,
    labelColor: labelColor ?? this.labelColor,
    minPxPerPegForLabels: minPxPerPegForLabels ?? this.minPxPerPegForLabels,
  );

  /// 给定钉位跨度时，是否该画行列号。
  bool labelsVisibleAt(double pxPerPeg) =>
      showLabels && pxPerPeg >= minPxPerPegForLabels;

  @override
  String toString() =>
      'GridStyle($cellStyle, line=${lineWidth}px, labels=$showLabels)';
}
