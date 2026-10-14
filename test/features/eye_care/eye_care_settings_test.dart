import 'dart:ui' show Color;

import 'package:bead_light_board/features/eye_care/domain/eye_care_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('默认值', () {
    test('默认开启护眼、常亮、沉浸式（使用者明确要求的默认值）', () {
      const EyeCareSettings settings = EyeCareSettings();
      expect(settings.enabled, isTrue);
      expect(settings.keepScreenOn, isTrue);
      expect(settings.immersive, isTrue);
      expect(settings.lowContrast, isFalse);
      expect(settings.brightness, 0.85);
      expect(settings.warmth, 0.25);
    });
  });

  group('软件调光', () {
    test('遮罩是深暖棕而不是纯黑（项目禁止纯黑大面积铺底）', () {
      final Color actual = const EyeCareSettings().dimOverlayColor;
      final int argb = actual.toARGB32();
      expect((argb >> 16) & 0xFF, 0x14); // R
      expect((argb >> 8) & 0xFF, 0x10); // G
      expect(argb & 0xFF, 0x0B); // B
      expect(actual, isNot(const Color(0xFF000000)));
    });

    test('alpha 与亮度成反比', () {
      expect(
        const EyeCareSettings(brightness: 1).dimOverlayColor.a,
        closeTo(0, 0.01),
      );
      expect(const EyeCareSettings().dimOverlayColor.a, closeTo(0.15, 0.01));
      expect(
        const EyeCareSettings(brightness: 0.5).dimOverlayColor.a,
        closeTo(0.5, 0.01),
      );
    });

    test('最暗也不会超过 maxDim（再暗就看不清了）', () {
      final EyeCareSettings darkest = const EyeCareSettings().copyWith(
        brightness: 0.0,
      );
      expect(darkest.brightness, 0.15);
      expect(darkest.dimOverlayColor.a, closeTo(EyeCareSettings.maxDim, 0.01));
    });

    test('hasDim 只在确实要调暗时为真', () {
      expect(const EyeCareSettings(brightness: 1).hasDim, isFalse);
      expect(const EyeCareSettings(brightness: 0.84).hasDim, isTrue);
    });
  });

  group('暖色矩阵', () {
    test('抬红压蓝，且不改变透明度', () {
      final List<double> m = const EyeCareSettings(warmth: 1).warmthMatrix;
      expect(m.length, 20);
      expect(m[0], greaterThan(1)); // R 增益
      expect(m[6], greaterThanOrEqualTo(1)); // G 增益
      expect(m[12], lessThan(1)); // B 增益
      expect(m[18], 1); // alpha 行
      expect(m.where((double v) => v != 0).length, 4 + 1 - 1);
    });

    test('各通道增益都在合理范围（不溢出成噪点）', () {
      for (final double warmth in <double>[0, 0.25, 0.5, 1]) {
        final List<double> m = EyeCareSettings(warmth: warmth).warmthMatrix;
        for (final int index in <int>[0, 6, 12]) {
          expect(m[index], inInclusiveRange(0.8, 1.2));
        }
      }
    });

    test('暖度为 0 时不必叠加滤镜', () {
      expect(const EyeCareSettings(warmth: 0).hasWarmth, isFalse);
      expect(const EyeCareSettings(warmth: 0.01).hasWarmth, isTrue);
    });
  });

  group('copyWith 与相等性', () {
    test('只改指定字段', () {
      const EyeCareSettings base = EyeCareSettings();
      final EyeCareSettings next = base.copyWith(lowContrast: true);
      expect(next.lowContrast, isTrue);
      expect(next.brightness, base.brightness);
      expect(next.keepScreenOn, base.keepScreenOn);
      expect(next.immersive, base.immersive);
    });

    test('暖度会被夹到 0..1', () {
      expect(const EyeCareSettings().copyWith(warmth: 5).warmth, 1);
      expect(const EyeCareSettings().copyWith(warmth: -3).warmth, 0);
    });

    test('值相等即视为相同（方便界面判断是否需要重建）', () {
      expect(const EyeCareSettings(), const EyeCareSettings());
      expect(
        const EyeCareSettings(),
        isNot(const EyeCareSettings(brightness: 0.6)),
      );
    });
  });
}
