import 'dart:typed_data';

import 'package:bead_light_board/features/import/domain/image_to_pattern.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// 造一张纯色图。
Uint8List solidPng(int width, int height, int r, int g, int b, {int a = 255}) {
  final img.Image image = img.Image(
    width: width,
    height: height,
    numChannels: 4,
  );
  img.fill(image, color: img.ColorRgba8(r, g, b, a));
  return Uint8List.fromList(img.encodePng(image));
}

/// 造一张左右分半的图（左半 left、右半 right）。
Uint8List splitPng(int width, int height, int leftArgb, int rightArgb) {
  final img.Image image = img.Image(
    width: width,
    height: height,
    numChannels: 4,
  );
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int argb = x < width ~/ 2 ? leftArgb : rightArgb;
      image.setPixelRgba(
        x,
        y,
        (argb >> 16) & 0xFF,
        (argb >> 8) & 0xFF,
        argb & 0xFF,
        255,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

/// 造一张 4x4：左上 2x2 为 corner，其余为 rest。
Uint8List quadrantPng(int cornerArgb, int restArgb) {
  final img.Image image = img.Image(width: 4, height: 4, numChannels: 4);
  for (int y = 0; y < 4; y++) {
    for (int x = 0; x < 4; x++) {
      final int argb = (x < 2 && y < 2) ? cornerArgb : restArgb;
      image.setPixelRgba(
        x,
        y,
        (argb >> 16) & 0xFF,
        (argb >> 8) & 0xFF,
        argb & 0xFF,
        255,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

const List<int> kRedGreenBlue = <int>[0xFFFF0000, 0xFF00FF00, 0xFF0000FF];

void main() {
  group('整图导入', () {
    test('纯色图 → 所有格子都是同一个色号', () {
      final ImportOutcome outcome = importImageToPattern(
        ImportRequest(
          sourceBytes: solidPng(8, 8, 255, 0, 0),
          paletteArgb: kRedGreenBlue,
          paletteId: 'test_fixture',
          rows: 4,
          cols: 4,
        ),
      );

      expect(outcome.pattern.rows, 4);
      expect(outcome.pattern.cols, 4);
      expect(outcome.pattern.usedColorCount, 1);
      expect(outcome.pattern.colorIndexAt(0, 0), 0); // 红
      expect(outcome.sourceWidth, 8);
      expect(outcome.sourceHeight, 8);
      expect(outcome.cropPixelWidth, 8);
    });

    test('左右分半 → 左列判红、右列判蓝（降采样正确对齐）', () {
      final ImportOutcome outcome = importImageToPattern(
        ImportRequest(
          sourceBytes: splitPng(8, 4, 0xFFFF0000, 0xFF0000FF),
          paletteArgb: kRedGreenBlue,
          paletteId: 'test_fixture',
          rows: 2,
          cols: 2,
        ),
      );

      expect(outcome.pattern.colorIndexAt(0, 0), 0); // 红
      expect(outcome.pattern.colorIndexAt(1, 0), 0);
      expect(outcome.pattern.colorIndexAt(0, 1), 2); // 蓝
      expect(outcome.pattern.colorIndexAt(1, 1), 2);
    });

    test('非正方形目标（30x20）尺寸正确', () {
      final ImportOutcome outcome = importImageToPattern(
        ImportRequest(
          sourceBytes: solidPng(60, 40, 0, 255, 0),
          paletteArgb: kRedGreenBlue,
          paletteId: 'test_fixture',
          rows: 20,
          cols: 30,
        ),
      );
      expect(outcome.pattern.rows, 20);
      expect(outcome.pattern.cols, 30);
      expect(outcome.pattern.length, 600);
      expect(outcome.pattern.colorIndexAt(19, 29), 1); // 绿
    });

    test('每格平均多像素时，平均值确实被用到（红+蓝 = 紫）', () {
      // 2x2 图：四个像素 红、蓝、红、蓝 → 平均 (127, 0, 127)
      final img.Image image = img.Image(width: 2, height: 2, numChannels: 4)
        ..setPixelRgba(0, 0, 255, 0, 0, 255)
        ..setPixelRgba(1, 0, 0, 0, 255, 255)
        ..setPixelRgba(0, 1, 255, 0, 0, 255)
        ..setPixelRgba(1, 1, 0, 0, 255, 255);

      final ImportOutcome outcome = importImageToPattern(
        ImportRequest(
          sourceBytes: Uint8List.fromList(img.encodePng(image)),
          // 色卡里正好放着这个平均值，能证明"面积平均"真的生效了
          paletteArgb: <int>[0xFF7F007F, 0xFFFF0000, 0xFF0000FF],
          paletteId: 'test_fixture',
          rows: 1,
          cols: 1,
        ),
      );

      expect(outcome.pattern.colorIndexAt(0, 0), 0);
    });
  });

  group('裁剪', () {
    test('只取左上角四分之一：角落色胜出', () {
      final ImportOutcome outcome = importImageToPattern(
        ImportRequest(
          sourceBytes: quadrantPng(0xFFFF0000, 0xFF0000FF),
          paletteArgb: kRedGreenBlue,
          paletteId: 'test_fixture',
          rows: 2,
          cols: 2,
          cropRegion: const CropRegion(
            left: 0,
            top: 0,
            width: 0.5,
            height: 0.5,
          ),
        ),
      );

      expect(outcome.pattern.usedColorCount, 1);
      expect(outcome.pattern.colorIndexAt(0, 0), 0); // 红
      expect(outcome.cropPixelWidth, 2);
      expect(outcome.cropPixelHeight, 2);
    });

    test('取右下角四分之一：底色胜出', () {
      final ImportOutcome outcome = importImageToPattern(
        ImportRequest(
          sourceBytes: quadrantPng(0xFFFF0000, 0xFF0000FF),
          paletteArgb: kRedGreenBlue,
          paletteId: 'test_fixture',
          rows: 2,
          cols: 2,
          cropRegion: const CropRegion(
            left: 0.5,
            top: 0.5,
            width: 0.5,
            height: 0.5,
          ),
        ),
      );
      expect(outcome.pattern.colorIndexAt(0, 0), 2); // 蓝
    });

    test('原图信息与裁剪信息分开报告', () {
      final ImportOutcome outcome = importImageToPattern(
        ImportRequest(
          sourceBytes: solidPng(16, 16, 255, 0, 0),
          paletteArgb: kRedGreenBlue,
          paletteId: 'test_fixture',
          rows: 2,
          cols: 2,
          cropRegion: const CropRegion(
            left: 0.25,
            top: 0.25,
            width: 0.5,
            height: 0.5,
          ),
        ),
      );
      expect(outcome.sourceWidth, 16);
      expect(outcome.sourceHeight, 16);
      expect(outcome.cropPixelWidth, 8);
      expect(outcome.cropPixelHeight, 8);
      expect(outcome.pixelsPerCell, 16);
      expect(outcome.isLowResolution, isFalse);
    });

    test('非法裁剪区域明确报错', () {
      expect(
        () => importImageToPattern(
          ImportRequest(
            sourceBytes: solidPng(8, 8, 255, 0, 0),
            paletteArgb: kRedGreenBlue,
            paletteId: 'test_fixture',
            rows: 2,
            cols: 2,
            cropRegion: const CropRegion(
              left: 0.8,
              top: 0,
              width: 0.5,
              height: 0.5,
            ),
          ),
        ),
        throwsA(
          isA<ImportException>().having(
            (ImportException e) => e.message,
            'message',
            contains('裁剪区域无效'),
          ),
        ),
      );
    });
  });

  group('透明像素', () {
    test('全透明图按指定底色合成（默认暖白）', () {
      final ImportOutcome outcome = importImageToPattern(
        ImportRequest(
          sourceBytes: solidPng(4, 4, 0, 0, 0, a: 0),
          paletteArgb: <int>[kDefaultCompositeBackground, 0xFFFF0000],
          paletteId: 'test_fixture',
          rows: 2,
          cols: 2,
        ),
      );
      expect(outcome.pattern.colorIndexAt(0, 0), 0);
      expect(outcome.pattern.usedColorCount, 1);
    });

    test('可以自定底色', () {
      final ImportOutcome outcome = importImageToPattern(
        ImportRequest(
          sourceBytes: solidPng(4, 4, 0, 0, 0, a: 0),
          paletteArgb: <int>[0xFF00FF00, kDefaultCompositeBackground],
          paletteId: 'test_fixture',
          rows: 1,
          cols: 1,
          compositeBackgroundArgb: 0xFF00FF00,
        ),
      );
      expect(outcome.pattern.colorIndexAt(0, 0), 0);
    });
  });

  group('错误处理', () {
    test('解码失败给出可读原因', () {
      expect(
        () => importImageToPattern(
          ImportRequest(
            sourceBytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
            paletteArgb: kRedGreenBlue,
            paletteId: 'test_fixture',
            rows: 2,
            cols: 2,
          ),
        ),
        throwsA(
          isA<ImportException>().having(
            (ImportException e) => e.message,
            'message',
            contains('无法解码'),
          ),
        ),
      );
    });

    test('空色卡明确报错（不生成一张瞎猜的图）', () {
      expect(
        () => importImageToPattern(
          ImportRequest(
            sourceBytes: solidPng(4, 4, 255, 0, 0),
            paletteArgb: const <int>[],
            paletteId: 'test_fixture',
            rows: 2,
            cols: 2,
          ),
        ),
        throwsA(
          isA<ImportException>().having(
            (ImportException e) => e.message,
            'message',
            contains('色卡是空的'),
          ),
        ),
      );
    });

    test('行列数非法时报参数错误', () {
      expect(
        () => importImageToPattern(
          ImportRequest(
            sourceBytes: solidPng(4, 4, 255, 0, 0),
            paletteArgb: kRedGreenBlue,
            paletteId: 'test_fixture',
            rows: 0,
            cols: 2,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('CropRegion', () {
    test('full 表示整图', () {
      expect(CropRegion.full.isValid, isTrue);
      final rect = CropRegion.full.toPixelRect(10, 20);
      expect(rect.x, 0);
      expect(rect.y, 0);
      expect(rect.width, 10);
      expect(rect.height, 20);
    });

    test('像素矩形至少为 1x1 且不越界', () {
      const CropRegion tiny = CropRegion(
        left: 0.99,
        top: 0.99,
        width: 0.001,
        height: 0.001,
      );
      final rect = tiny.toPixelRect(10, 10);
      expect(rect.width, greaterThanOrEqualTo(1));
      expect(rect.height, greaterThanOrEqualTo(1));
      expect(rect.x + rect.width, lessThanOrEqualTo(10));
      expect(rect.y + rect.height, lessThanOrEqualTo(10));
    });

    test('越界区域判为非法', () {
      expect(
        const CropRegion(left: -0.1, top: 0, width: 0.5, height: 0.5).isValid,
        isFalse,
      );
      expect(
        const CropRegion(left: 0, top: 0, width: 0, height: 0.5).isValid,
        isFalse,
      );
    });
  });
}
