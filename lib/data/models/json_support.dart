import 'dart:convert';

/// JSON 结构错误。
///
/// [path] 指出出错字段的位置（例如 `colors[3].hex`），方便用户对着色卡文件改。
final class ModelFormatException implements Exception {
  const ModelFormatException(this.path, this.message);

  /// 出错字段路径。
  final String path;

  /// 人类可读的原因。
  final String message;

  @override
  String toString() => '数据格式错误 [$path]: $message';
}

/// 把 JSON 文本解析成顶层对象；失败时抛出带路径的 [ModelFormatException]。
Map<String, Object?> decodeJsonObject(String source, {required String path}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (error) {
    throw ModelFormatException(path, 'JSON 解析失败：${error.message}');
  }
  if (decoded is! Map<String, Object?>) {
    throw ModelFormatException(path, '顶层必须是 JSON 对象');
  }
  return decoded;
}

/// 取必填字符串字段。
String requireString(Map<String, Object?> json, String key, String path) {
  final Object? value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw ModelFormatException('$path.$key', '必填，且必须是非空字符串');
  }
  return value.trim();
}

/// 取可选字符串字段（空字符串视为未填）。
String? optionalString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw ModelFormatException(key, '必须是字符串');
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// 取必填整数字段（JSON 里不能写成字符串）。
int requireInt(Map<String, Object?> json, String key, String path) {
  final Object? value = json[key];
  if (value is! int) {
    throw ModelFormatException('$path.$key', '必填，且必须是整数');
  }
  return value;
}

/// 取必填正整数字段。
int requirePositiveInt(Map<String, Object?> json, String key, String path) {
  final int value = requireInt(json, key, path);
  if (value <= 0) {
    throw ModelFormatException('$path.$key', '必须大于 0，实际为 $value');
  }
  return value;
}

/// 取可选正数字段（毫米数，允许小数）。缺失或为 null 表示"未确认"。
double? optionalPositiveDouble(
  Map<String, Object?> json,
  String key,
  String path,
) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! num) {
    throw ModelFormatException('$path.$key', '必须是数字或 null');
  }
  final double result = value.toDouble();
  if (result <= 0) {
    throw ModelFormatException('$path.$key', '必须大于 0 或为 null，实际为 $result');
  }
  return result;
}

/// 取必填数组字段。
List<Object?> requireList(Map<String, Object?> json, String key, String path) {
  final Object? value = json[key];
  if (value is! List<Object?>) {
    throw ModelFormatException('$path.$key', '必填，且必须是数组');
  }
  return value;
}

/// 取必填对象字段。
Map<String, Object?> requireMap(
  Map<String, Object?> json,
  String key,
  String path,
) {
  final Object? value = json[key];
  if (value is! Map<String, Object?>) {
    throw ModelFormatException('$path.$key', '必填，且必须是对象');
  }
  return value;
}
