import 'dart:ui' show Offset, Size;

import 'package:bead_light_board/features/import/domain/crop_geometry.dart';
import 'package:bead_light_board/features/import/domain/image_to_pattern.dart';
import 'package:flutter_test/flutter_test.dart';

/// 断言两个矩形在容差内相等。
void expectRegion(
  CropRegion actual, {
  required double left,
  required double top,
  required double width,
  required double height,
  double tolerance = 1e-9,
}) {
  expect(actual.left, closeTo(left, tolerance), reason: 'left');
  expect(actual.top, closeTo(top, tolerance), reason: 'top');
  expect(actual.width, closeTo(width, tolerance), reason: 'width');
  expect(actual.height, closeTo(height, tolerance), reason: 'height');
}

void main() {
  group('cover 基准尺寸', () {
    test('宽图以高度为准铺满（左右会被裁掉）', () {
      const CropGeometry geometry = CropGeometry(
        frameSize: Size(100, 100),
        imageWidth: 200,
        imageHeight: 100,
      );
      expect(geometry.baseDisplaySize, const Size(200, 100));
      expect(geometry.topLeft, const Offset(-50, 0));
      expectRegion(
        geometry.normalizedCropRegion,
        left: 0.25,
        top: 0,
        width: 0.5,
        height: 1,
      );
    });

    test('高图以宽度为准铺满（上下会被裁掉）', () {
      const CropGeometry geometry = CropGeometry(
        frameSize: Size(100, 100),
        imageWidth: 100,
        imageHeight: 400,
      );
      expect(geometry.baseDisplaySize, const Size(100, 400));
      expectRegion(
        geometry.normalizedCropRegion,
        left: 0,
        top: 0.375,
        width: 1,
        height: 0.25,
      );
    });

    test('正方形图 + 正方形取景框 = 整图', () {
      const CropGeometry geometry = CropGeometry(
        frameSize: Size(100, 100),
        imageWidth: 64,
        imageHeight: 64,
      );
      expectRegion(
        geometry.normalizedCropRegion,
        left: 0,
        top: 0,
        width: 1,
        height: 1,
      );
    });

    test('非正方形取景框（50x20 图纸）也能整图取用', () {
      const CropGeometry geometry = CropGeometry(
        frameSize: Size(150, 100),
        imageWidth: 300,
        imageHeight: 200,
      );
      expectRegion(
        geometry.normalizedCropRegion,
        left: 0,
        top: 0,
        width: 1,
        height: 1,
      );
    });

    test('尺寸为 0 时安全退化为整图（不会除零）', () {
      const CropGeometry geometry = CropGeometry(
        frameSize: Size.zero,
        imageWidth: 10,
        imageHeight: 10,
      );
      expect(geometry.baseDisplaySize, Size.zero);
      expectRegion(
        geometry.normalizedCropRegion,
        left: 0,
        top: 0,
        width: 1,
        height: 1,
      );
    });
  });

  group('位移夹取：图片必须始终盖满取景框', () {
    const CropGeometry base = CropGeometry(
      frameSize: Size(100, 100),
      imageWidth: 200,
      imageHeight: 100,
    );

    test('往左拖到底时，右边缘正好贴住取景框右边缘', () {
      final CropGeometry moved = base.panned(const Offset(-500, 0));
      expect(moved.offset.dx, closeTo(-50, 1e-9));
      expectRegion(
        moved.normalizedCropRegion,
        left: 0.5,
        top: 0,
        width: 0.5,
        height: 1,
      );
    });

    test('往右拖到底时，左边缘正好贴住取景框左边缘', () {
      final CropGeometry moved = base.panned(const Offset(500, 0));
      expect(moved.offset.dx, closeTo(50, 1e-9));
      expectRegion(
        moved.normalizedCropRegion,
        left: 0,
        top: 0,
        width: 0.5,
        height: 1,
      );
    });

    test('纵向没有可动空间（高度恰好相等）', () {
      expect(base.panned(const Offset(0, 300)).offset.dy, 0);
    });

    test('任何合法位移下，裁剪区域都不会越出原图', () {
      for (final double dx in <double>[-999, -50, 0, 50, 999]) {
        for (final double dy in <double>[-999, 0, 999]) {
          final CropRegion region = base
              .panned(Offset(dx, dy))
              .normalizedCropRegion;
          expect(region.left, greaterThanOrEqualTo(-1e-9), reason: 'dx=$dx');
          expect(region.top, greaterThanOrEqualTo(-1e-9), reason: 'dy=$dy');
          expect(
            region.left + region.width,
            lessThanOrEqualTo(1 + 1e-9),
            reason: 'dx=$dx dy=$dy',
          );
          expect(
            region.top + region.height,
            lessThanOrEqualTo(1 + 1e-9),
            reason: 'dx=$dx dy=$dy',
          );
        }
      }
    });
  });

  group('缩放', () {
    const CropGeometry square = CropGeometry(
      frameSize: Size(100, 100),
      imageWidth: 100,
      imageHeight: 100,
    );

    test('缩放范围被夹在 1..8', () {
      expect(square.zoomed(0.1, const Offset(50, 50)).scale, 1);
      expect(square.zoomed(100, const Offset(50, 50)).scale, 8);
    });

    test('放大后裁剪区域变小（看得更细）', () {
      final CropGeometry zoomed = square.zoomed(2, const Offset(50, 50));
      expectRegion(
        zoomed.normalizedCropRegion,
        left: 0.25,
        top: 0.25,
        width: 0.5,
        height: 0.5,
      );
    });

    test('以焦点缩放时，焦点下的图像内容保持不变', () {
      const Offset focal = Offset(25, 25);
      const CropGeometry before = square;
      final CropGeometry after = square.zoomed(2, focal);
      expect(after.scale, 2);

      // 焦点在取景框里的位置 → 归一化图像坐标，缩放前后应一致
      double normalizedAt(CropGeometry geometry, Offset point) {
        final Offset origin = geometry.topLeft;
        final Size shown = geometry.displaySize;
        return (point.dx - origin.dx) / shown.width;
      }

      expect(
        normalizedAt(after, focal),
        closeTo(normalizedAt(before, focal), 1e-9),
      );
    });

    test('多次缩放与平移后仍然合法', () {
      CropGeometry geometry = square;
      for (int i = 0; i < 12; i++) {
        geometry = geometry
            .zoomed(1.4, const Offset(70, 30))
            .panned(const Offset(-40, 25));
      }
      final CropRegion region = geometry.normalizedCropRegion;
      expect(geometry.scale, lessThanOrEqualTo(CropGeometry.maxScale));
      expect(region.left, greaterThanOrEqualTo(-1e-9));
      expect(region.left + region.width, lessThanOrEqualTo(1 + 1e-9));
      expect(region.top + region.height, lessThanOrEqualTo(1 + 1e-9));
    });
  });

  group('换算回原图像素', () {
    test('sourcePixelRect 与归一化区域一致', () {
      const CropGeometry geometry = CropGeometry(
        frameSize: Size(100, 100),
        imageWidth: 400,
        imageHeight: 200,
      );
      final CropRegion region = geometry.normalizedCropRegion;
      final rect = geometry.sourcePixelRect;
      expect(rect.left, closeTo(region.left * 400, 1e-9));
      expect(rect.width, closeTo(region.width * 400, 1e-9));
      expect(rect.height, closeTo(region.height * 200, 1e-9));
    });

    test('裁剪出来的像素区域可以直接喂给导入流水线', () {
      const CropGeometry geometry = CropGeometry(
        frameSize: Size(100, 100),
        imageWidth: 200,
        imageHeight: 100,
      );
      final CropRegion region = geometry.normalizedCropRegion;
      expect(region.isValid, isTrue);
      final rect = region.toPixelRect(200, 100);
      expect(rect.x, 50);
      expect(rect.width, 100);
      expect(rect.height, 100);
    });
  });
}
