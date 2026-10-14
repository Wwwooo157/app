import 'dart:io';

import 'package:bead_light_board/data/models/bead_color.dart';
import 'package:bead_light_board/data/models/board_spec.dart';
import 'package:bead_light_board/data/models/palette.dart';
import 'package:bead_light_board/data/repositories/board_repository.dart';
import 'package:bead_light_board/data/repositories/palette_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// 直接读磁盘上的真实资源文件，走真实解析代码。
///
/// 目的：保证**随包发出的 JSON 文件确实合法**，而不是只有构造出来的假数据能过。
Future<String> fileLoader(String path) async => File(path).readAsString();

void main() {
  group('随包资源校验', () {
    test('色卡清单可解析，且每个品牌色卡 id 与清单一致', () async {
      final PaletteRepository repository = PaletteRepository(
        loader: fileLoader,
      );

      final List<PaletteIndexEntry> entries = await repository.loadIndex();
      expect(entries, isNotEmpty, reason: '色卡清单不应为空');

      for (final PaletteIndexEntry entry in entries) {
        // 解析失败会直接让本测试失败——这正是我们要的保护
        final Palette palette = await repository.loadPalette(entry.assetPath);
        expect(
          palette.id,
          entry.id,
          reason: '${entry.assetPath} 内的 id 必须与清单中的 id 一致',
        );
        expect(palette.name, isNotEmpty);
      }
    });

    test('MARD 色卡有真实数据，且 221/291 的结构自洽', () async {
      final PaletteRepository repository = PaletteRepository(
        loader: fileLoader,
      );

      final Palette mard = await repository.loadPalette(
        'assets/palettes/mard.json',
      );
      expect(mard.isEmpty, isFalse, reason: 'MARD 是默认色卡，必须非空');
      expect(mard.colors, hasLength(221), reason: 'MARD 主流体系为 221 色');
      // 色号唯一性由解析器保证（重复会直接抛错），这里再钉一次
      expect(mard.colors.map((BeadColor c) => c.code).toSet(), hasLength(221));

      final Palette mard291 = await repository.loadPalette(
        'assets/palettes/mard291.json',
      );
      expect(mard291.colors, hasLength(291));

      // 291 是 221 的扩展：221 的色号应被 291 全部覆盖
      final Set<String> codes221 = mard.colors
          .map((BeadColor c) => c.code)
          .toSet();
      final Set<String> codes291 = mard291.colors
          .map((BeadColor c) => c.code)
          .toSet();
      expect(
        codes291.containsAll(codes221),
        isTrue,
        reason: '291 应包含 221 的全部色号',
      );
    });

    test('尚未填写的品牌色卡保持为空（等使用者填）', () async {
      final PaletteRepository repository = PaletteRepository(
        loader: fileLoader,
      );

      // 只列**确实还是空**的品牌；MARD 已经有真实数据，不在此列。
      for (final String path in <String>[
        'assets/palettes/perler.json',
        'assets/palettes/hama.json',
        'assets/palettes/artkal.json',
      ]) {
        final Palette palette = await repository.loadPalette(path);
        expect(
          palette.isEmpty,
          isTrue,
          reason: '$path 仍未填写；空色卡会让量化功能被禁用（刻意的设计）',
        );
      }

      final Palette fixture = await repository.loadPalette(
        'assets/palettes/test_fixture.json',
      );
      expect(fixture.isEmpty, isFalse, reason: '夹具色卡需要非空，量化单测依赖它');
      expect(fixture.colors.map((color) => color.code).toList(), <String>[
        'T01',
        'T02',
        'T03',
        'T04',
        'T05',
        'T06',
        'T07',
        'T08',
      ]);
      expect(
        fixture.name.contains('非真实色号'),
        isTrue,
        reason: '夹具色卡必须在名称上明确标注，不能与真实色卡混淆',
      );
    });

    test('板规格文件可解析，包含 29x29 与 52x52', () async {
      final BoardRepository repository = BoardRepository(loader: fileLoader);
      final List<BoardSpec> boards = await repository.loadBoards();

      final Map<String, BoardSpec> byId = <String, BoardSpec>{
        for (final BoardSpec spec in boards) spec.id: spec,
      };
      expect(byId.keys, containsAll(<String>['square_29', 'square_52']));
      expect(byId['square_29']!.pegCount, 841);
      expect(byId['square_52']!.pegCount, 2704);

      // 间距由使用者确认（5mm，midi 标准豆），因此这里是明确值而不是 null。
      // 变更该值必须同步 docs/dev-notes.md 里的屏幕适配测算。
      for (final BoardSpec spec in boards) {
        expect(spec.pitchMm, 5, reason: '使用者确认的豆子中心间距为 5mm');
      }
      expect(byId['square_29']!.physicalWidthMm, 145);
      expect(
        byId['square_52']!.physicalWidthMm,
        260,
        reason: '52x52 @5mm = 260mm 见方，超出平板屏幕可用区，必须走分区引导',
      );
    });
  });
}
