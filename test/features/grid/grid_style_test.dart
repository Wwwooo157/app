import 'dart:ui' show Color;

import 'package:bead_light_board/core/theme/app_theme.dart';
import 'package:bead_light_board/features/grid/domain/grid_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GridStyle.eyeCare 默认配色', () {
    test('与 AppColors 完全一致（防止领域层与主题层漂移）', () {
      final GridStyle style = GridStyle.eyeCare();
      expect(style.lineColor, AppColors.gridLine);
      expect(style.backgroundColor, AppColors.background);
      expect(style.patternBorderColor, AppColors.accent);
    });

    test('不使用纯白纯黑（项目对护眼的硬要求）', () {
      final GridStyle style = GridStyle.eyeCare();
      const Color white = Color(0xFFFFFFFF);
      const Color black = Color(0xFF000000);
      for (final Color color in <Color>[
        style.lineColor,
        style.backgroundColor,
        style.patternBorderColor,
      ]) {
        expect(color, isNot(white));
        expect(color, isNot(black));
      }
    });

    test('默认画法是居中亮点而不是整格填充', () {
      expect(GridStyle.eyeCare().cellStyle, PegCellStyle.centeredDot);
      expect(GridStyle.eyeCare().showLabels, isFalse);
    });
  });

  group('行列号显示阈值', () {
    test('开启后仍需钉位足够大才显示，避免糊成一团', () {
      final GridStyle style = GridStyle.eyeCare(showLabels: true);
      expect(style.labelsVisibleAt(20), isTrue);
      expect(style.labelsVisibleAt(16), isTrue);
      expect(style.labelsVisibleAt(15.9), isFalse);
    });

    test('关闭时永远不显示', () {
      final GridStyle style = GridStyle.eyeCare();
      expect(style.labelsVisibleAt(40), isFalse);
    });
  });

  group('copyWith', () {
    test('只改指定字段，其余保持不变', () {
      final GridStyle base = GridStyle.eyeCare();
      final GridStyle thicker = base.copyWith(
        lineWidth: 1.4,
        cellStyle: PegCellStyle.filled,
      );
      expect(thicker.lineWidth, 1.4);
      expect(thicker.cellStyle, PegCellStyle.filled);
      expect(thicker.lineColor, base.lineColor);
      expect(thicker.backgroundColor, base.backgroundColor);
      expect(thicker.dotDiameterFactor, base.dotDiameterFactor);
    });
  });
}
