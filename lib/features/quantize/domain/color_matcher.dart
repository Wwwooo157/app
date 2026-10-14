import 'package:bead_light_board/data/models/bead_color.dart';
import 'package:bead_light_board/data/models/palette.dart';
import 'package:bead_light_board/features/quantize/domain/color_space.dart';

/// 色卡匹配器：把任意 RGB 映射到色卡里**感知最接近**的色号。
///
/// 色卡的 Lab 值在构造时预计算一次（52 色也只是 52 次换算），
/// 之后每个格子只做一次线性扫描 —— 52×52 图纸共 2704 次匹配，完全够快。
final class PaletteMatcher {
  PaletteMatcher._(this._labColors, this._argbColors);

  /// 由 ARGB 颜色列表构造。
  factory PaletteMatcher.fromArgb(List<int> argbColors) {
    final List<LabColor> labs = <LabColor>[
      for (final int argb in argbColors) argbToLab(argb),
    ];
    return PaletteMatcher._(labs, List<int>.unmodifiable(argbColors));
  }

  /// 由色卡构造。
  factory PaletteMatcher.fromPalette(Palette palette) =>
      PaletteMatcher.fromArgb(<int>[
        for (final BeadColor color in palette.colors) color.argb,
      ]);

  final List<LabColor> _labColors;
  final List<int> _argbColors;

  /// 色卡颜色数。
  int get length => _argbColors.length;

  /// 色卡是否为空。
  bool get isEmpty => _argbColors.isEmpty;

  /// 匹配 RGB，返回色卡索引。
  ///
  /// 色卡为空时抛 [StateError]：宁可明确失败，也不要瞎猜一个颜色。
  int matchRgb(int r, int g, int b) {
    if (isEmpty) {
      throw StateError('色卡为空，无法匹配颜色');
    }
    final LabColor target = srgbToLab(r, g, b);
    int bestIndex = 0;
    double bestDistance = double.infinity;
    for (int i = 0; i < _labColors.length; i++) {
      final double distance = target.distanceTo(_labColors[i]);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
        if (distance == 0) {
          break; // 完全一致，不可能更近
        }
      }
    }
    return bestIndex;
  }

  /// 匹配 ARGB（忽略 alpha）。
  int matchArgb(int argb) =>
      matchRgb((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);

  @override
  String toString() => 'PaletteMatcher($length colors)';
}
