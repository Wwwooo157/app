import 'dart:convert';
import 'dart:typed_data';

import 'package:bead_light_board/data/models/bead_pattern.dart';
import 'package:bead_light_board/data/models/json_support.dart';
import 'package:bead_light_board/features/guide/domain/beading_progress.dart';
import 'package:bead_light_board/features/guide/domain/guide_stats.dart';

/// 一个拼豆项目：图纸 + 进度 + 元数据。
///
/// 存成 JSON 文件（见 [ProjectRepository]）：图纸与进度都是二进制位图，
/// 用 base64 编码后放进 JSON —— 文件仍然可以用文本编辑器打开看，
/// 只是位图部分不直观（另有 rows/cols 与色号统计可供人核对）。
final class Project {
  const Project({
    required this.id,
    required this.name,
    required this.pattern,
    required this.progress,
    required this.createdAt,
    required this.updatedAt,
    this.sourceImageName,
  });

  /// 当前支持的 schema 版本。
  static const int supportedSchemaVersion = 1;

  final String id;
  final String name;
  final BeadPattern pattern;
  final BeadingProgress progress;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 来源图片名（从相册/示例图导入时记录，便于回忆这是哪张图）。
  final String? sourceImageName;

  int get rows => pattern.rows;
  int get cols => pattern.cols;

  /// 已放格数（含"整色完成"隐含的）。
  int get placedCells => _stats.placedCells;

  /// 总格数。
  int get totalCells => _stats.totalCells;

  /// 总进度百分比（0..100）。
  int get percent => _stats.percent;

  /// 图纸用到的颜色数。
  int get usedColorCount => _stats.usedColorCount;

  /// 已完成的颜色数。
  int get completedColorCount => _stats.completedUsedColorCount;

  /// 是否已拼完。
  bool get isComplete => _stats.isComplete;

  GuideStats get _stats => computeGuideStats(
    pattern: pattern,
    progress: progress,
    activeColorIndex: null,
  );

  Project copyWith({
    String? name,
    BeadPattern? pattern,
    BeadingProgress? progress,
    DateTime? updatedAt,
    String? sourceImageName,
  }) => Project(
    id: id,
    name: name ?? this.name,
    pattern: pattern ?? this.pattern,
    progress: progress ?? this.progress,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    sourceImageName: sourceImageName ?? this.sourceImageName,
  );

  // ---------------------------------------------------------------- 序列化

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': supportedSchemaVersion,
    'id': id,
    'name': name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (sourceImageName != null) 'sourceImageName': sourceImageName,
    'paletteId': pattern.paletteId,
    'rows': pattern.rows,
    'cols': pattern.cols,
    'cells': encodeCellIndices(pattern),
    'placed': base64Encode(progress.toByteMap()),
    'completedColors': progress.completedColors.toList()..sort(),
  };

  /// 解析并**严格校验**。
  ///
  /// 校验的重点是"位图长度必须与 rows×cols 吻合"：长度不对说明文件被改坏了
  /// 或版本对不上，这时宁可报错让上层跳过这个项目，也不要加载出错位的进度。
  static Project fromJsonText(String source) {
    final Map<String, Object?> json = decodeJsonObject(source, path: 'project');
    final int version = requireInt(json, 'schemaVersion', 'project');
    if (version != supportedSchemaVersion) {
      throw ModelFormatException(
        'project.schemaVersion',
        '不支持的版本 $version（当前支持 $supportedSchemaVersion）',
      );
    }

    final int rows = requirePositiveInt(json, 'rows', 'project');
    final int cols = requirePositiveInt(json, 'cols', 'project');
    final String paletteId = requireString(json, 'paletteId', 'project');

    final Uint16List cells = decodeCellIndices(
      requireString(json, 'cells', 'project'),
      rows: rows,
      cols: cols,
    );
    final BeadPattern pattern = BeadPattern.filled(
      rows: rows,
      cols: cols,
      paletteId: paletteId,
    );
    int index = 0;
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        pattern.setColorIndexAt(row, col, cells[index++]);
      }
    }

    final Uint8List placed;
    try {
      placed = base64Decode(requireString(json, 'placed', 'project'));
    } on FormatException catch (error) {
      throw ModelFormatException(
        'project.placed',
        'base64 解码失败：${error.message}',
      );
    }

    final List<Object?> colors = requireList(
      json,
      'completedColors',
      'project',
    );
    final List<int> completedColors = <int>[
      for (final Object? value in colors)
        if (value is int && value >= 0)
          value
        else
          throw ModelFormatException(
            'project.completedColors',
            '必须是正整数数组，实际含 $value',
          ),
    ];

    final BeadingProgress progress;
    try {
      progress = BeadingProgress.fromByteMap(
        rows: rows,
        cols: cols,
        placed: placed,
        completedColors: completedColors,
      );
    } on ArgumentError catch (error) {
      throw ModelFormatException('project.placed', '${error.message}');
    }

    return Project(
      id: requireString(json, 'id', 'project'),
      name: requireString(json, 'name', 'project'),
      pattern: pattern,
      progress: progress,
      createdAt: _requireDate(json, 'createdAt'),
      updatedAt: _requireDate(json, 'updatedAt'),
      sourceImageName: optionalString(json, 'sourceImageName'),
    );
  }

  // --------------------------------------------------------------- 位图编码

  /// 把图纸的色号索引编码成 base64（**小端序**显式写出，不依赖平台字节序）。
  static String encodeCellIndices(BeadPattern pattern) {
    final Uint8List bytes = Uint8List(pattern.length * 2);
    int offset = 0;
    for (int row = 0; row < pattern.rows; row++) {
      for (int col = 0; col < pattern.cols; col++) {
        final int value = pattern.colorIndexAt(row, col);
        bytes[offset++] = value & 0xFF;
        bytes[offset++] = (value >> 8) & 0xFF;
      }
    }
    return base64Encode(bytes);
  }

  /// 解回色号索引（长度必须正好 rows × cols × 2 字节）。
  static Uint16List decodeCellIndices(
    String encoded, {
    required int rows,
    required int cols,
  }) {
    final Uint8List bytes;
    try {
      bytes = base64Decode(encoded);
    } on FormatException catch (error) {
      throw ModelFormatException(
        'project.cells',
        'base64 解码失败：${error.message}',
      );
    }
    final int expected = rows * cols * 2;
    if (bytes.length != expected) {
      throw ModelFormatException(
        'project.cells',
        '位图长度 ${bytes.length} 字节，与 $rows x $cols 应为的 $expected 字节不符',
      );
    }
    final Uint16List cells = Uint16List(rows * cols);
    for (int i = 0; i < cells.length; i++) {
      cells[i] = bytes[i * 2] | (bytes[i * 2 + 1] << 8);
    }
    return cells;
  }

  static DateTime _requireDate(Map<String, Object?> json, String key) {
    final String raw = requireString(json, key, 'project');
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw ModelFormatException('project.$key', '不是合法的时间：$raw');
    }
    return parsed;
  }

  @override
  String toString() =>
      'Project($id, "$name", ${rows}x$cols, $percent%, updated=$updatedAt)';
}
