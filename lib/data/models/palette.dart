import 'package:bead_light_board/data/models/bead_color.dart';
import 'package:bead_light_board/data/models/json_support.dart';

/// 一个品牌的色卡。
///
/// 设计原则：**App 不内置任何色号**。真实色号由使用者填进
/// `assets/palettes/<id>.json`，本类只负责按结构解析并严格校验。
/// 因此 `colors` 允许为空数组（表示"尚未填写"），此时 [isEmpty] 为 true，
/// 颜色量化功能必须被禁用而不是瞎猜颜色。
final class Palette {
  const Palette({
    required this.id,
    required this.name,
    required this.colors,
    this.pitchMm,
    this.source,
  });

  /// 当前支持的色卡文件结构版本。
  static const int supportedSchemaVersion = 1;

  /// 色卡标识，例如 `mard`。
  final String id;

  /// 显示名，例如 `MARD`。
  final String name;

  /// 全部色号（顺序即索引，[BeadPattern] 里存的就是这个索引）。
  final List<BeadColor> colors;

  /// 该品牌豆子的标称间距（毫米）。null 表示未确认，由标尺校准决定。
  final double? pitchMm;

  /// 数据来源说明，便于日后核对/更新。
  final String? source;

  /// 色卡是否为空（还没填真实色号）。
  bool get isEmpty => colors.isEmpty;

  /// 色号数量。
  int get length => colors.length;

  /// 按色号文本找索引，找不到返回 null。
  int? indexOfCode(String code) {
    for (int i = 0; i < colors.length; i++) {
      if (colors[i].code == code) {
        return i;
      }
    }
    return null;
  }

  /// 从 JSON 对象解析，严格校验结构。
  static Palette fromJson(Map<String, Object?> json) {
    final Object? version = json['schemaVersion'];
    if (version is! int) {
      throw const ModelFormatException('schemaVersion', '必填，且必须是整数');
    }
    if (version != supportedSchemaVersion) {
      throw ModelFormatException(
        'schemaVersion',
        '不支持的版本 $version，本版本只支持 $supportedSchemaVersion',
      );
    }

    final String id = requireString(json, 'id', '');
    final String name = requireString(json, 'name', '');

    final List<Object?> rawColors = requireList(json, 'colors', '');
    final List<BeadColor> colors = <BeadColor>[];
    final Map<String, int> firstIndexByCode = <String, int>{};

    for (int i = 0; i < rawColors.length; i++) {
      final Object? item = rawColors[i];
      if (item is! Map<String, Object?>) {
        throw ModelFormatException('colors[$i]', '必须是对象');
      }
      final BeadColor color = BeadColor.fromJson(item, path: 'colors[$i]');
      final int? duplicateOf = firstIndexByCode[color.code];
      if (duplicateOf != null) {
        throw ModelFormatException(
          'colors[$i].code',
          '色号 "${color.code}" 与 colors[$duplicateOf] 重复，色号在同一个色卡内必须唯一',
        );
      }
      firstIndexByCode[color.code] = i;
      colors.add(color);
    }

    return Palette(
      id: id,
      name: name,
      colors: List<BeadColor>.unmodifiable(colors),
      pitchMm: optionalPositiveDouble(json, 'pitchMm', ''),
      source: optionalString(json, 'source'),
    );
  }

  /// 从 JSON 文本解析。
  static Palette fromJsonText(String source) =>
      Palette.fromJson(decodeJsonObject(source, path: 'palette'));

  /// 导出为可写回的 JSON（供"另存为模板"等场景使用）。
  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': supportedSchemaVersion,
    'id': id,
    'name': name,
    if (pitchMm != null) 'pitchMm': pitchMm,
    if (source != null) 'source': source,
    'colors': colors
        .map(
          (BeadColor color) => <String, Object?>{
            'code': color.code,
            if (color.name != null) 'name': color.name,
            'hex': color.hex,
            if (color.series != null) 'series': color.series,
          },
        )
        .toList(),
  };

  @override
  String toString() => 'Palette($id, ${colors.length} colors)';
}
