import 'dart:ui' show Color;

import 'package:bead_light_board/core/theme/app_theme.dart';
import 'package:bead_light_board/features/eye_care/domain/eye_care_palette.dart';
import 'package:bead_light_board/features/grid/domain/grid_style.dart';
import 'package:bead_light_board/features/guide/domain/guide_style.dart';
import 'package:flutter_test/flutter_test.dart';

/// 相对亮度（用于比较"谁更暗"）。
double luminance(Color color) => color.computeLuminance();

void main() {
  group('普通模式沿用既有配色', () {
    test('网格样式与 GridStyle.eyeCare 一致', () {
      final GridStyle normal = EyeCarePalette.gridStyle(
        lowContrast: false,
        lineWidth: 0.6,
        cellStyle: PegCellStyle.centeredDot,
      );
      final GridStyle reference = GridStyle.eyeCare();
      expect(normal.lineColor, reference.lineColor);
      expect(normal.backgroundColor, reference.backgroundColor);
      expect(normal.lineWidth, reference.lineWidth);
    });

    test('引导样式与 GuideStyle 默认值一致', () {
      final GuideStyle normal = EyeCarePalette.guideStyle(lowContrast: false);
      const GuideStyle reference = GuideStyle();
      expect(normal.highlightColor, reference.highlightColor);
      expect(normal.completedColor, reference.completedColor);
      expect(normal.dimFactor, reference.dimFactor);
    });
  });

  group('低对比模式', () {
    final GridStyle normal = EyeCarePalette.gridStyle(
      lowContrast: false,
      lineWidth: 1.2,
      cellStyle: PegCellStyle.filled,
    );
    final GridStyle low = EyeCarePalette.gridStyle(
      lowContrast: true,
      lineWidth: 1.2,
      cellStyle: PegCellStyle.filled,
    );

    test('网格线更暗、底也更暗', () {
      expect(luminance(low.lineColor), lessThan(luminance(normal.lineColor)));
      expect(
        luminance(low.backgroundColor),
        lessThan(luminance(normal.backgroundColor)),
      );
    });

    test('线宽被压到 0.5 以内，点径更小', () {
      expect(low.lineWidth, lessThanOrEqualTo(0.5));
      expect(low.dotDiameterFactor, lessThan(normal.dotDiameterFactor));
      // 画法不变：低对比只改配色与线宽，不改变图纸内容的表达方式
      expect(low.cellStyle, normal.cellStyle);
    });

    test('引导高亮也变柔和、已完成更暗', () {
      final GuideStyle guideNormal = EyeCarePalette.guideStyle(
        lowContrast: false,
      );
      final GuideStyle guideLow = EyeCarePalette.guideStyle(lowContrast: true);
      expect(
        luminance(guideLow.highlightColor),
        lessThan(luminance(guideNormal.highlightColor)),
      );
      expect(guideLow.dimFactor, lessThan(guideNormal.dimFactor));
    });

    test('低对比配色与主题基调一致：不出现纯白纯黑', () {
      const Color white = Color(0xFFFFFFFF);
      const Color black = Color(0xFF000000);
      final GuideStyle guideLow = EyeCarePalette.guideStyle(lowContrast: true);
      for (final Color color in <Color>[
        low.lineColor,
        low.backgroundColor,
        low.patternBorderColor,
        guideLow.highlightColor,
        guideLow.highlightPulseColor,
        guideLow.completedColor,
      ]) {
        expect(color, isNot(white));
        expect(color, isNot(black));
      }
    });

    test('两种模式都不使用纯白高亮（避免透明板下刺眼）', () {
      expect(
        EyeCarePalette.guideStyle(lowContrast: false).highlightPulseColor,
        isNot(const Color(0xFFFFFFFF)),
      );
      expect(
        EyeCarePalette.guideStyle(lowContrast: true).highlightPulseColor,
        isNot(const Color(0xFFFFFFFF)),
      );
    });
  });

  group('与主题色的关系', () {
    test('普通模式的底色/线色仍等于 AppColors（防止漂移）', () {
      final GridStyle normal = EyeCarePalette.gridStyle(
        lowContrast: false,
        lineWidth: 0.6,
        cellStyle: PegCellStyle.centeredDot,
      );
      expect(normal.backgroundColor, AppColors.background);
      expect(normal.lineColor, AppColors.gridLine);
      expect(
        EyeCarePalette.guideStyle(lowContrast: false).highlightColor,
        AppColors.accent,
      );
    });
  });
}
