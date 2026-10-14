import 'package:bead_light_board/data/models/board_spec.dart';
import 'package:bead_light_board/data/models/json_support.dart';
import 'package:bead_light_board/data/repositories/palette_repository.dart'
    show AssetTextLoader;
import 'package:flutter/services.dart' show rootBundle;

/// 拼豆板规格仓库，读取 `assets/boards/boards.json`。
final class BoardRepository {
  BoardRepository({AssetTextLoader? loader})
    : _load = loader ?? _loadFromAssetBundle;

  /// 板规格文件路径。
  static const String boardsAssetPath = 'assets/boards/boards.json';

  static const int supportedSchemaVersion = 1;

  final AssetTextLoader _load;

  /// 读取全部板规格。
  Future<List<BoardSpec>> loadBoards() async {
    final String text = await _load(boardsAssetPath);
    final Map<String, Object?> json = decodeJsonObject(
      text,
      path: boardsAssetPath,
    );

    final Object? version = json['schemaVersion'];
    if (version is! int || version != supportedSchemaVersion) {
      throw ModelFormatException(
        '$boardsAssetPath.schemaVersion',
        '不支持或缺失的版本（期望 $supportedSchemaVersion，实际 $version）',
      );
    }

    final List<Object?> raw = requireList(json, 'boards', boardsAssetPath);
    final List<BoardSpec> boards = <BoardSpec>[];
    for (int i = 0; i < raw.length; i++) {
      final Object? item = raw[i];
      if (item is! Map<String, Object?>) {
        throw ModelFormatException('$boardsAssetPath.boards[$i]', '必须是对象');
      }
      boards.add(BoardSpec.fromJson(item, path: '$boardsAssetPath.boards[$i]'));
    }
    return boards;
  }

  static Future<String> _loadFromAssetBundle(String assetPath) =>
      rootBundle.loadString(assetPath);
}
