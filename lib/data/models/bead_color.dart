import 'package:bead_light_board/data/models/json_support.dart';

/// 一个色号。
///
/// 颜色用 `int`（0xAARRGGBB）保存，刻意不依赖 Flutter 的 `Color`，
/// 这样模型层与解析逻辑都能在纯 Dart 单测里跑，不需要 widget 环境。
final class BeadColor {
  const BeadColor({
    required this.code,
    required this.argb,
    this.name,
    this.series,
  });

  /// 色号（品牌给出的编号，例如 MARD 的 "A01"）。在同一个色卡内唯一。
  final String code;

  /// 不透明颜色，0xFFRRGGBB。
  final int argb;

  /// 色名，可空。
  final String? name;

  /// 系列/分组，可空，用于排序与分组显示。
  final String? series;

  /// 只接受 `#RRGGBB`（6 位，不接受 8 位带透明度写法：豆子颜色本身不透明）。
  static final RegExp _hexPattern = RegExp(r'^#([0-9a-fA-F]{6})$');

  /// 从 JSON 解析；[path] 用于报错定位，例如 `colors[3]`。
  factory BeadColor.fromJson(
    Map<String, Object?> json, {
    required String path,
  }) {
    final String code = requireString(json, 'code', path);

    final Object? rawHex = json['hex'];
    if (rawHex is! String) {
      throw ModelFormatException('$path.hex', '必填，且必须是字符串，例如 "#F2F2F0"');
    }
    final RegExpMatch? match = _hexPattern.firstMatch(rawHex.trim());
    if (match == null) {
      throw ModelFormatException(
        '$path.hex',
        '必须是 #RRGGBB 形式（6 位十六进制），实际为 "$rawHex"',
      );
    }
    final int rgb = int.parse(match.group(1)!, radix: 16);

    return BeadColor(
      code: code,
      argb: 0xFF000000 | rgb,
      name: optionalString(json, 'name'),
      series: optionalString(json, 'series'),
    );
  }

  /// 转回 `#RRGGBB` 文本。
  String get hex =>
      '#${(argb & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  String toString() => 'BeadColor($code, $hex${name == null ? '' : ', $name'})';

  @override
  bool operator ==(Object other) =>
      other is BeadColor &&
      other.code == code &&
      other.argb == argb &&
      other.name == name &&
      other.series == series;

  @override
  int get hashCode => Object.hash(code, argb, name, series);
}
