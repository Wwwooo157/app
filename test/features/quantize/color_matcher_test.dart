import 'package:bead_light_board/data/models/palette.dart';
import 'package:bead_light_board/features/quantize/domain/color_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('精确匹配', () {
    final PaletteMatcher matcher = PaletteMatcher.fromArgb(<int>[
      0xFFFF0000,
      0xFF00FF00,
      0xFF0000FF,
    ]);

    test('色卡里的颜色必须匹配到自己（索引即色号索引）', () {
      expect(matcher.matchRgb(255, 0, 0), 0);
      expect(matcher.matchRgb(0, 255, 0), 1);
      expect(matcher.matchRgb(0, 0, 255), 2);
    });

    test('matchArgb 忽略 alpha', () {
      expect(matcher.matchArgb(0x80FF0000), 0);
      expect(matcher.matchArgb(0x000000FF), 2);
    });

    test('邻近颜色仍然匹配到同一色号', () {
      expect(matcher.matchRgb(240, 12, 8), 0);
      expect(matcher.matchRgb(8, 240, 12), 1);
      expect(matcher.matchRgb(12, 8, 240), 2);
    });
  });

  group('用的是 Lab 感知距离，而不是 RGB 距离', () {
    test('紫红色 #800080 在 [红, 蓝] 色卡里应判给蓝（RGB 距离会判给红）', () {
      final PaletteMatcher matcher = PaletteMatcher.fromArgb(<int>[
        0xFFFF0000,
        0xFF0000FF,
      ]);

      // 纯 RGB 欧氏距离：(128,0,128) 到红与到蓝完全相等（都是 180.3），
      // 会退化成"取第一个"。而 Lab 感知上它明显更接近蓝。
      final double rgbToRed = _rgbDistance(128, 0, 128, 255, 0, 0);
      final double rgbToBlue = _rgbDistance(128, 0, 128, 0, 0, 255);
      expect(rgbToRed, closeTo(rgbToBlue, 0.01), reason: '前提：RGB 距离在此打平');

      expect(matcher.matchRgb(128, 0, 128), 1);
    });

    test('深灰在 [黑, 白] 色卡里判给黑', () {
      final PaletteMatcher matcher = PaletteMatcher.fromArgb(<int>[
        0xFF000000,
        0xFFFFFFFF,
      ]);
      expect(matcher.matchRgb(30, 30, 30), 0);
      expect(matcher.matchRgb(230, 230, 230), 1);
    });
  });

  group('边界与错误', () {
    test('空色卡必须明确抛错，不瞎猜一个颜色', () {
      final PaletteMatcher empty = PaletteMatcher.fromArgb(const <int>[]);
      expect(empty.isEmpty, isTrue);
      expect(empty.length, 0);
      expect(() => empty.matchRgb(1, 2, 3), throwsStateError);
    });

    test('单色色卡：任何输入都匹配到它', () {
      final PaletteMatcher single = PaletteMatcher.fromArgb(<int>[0xFF123456]);
      expect(single.matchRgb(0, 0, 0), 0);
      expect(single.matchRgb(255, 255, 255), 0);
    });
  });

  group('从色卡构造', () {
    test('保留色卡顺序（索引对应色号索引）', () {
      final Palette palette = Palette.fromJsonText('''
{
  "schemaVersion": 1,
  "id": "demo",
  "name": "Demo",
  "colors": [
    { "code": "c1", "hex": "#0000FF" },
    { "code": "c2", "hex": "#FF0000" }
  ]
}
''');
      final PaletteMatcher matcher = PaletteMatcher.fromPalette(palette);
      expect(matcher.length, 2);
      expect(matcher.matchRgb(0, 0, 255), 0);
      expect(matcher.matchRgb(255, 0, 0), 1);
    });
  });
}

double _rgbDistance(int r1, int g1, int b1, int r2, int g2, int b2) {
  final int dr = r1 - r2;
  final int dg = g1 - g2;
  final int db = b1 - b2;
  return (dr * dr + dg * dg + db * db).toDouble().abs();
}
