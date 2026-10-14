import 'dart:ui' show Color;

/// 引导高亮的配色。
///
/// 默认值与 `AppColors` 保持一致（有单测防止漂移）：高亮用柔和青绿，
/// 已完成用中灰，**绝不用纯白**——屏幕要垫在透明板下当灯板，纯白高亮会刺眼。
final class GuideStyle {
  const GuideStyle({
    this.highlightColor = const Color(0xFF7FB3A3),
    this.highlightPulseColor = const Color(0xFFB9E3D5),
    this.completedColor = const Color(0xFF4A5057),
    this.dimFactor = 0.22,
  });

  /// 当前引导色的常态高亮色。
  final Color highlightColor;

  /// 闪烁时脉动到的更亮色（仍不是纯白）。
  final Color highlightPulseColor;

  /// 已完成（整色完成，或单格已放）的颜色。
  final Color completedColor;

  /// 非当前色的保留比例（0 = 完全不可见，1 = 原色）。
  /// 默认 0.22：能看出整体轮廓，又不干扰当前色。
  final double dimFactor;

  /// 把颜色按 [dimFactor] 往背景方向压暗。
  Color dimTowards(Color color, Color background) =>
      Color.lerp(background, color, dimFactor)!;

  GuideStyle copyWith({
    Color? highlightColor,
    Color? highlightPulseColor,
    Color? completedColor,
    double? dimFactor,
  }) => GuideStyle(
    highlightColor: highlightColor ?? this.highlightColor,
    highlightPulseColor: highlightPulseColor ?? this.highlightPulseColor,
    completedColor: completedColor ?? this.completedColor,
    dimFactor: dimFactor ?? this.dimFactor,
  );

  @override
  String toString() => 'GuideStyle(dim=$dimFactor)';
}
