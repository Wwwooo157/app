import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:bead_light_board/features/grid/domain/grid_style.dart';
import 'package:bead_light_board/features/guide/domain/guide_style.dart';

/// 护眼相关的配色预设。
///
/// 普通模式直接沿用 `GridStyle.eyeCare()` / `GuideStyle()`（与 `AppColors` 一致）；
/// 低对比模式换成更暗的线、更弱的高亮、更小的点径 —— 目标是"看得清但不刺眼"。
abstract final class EyeCarePalette {
  /// 网格外观。
  static GridStyle gridStyle({
    required bool lowContrast,
    required double lineWidth,
    required PegCellStyle cellStyle,
  }) {
    if (!lowContrast) {
      return GridStyle.eyeCare(lineWidth: lineWidth, cellStyle: cellStyle);
    }
    return GridStyle(
      lineColor: const Color(0xFF33383D),
      backgroundColor: const Color(0xFF16181A),
      patternBorderColor: const Color(0xFF5F8F83),
      lineWidth: math.min(lineWidth, 0.5),
      cellStyle: cellStyle,
      dotDiameterFactor: 0.38,
    );
  }

  /// 引导高亮外观。
  static GuideStyle guideStyle({required bool lowContrast}) => lowContrast
      ? const GuideStyle(
          highlightColor: Color(0xFF6E9C8D),
          highlightPulseColor: Color(0xFF8FBFAF),
          completedColor: Color(0xFF3A3F45),
          dimFactor: 0.16,
        )
      : const GuideStyle();
}
