import 'dart:io';
import 'dart:typed_data';

import 'package:bead_light_board/data/models/bead_color.dart';
import 'package:bead_light_board/data/models/palette.dart';
import 'package:bead_light_board/data/repositories/palette_repository.dart';
import 'package:bead_light_board/features/import/domain/image_to_pattern.dart';
import 'package:bead_light_board/features/quantize/domain/color_space.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// 端到端：**真实的示例图 + 真实的 MARD 色卡**跑一遍导入。
///
/// 这条测试专门守一类"方向性"错误：示例图是"暖白背景 + 红心"，
/// 量化后主色必须是浅色、心形必须是红色系 —— 如果哪天出现
/// "浅色被映射成近黑色"，这里会立刻炸。
Future<String> fileLoader(String path) async => File(path).readAsString();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('示例图 → MARD 量化：主色浅、心形红', () async {
    final Palette mard = await PaletteRepository(loader: fileLoader)
        .loadPalette('assets/palettes/mard.json');
    final List<int> argb = <int>[
      for (final BeadColor color in mard.colors) color.argb,
    ];

    final Uint8List bytes = File('assets/samples/sample_heart.png')
        .readAsBytesSync();

    final ImportOutcome outcome = importImageToPattern(
      ImportRequest(
        sourceBytes: bytes,
        paletteArgb: argb,
        paletteId: mard.id,
        rows: 52,
        cols: 52,
      ),
    );

    final Map<int, int> usage = outcome.pattern.usageByColorIndex;
    final List<MapEntry<int, int>> sorted = usage.entries.toList()
      ..sort(
        (MapEntry<int, int> a, MapEntry<int, int> b) =>
            b.value.compareTo(a.value),
      );

    final StringBuffer report = StringBuffer('量化结果（前 6 色）：');
    for (final MapEntry<int, int> entry in sorted.take(6)) {
      final BeadColor color = mard.colors[entry.key];
      report.write(
        '\n  ${color.code} ${color.hex} × ${entry.value} 格'
        '（L=${argbToLab(color.argb).l.toStringAsFixed(1)}）',
      );
    }
    // ignore: avoid_print
    print(report.toString());

    // 主色应当是浅色：示例图 80% 以上是暖白背景
    final BeadColor dominant = mard.colors[sorted.first.key];
    expect(
      argbToLab(dominant.argb).l,
      greaterThan(75),
      reason: '主色应当是浅色，实际是 ${dominant.code} ${dominant.hex}',
    );
    expect(
      sorted.first.value,
      greaterThan(52 * 52 ~/ 2),
      reason: '暖白背景应当占据过半格子',
    );

    // 应当存在一个红色系颜色被用到（心形）
    final bool hasRed = sorted.any((MapEntry<int, int> entry) {
      final int r = (mard.colors[entry.key].argb >> 16) & 0xFF;
      final int g = (mard.colors[entry.key].argb >> 8) & 0xFF;
      final int b = mard.colors[entry.key].argb & 0xFF;
      return r > g + 40 && r > b + 40;
    });
    expect(hasRed, isTrue, reason: '心形应当产生至少一个红色系色号');
  });

  test('示例图本身确实是浅底（防止测试夹具自己坏了）', () {
    final img.Image image = img.decodeImage(
      File('assets/samples/sample_heart.png').readAsBytesSync(),
    )!;

    // 四角应当是暖白背景
    for (final (int x, int y) in <(int, int)>[
      (4, 4),
      (image.width - 5, 4),
      (4, image.height - 5),
      (image.width - 5, image.height - 5),
    ]) {
      final img.Pixel corner = image.getPixel(x, y);
      expect(corner.r, greaterThan(200), reason: '($x,$y)');
      expect(corner.g, greaterThan(200), reason: '($x,$y)');
      expect(corner.b, greaterThan(200), reason: '($x,$y)');
    }

    // 红色像素应占合理比例（心形占一部分，但不该占满全图）
    int reddish = 0;
    int total = 0;
    for (int y = 0; y < image.height; y += 4) {
      for (int x = 0; x < image.width; x += 4) {
        final img.Pixel pixel = image.getPixel(x, y);
        total++;
        if (pixel.r > 150 && pixel.r > pixel.g + 40 && pixel.r > pixel.b + 40) {
          reddish++;
        }
      }
    }
    final double ratio = reddish / total;
    expect(ratio, greaterThan(0.05), reason: '心形应当占一定比例，实际 $ratio');
    expect(ratio, lessThan(0.6), reason: '心形不该占满全图，实际 $ratio');
  });
}
