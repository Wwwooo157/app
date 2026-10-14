import 'package:bead_light_board/data/models/json_support.dart';
import 'package:bead_light_board/data/models/palette.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 资源文本加载函数。
///
/// 抽成函数类型是为了让单测注入假数据，从而不需要 Flutter 资源环境。
typedef AssetTextLoader = Future<String> Function(String assetPath);

/// 色卡清单里的一条记录。
final class PaletteIndexEntry {
  const PaletteIndexEntry({
    required this.id,
    required this.name,
    required this.assetPath,
  });

  final String id;
  final String name;
  final String assetPath;

  static PaletteIndexEntry fromJson(
    Map<String, Object?> json, {
    required String path,
  }) {
    return PaletteIndexEntry(
      id: requireString(json, 'id', path),
      name: requireString(json, 'name', path),
      assetPath: requireString(json, 'asset', path),
    );
  }

  @override
  String toString() => 'PaletteIndexEntry($id -> $assetPath)';
}

/// 色卡仓库：负责按清单加载 `assets/palettes/*.json`。
///
/// App 无法在运行时枚举资源目录，所以必须靠 [indexAssetPath] 这份清单。
final class PaletteRepository {
  PaletteRepository({AssetTextLoader? loader})
    : _load = loader ?? _loadFromAssetBundle;

  /// 色卡清单路径。
  static const String indexAssetPath = 'assets/palettes/index.json';

  static const int supportedSchemaVersion = 1;

  final AssetTextLoader _load;

  /// 读取色卡清单。
  Future<List<PaletteIndexEntry>> loadIndex() async {
    final String text = await _load(indexAssetPath);
    final Map<String, Object?> json = decodeJsonObject(
      text,
      path: indexAssetPath,
    );

    final Object? version = json['schemaVersion'];
    if (version is! int || version != supportedSchemaVersion) {
      throw ModelFormatException(
        '$indexAssetPath.schemaVersion',
        '不支持或缺失的版本（期望 $supportedSchemaVersion，实际 $version）',
      );
    }

    final List<Object?> raw = requireList(json, 'palettes', indexAssetPath);
    final List<PaletteIndexEntry> entries = <PaletteIndexEntry>[];
    for (int i = 0; i < raw.length; i++) {
      final Object? item = raw[i];
      if (item is! Map<String, Object?>) {
        throw ModelFormatException('$indexAssetPath.palettes[$i]', '必须是对象');
      }
      entries.add(
        PaletteIndexEntry.fromJson(item, path: '$indexAssetPath.palettes[$i]'),
      );
    }
    return entries;
  }

  /// 读取并解析单个色卡文件。解析失败时错误信息里会带上文件路径。
  Future<Palette> loadPalette(String assetPath) async {
    final String text = await _load(assetPath);
    final Map<String, Object?> json = decodeJsonObject(text, path: assetPath);
    return Palette.fromJson(json);
  }

  /// 加载清单里的所有色卡。
  ///
  /// 单个色卡结构有问题时**不会**整批失败，而是把该色卡换成 null 并把错误交给
  /// [onError]（默认忽略），这样"某个品牌文件填错了"不会让整个 App 打不开。
  Future<List<Palette>> loadAll({
    void Function(String assetPath, Object error)? onError,
  }) async {
    final List<PaletteIndexEntry> entries = await loadIndex();
    final List<Palette> palettes = <Palette>[];
    for (final PaletteIndexEntry entry in entries) {
      try {
        palettes.add(await loadPalette(entry.assetPath));
      } catch (error) {
        onError?.call(entry.assetPath, error);
      }
    }
    return palettes;
  }

  static Future<String> _loadFromAssetBundle(String assetPath) =>
      // cache: false 是**故意的**：`loadString` 默认会缓存 Future，
      // 而缓存下来的 Future 属于创建它的那个 fake-async zone —— 在 widget test 里
      // 表现为"第一个测试能加载色卡，后面的测试永远等不到"，而且不报错、
      // 只是色号悄悄退化成 ?N。色卡文件很小，不缓存更稳，
      // 顺带也让热重载后能看到 JSON 的改动。
      rootBundle.loadString(assetPath, cache: false);
}
