import 'dart:io';

import 'package:bead_light_board/data/models/bead_color.dart';
import 'package:bead_light_board/data/models/palette.dart';
import 'package:bead_light_board/data/repositories/palette_repository.dart';
import 'package:bead_light_board/features/quantize/domain/color_matcher.dart';
import 'package:bead_light_board/features/quantize/domain/color_space.dart';
import 'package:flutter_test/flutter_test.dart';

/// 用**真实的 MARD 色卡**验证量化方向。
///
/// 这类"方向性"断言是必须的：色号对不对只能拿实物核，
/// 但"浅色不能被映射成近黑色"这种事，机器一眼就能看出来。
Future<String> fileLoader(String path) async => File(path).readAsString();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Palette mard;
  late PaletteMatcher matcher;

  setUpAll(() async {
    mard = await PaletteRepository(loader: fileLoader)
        .loadPalette('assets/palettes/mard.json');
    matcher = PaletteMatcher.fromPalette(mard);
  });

  BeadColor pick(int r, int g, int b) => mard.colors[matcher.matchRgb(r, g, b)];

  test('色卡本身：221 色、argb 与 hex 一致', () {
    expect(mard.colors, hasLength(221));
    for (final BeadColor color in mard.colors) {
      final int r = (color.argb >> 16) & 0xFF;
      final int g = (color.argb >> 8) & 0xFF;
      final int b = color.argb & 0xFF;
      // argb 必须与 hex 字段自洽（防止解析层把通道顺序搞反）
      expect(
        color.hex.toUpperCase(),
        '#${r.toRadixString(16).padLeft(2, '0')}'
                '${g.toRadixString(16).padLeft(2, '0')}'
                '${b.toRadixString(16).padLeft(2, '0')}'
            .toUpperCase(),
        reason: '${color.code}',
      );
    }
  });

  test('浅色背景必须映射到浅色（示例图背景 #F0ECE4）', () {
    final BeadColor picked = pick(240, 236, 228);
    final double lightness = argbToLab(picked.argb).l;
    expect(
      lightness,
      greaterThan(75),
      reason: '浅色被映射到了暗色：${picked.code} ${picked.hex}（L=$lightness）',
    );
  });

  test('纯白与纯黑各归其位', () {
    expect(argbToLab(pick(255, 255, 255).argb).l, greaterThan(90));
    expect(argbToLab(pick(0, 0, 0).argb).l, lessThan(15));
  });

  test('红色必须映射到红通道最强的色', () {
    final BeadColor picked = pick(214, 92, 104);
    final int r = (picked.argb >> 16) & 0xFF;
    final int g = (picked.argb >> 8) & 0xFF;
    final int b = picked.argb & 0xFF;
    expect(r, greaterThan(g), reason: '取到 ${picked.code} ${picked.hex}');
    expect(r, greaterThan(b), reason: '取到 ${picked.code} ${picked.hex}');
  });

  test('整张色卡都能匹配（不抛异常、索引都在范围内）', () {
    for (final BeadColor color in mard.colors) {
      final int index = matcher.matchRgb(
        (color.argb >> 16) & 0xFF,
        (color.argb >> 8) & 0xFF,
        color.argb & 0xFF,
      );
      expect(index, inInclusiveRange(0, mard.colors.length - 1));
    }
  });
}
