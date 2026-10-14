import 'package:bead_light_board/features/quantize/domain/color_space.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sRGB -> Lab 参考值（D65，与标准表一致）', () {
    test('白色', () {
      final LabColor white = srgbToLab(255, 255, 255);
      expect(white.l, closeTo(100, 0.01));
      expect(white.a, closeTo(0, 0.02));
      expect(white.b, closeTo(0, 0.02));
    });

    test('黑色', () {
      final LabColor black = srgbToLab(0, 0, 0);
      expect(black.l, closeTo(0, 0.01));
      expect(black.a, closeTo(0, 0.01));
      expect(black.b, closeTo(0, 0.01));
    });

    test('红绿蓝三原色的 L/a/b 与标准值一致', () {
      final LabColor red = srgbToLab(255, 0, 0);
      expect(red.l, closeTo(53.24, 0.05));
      expect(red.a, closeTo(80.09, 0.05));
      expect(red.b, closeTo(67.20, 0.05));

      final LabColor green = srgbToLab(0, 255, 0);
      expect(green.l, closeTo(87.73, 0.05));
      expect(green.a, closeTo(-86.18, 0.05));
      expect(green.b, closeTo(83.18, 0.05));

      final LabColor blue = srgbToLab(0, 0, 255);
      expect(blue.l, closeTo(32.30, 0.05));
      expect(blue.a, closeTo(79.19, 0.05));
      expect(blue.b, closeTo(-107.86, 0.05));
    });
  });

  group('中性轴与单调性', () {
    test('灰阶必须落在 a≈0、b≈0 的中性轴上', () {
      for (final int value in <int>[0, 32, 64, 128, 192, 255]) {
        final LabColor gray = srgbToLab(value, value, value);
        expect(gray.a.abs(), lessThan(0.01), reason: 'v=$value');
        expect(gray.b.abs(), lessThan(0.02), reason: 'v=$value');
      }
    });

    test('亮度随灰阶单调递增，且中灰约为 53', () {
      double previous = -1;
      for (final int value in <int>[0, 16, 32, 64, 128, 192, 255]) {
        final double l = srgbToLab(value, value, value).l;
        expect(l, greaterThan(previous));
        previous = l;
      }
      expect(srgbToLab(128, 128, 128).l, closeTo(53.6, 0.5));
    });

    test('亮度与人眼感受一致：绿色比蓝色亮得多（RGB 里看不出来）', () {
      expect(srgbToLab(0, 255, 0).l, greaterThan(srgbToLab(0, 0, 255).l + 40));
    });
  });

  group('色差', () {
    test('自身距离为 0，且距离对称', () {
      final LabColor a = srgbToLab(10, 20, 30);
      final LabColor b = srgbToLab(200, 100, 50);
      expect(a.distanceTo(a), 0);
      expect(a.distanceTo(b), closeTo(b.distanceTo(a), 1e-9));
      expect(a.distanceTo(b), greaterThan(0));
    });

    test('相近颜色距离小于差异大的颜色', () {
      final LabColor target = srgbToLab(100, 100, 100);
      expect(
        target.distanceTo(srgbToLab(110, 100, 100)),
        lessThan(target.distanceTo(srgbToLab(255, 0, 0))),
      );
    });
  });

  group('ARGB 辅助', () {
    test('argbToLab 忽略 alpha', () {
      expect(argbToLab(0xFFFF0000).l, closeTo(argbToLab(0x80FF0000).l, 1e-9));
      expect(argbToLab(0x000000FF).b, closeTo(argbToLab(0xFF0000FF).b, 1e-9));
    });
  });
}
