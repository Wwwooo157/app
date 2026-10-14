import 'package:bead_light_board/data/models/json_support.dart';
import 'package:bead_light_board/data/models/palette.dart';
import 'package:bead_light_board/data/repositories/board_repository.dart';
import 'package:bead_light_board/data/repositories/palette_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// 假资源加载器：模拟 rootBundle，但完全离线、可控。
AssetTextLoader fakeLoader(Map<String, String> assets) {
  return (String assetPath) async {
    final String? content = assets[assetPath];
    if (content == null) {
      throw StateError('测试资源不存在: $assetPath');
    }
    return content;
  };
}

const String _goodIndex = '''
{
  "schemaVersion": 1,
  "palettes": [
    { "id": "good", "name": "Good", "asset": "assets/palettes/good.json" },
    { "id": "broken", "name": "Broken", "asset": "assets/palettes/broken.json" }
  ]
}
''';

const String _goodPalette = '''
{
  "schemaVersion": 1,
  "id": "good",
  "name": "Good",
  "colors": [ { "code": "A01", "hex": "#112233" } ]
}
''';

const String _brokenPalette = '''
{
  "schemaVersion": 1,
  "id": "broken",
  "name": "Broken",
  "colors": [ { "code": "B01", "hex": "not-a-color" } ]
}
''';

void main() {
  group('PaletteRepository', () {
    test('读取色卡清单', () async {
      final PaletteRepository repository = PaletteRepository(
        loader: fakeLoader(<String, String>{
          PaletteRepository.indexAssetPath: _goodIndex,
        }),
      );

      final List<PaletteIndexEntry> entries = await repository.loadIndex();
      expect(entries.length, 2);
      expect(entries[0].id, 'good');
      expect(entries[0].assetPath, 'assets/palettes/good.json');
      expect(entries[1].name, 'Broken');
    });

    test('清单 schemaVersion 不对时拒绝', () async {
      final PaletteRepository repository = PaletteRepository(
        loader: fakeLoader(<String, String>{
          PaletteRepository.indexAssetPath:
              '{"schemaVersion": 2, "palettes": []}',
        }),
      );
      expect(repository.loadIndex, throwsA(isA<ModelFormatException>()));
    });

    test('单个色卡解析失败不会影响其它色卡，错误经 onError 上报', () async {
      final PaletteRepository repository = PaletteRepository(
        loader: fakeLoader(<String, String>{
          PaletteRepository.indexAssetPath: _goodIndex,
          'assets/palettes/good.json': _goodPalette,
          'assets/palettes/broken.json': _brokenPalette,
        }),
      );

      final List<String> failedPaths = <String>[];
      final List<Palette> palettes = await repository.loadAll(
        onError: (String assetPath, Object error) => failedPaths.add(assetPath),
      );

      expect(palettes.length, 1);
      expect(palettes.single.id, 'good');
      expect(failedPaths, <String>['assets/palettes/broken.json']);
    });

    test('onError 省略时不抛异常，只是跳过坏文件', () async {
      final PaletteRepository repository = PaletteRepository(
        loader: fakeLoader(<String, String>{
          PaletteRepository.indexAssetPath: _goodIndex,
          'assets/palettes/good.json': _goodPalette,
          'assets/palettes/broken.json': _brokenPalette,
        }),
      );
      final List<Palette> palettes = await repository.loadAll();
      expect(palettes.length, 1);
    });
  });

  group('BoardRepository', () {
    test('读取板规格清单', () async {
      final BoardRepository repository = BoardRepository(
        loader: fakeLoader(<String, String>{
          BoardRepository.boardsAssetPath: '''
{
  "schemaVersion": 1,
  "boards": [
    { "id": "square_29", "name": "29x29", "rows": 29, "cols": 29 },
    { "id": "square_52", "name": "52x52", "rows": 52, "cols": 52, "pitchMm": 2.6 }
  ]
}
''',
        }),
      );

      final boards = await repository.loadBoards();
      expect(boards.length, 2);
      expect(boards[0].pegCount, 841);
      expect(boards[1].pitchMm, 2.6);
      expect(boards[1].physicalWidthMm, closeTo(135.2, 0.001));
    });

    test('boards 字段缺失时拒绝', () async {
      final BoardRepository repository = BoardRepository(
        loader: fakeLoader(<String, String>{
          BoardRepository.boardsAssetPath: '{"schemaVersion": 1}',
        }),
      );
      expect(repository.loadBoards, throwsA(isA<ModelFormatException>()));
    });
  });
}
