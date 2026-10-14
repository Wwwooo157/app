import 'dart:ui' show Offset;

import 'package:bead_light_board/data/models/json_support.dart';

/// 屏幕网格与物理钉位的校准参数。
///
/// 设计原则：**默认就是严格物理 1:1**（[scaleFactor] = 1、[origin] 为原点）。
/// 使用者的微调是"叠加在物理真相之上的修正"，而不是重新定义比例；
/// 一旦 [scaleFactor] 偏离 1，界面必须明确标出「当前非严格 1:1」，
/// 不能让使用者以为屏幕还在按真实尺寸显示。
///
/// 本机平板已用实体尺子验证：默认参数下 10 格 = 50.0 mm，完全吻合。
final class Calibration {
  const Calibration({
    required this.pitchMm,
    required this.scaleFactor,
    required this.origin,
    required this.locked,
  });

  /// 当前支持的存储结构版本。
  static const int supportedSchemaVersion = 1;

  /// 判断 [scaleFactor] 是否等于 1 的容差。
  static const double scaleEpsilon = 1e-6;

  /// 允许的缩放范围：再大就不像"微调"了，更可能是数据坏了。
  static const double minScaleFactor = 0.5;
  static const double maxScaleFactor = 2.0;

  /// 标称豆距（毫米）。
  final double pitchMm;

  /// 相对物理 1:1 的缩放系数。1.0 = 严格 1:1。
  final double scaleFactor;

  /// 网格原点（格子 (0,0) 左上角）在画布上的位置，逻辑像素。
  final Offset origin;

  /// 是否已锁定（锁定后禁用手势，防误触）。
  final bool locked;

  /// 默认值：严格 1:1、原点、未锁定。
  factory Calibration.defaults({required double pitchMm}) => Calibration(
    pitchMm: pitchMm,
    scaleFactor: 1,
    origin: Offset.zero,
    locked: false,
  );

  /// 是否处于严格物理 1:1（没有手动缩放）。
  bool get isStrictlyOneToOne => (scaleFactor - 1).abs() < scaleEpsilon;

  /// 是否被改过（用于界面提示"当前有手动修正"）。
  bool get isAdjusted => !isStrictlyOneToOne || origin != Offset.zero;

  Calibration copyWith({
    double? pitchMm,
    double? scaleFactor,
    Offset? origin,
    bool? locked,
  }) => Calibration(
    pitchMm: pitchMm ?? this.pitchMm,
    scaleFactor: scaleFactor ?? this.scaleFactor,
    origin: origin ?? this.origin,
    locked: locked ?? this.locked,
  );

  /// 导出为 JSON。
  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': supportedSchemaVersion,
    'pitchMm': pitchMm,
    'scaleFactor': scaleFactor,
    'originDx': origin.dx,
    'originDy': origin.dy,
    'locked': locked,
  };

  /// 从 JSON 对象解析，严格校验。
  static Calibration fromJson(Map<String, Object?> json) {
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

    final double pitchMm = _requireFiniteDouble(json, 'pitchMm');
    if (pitchMm <= 0) {
      throw ModelFormatException('pitchMm', '必须大于 0，实际为 $pitchMm');
    }

    final double scaleFactor = _requireFiniteDouble(json, 'scaleFactor');
    if (scaleFactor < minScaleFactor || scaleFactor > maxScaleFactor) {
      throw ModelFormatException(
        'scaleFactor',
        '必须在 $minScaleFactor ~ $maxScaleFactor 之间，实际为 $scaleFactor',
      );
    }

    return Calibration(
      pitchMm: pitchMm,
      scaleFactor: scaleFactor,
      origin: Offset(
        _requireFiniteDouble(json, 'originDx'),
        _requireFiniteDouble(json, 'originDy'),
      ),
      locked: _requireBool(json, 'locked'),
    );
  }

  /// 从 JSON 文本解析。
  static Calibration fromJsonText(String source) =>
      Calibration.fromJson(decodeJsonObject(source, path: 'calibration'));

  @override
  String toString() =>
      'Calibration(pitch=${pitchMm}mm, scale=${scaleFactor.toStringAsFixed(4)}, '
      'origin=$origin, locked=$locked)';
}

double _requireFiniteDouble(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! num || !value.isFinite) {
    throw ModelFormatException(key, '必填，且必须是有限数字');
  }
  return value.toDouble();
}

bool _requireBool(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! bool) {
    throw ModelFormatException(key, '必填，且必须是布尔值');
  }
  return value;
}
