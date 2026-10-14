import 'dart:ui' show Color;

/// 护眼与显示设置。
///
/// 设计取舍：
/// - **软件调光**而不是改系统亮度：不改系统设置、不需要权限、跨设备一致；
///   而且"屏幕越暗 → 透明板上的反光越弱"，正是拼豆场景需要的。
/// - **暖色调**用颜色矩阵实现（抬红压蓝），不引入任何图片资源。
/// - 默认值就是"拼豆场景推荐值"，且**默认开启**（使用者明确要求）。
final class EyeCareSettings {
  const EyeCareSettings({
    this.enabled = true,
    this.brightness = 0.85,
    this.warmth = 0.25,
    this.lowContrast = false,
    this.keepScreenOn = true,
    this.immersive = true,
  });

  /// 护眼总开关，默认开启。
  final bool enabled;

  /// 软件调光：1.0 = 不调暗；越小越暗（反光越弱）。
  final double brightness;

  /// 暖色强度：0 = 原色，1 = 最暖。
  final double warmth;

  /// 低对比模式：网格线与高亮都用更柔和的色，进一步降低刺眼感。
  final bool lowContrast;

  /// 拼豆时保持屏幕常亮（否则拼一半就息屏了）。
  final bool keepScreenOn;

  /// 沉浸式全屏：隐藏状态栏/导航栏，让网格真正铺满。
  final bool immersive;

  /// 调光遮罩的 alpha 上限：再暗就看不清了。
  static const double maxDim = 0.85;

  /// 调光遮罩颜色。
  ///
  /// 用**深暖棕**而不是纯黑：纯黑会让屏幕发灰、对比过硬，
  /// 与项目"避免纯白纯黑"的整体基调一致。
  Color get dimOverlayColor {
    final double dim = (1 - brightness).clamp(0.0, maxDim);
    return Color.fromARGB((dim * 255).round(), 0x14, 0x10, 0x0B);
  }

  /// 是否需要叠加调光层。
  bool get hasDim => (1 - brightness) > 0.001;

  /// 暖色滤镜矩阵（4x5，供 `ColorFilter.matrix` 使用）。
  ///
  /// 抬红、微抬绿、压蓝，模拟"暖光"，不改变透明度。
  List<double> get warmthMatrix {
    final double w = warmth.clamp(0.0, 1.0);
    final double red = 1 + 0.18 * w;
    final double green = 1 + 0.02 * w;
    final double blue = 1 - 0.18 * w;
    return <double>[
      red, 0, 0, 0, 0, //
      0, green, 0, 0, 0, //
      0, 0, blue, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// 是否需要叠加暖色滤镜（暖度为 0 时不必多一层离屏合成）。
  bool get hasWarmth => warmth > 0.001;

  EyeCareSettings copyWith({
    bool? enabled,
    double? brightness,
    double? warmth,
    bool? lowContrast,
    bool? keepScreenOn,
    bool? immersive,
  }) => EyeCareSettings(
    enabled: enabled ?? this.enabled,
    brightness: (brightness ?? this.brightness).clamp(0.15, 1.0),
    warmth: (warmth ?? this.warmth).clamp(0.0, 1.0),
    lowContrast: lowContrast ?? this.lowContrast,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    immersive: immersive ?? this.immersive,
  );

  @override
  bool operator ==(Object other) =>
      other is EyeCareSettings &&
      other.enabled == enabled &&
      other.brightness == brightness &&
      other.warmth == warmth &&
      other.lowContrast == lowContrast &&
      other.keepScreenOn == keepScreenOn &&
      other.immersive == immersive;

  @override
  int get hashCode => Object.hash(
    enabled,
    brightness,
    warmth,
    lowContrast,
    keepScreenOn,
    immersive,
  );

  @override
  String toString() =>
      'EyeCareSettings(enabled=$enabled, 亮度=$brightness, 暖度=$warmth, '
      '低对比=$lowContrast, 常亮=$keepScreenOn, 沉浸=$immersive)';
}
