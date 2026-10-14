import 'dart:math' as math;

/// CIE Lab 颜色（D65 白点）。
///
/// 为什么量化要用 Lab 而不是直接比 RGB：RGB 的距离与人眼感受不成比例，
/// 深色区与饱和区尤其明显。拼豆要"看起来最像"，用 Lab（CIE76 欧氏距离）
/// 已经比 RGB 靠谱得多，且计算量小、可完全单测。
final class LabColor {
  const LabColor(this.l, this.a, this.b);

  /// 亮度 0..100。
  final double l;

  /// 绿-红轴。
  final double a;

  /// 蓝-黄轴。
  final double b;

  /// CIE76 色差（在 Lab 里的欧氏距离）。
  double distanceTo(LabColor other) {
    final double dl = l - other.l;
    final double da = a - other.a;
    final double db = b - other.b;
    return math.sqrt(dl * dl + da * da + db * db);
  }

  @override
  String toString() =>
      'Lab(${l.toStringAsFixed(2)}, ${a.toStringAsFixed(2)}, ${b.toStringAsFixed(2)})';
}

/// D65 白点的三刺激值。
const double _whiteX = 0.95047;
const double _whiteY = 1.00000;
const double _whiteZ = 1.08883;

/// sRGB 分量（0..255）→ 线性光。
double _srgbToLinear(int channel) {
  final double v = channel / 255.0;
  return v <= 0.04045
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double _labF(double t) =>
    t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : (7.787 * t + 16.0 / 116.0);

/// sRGB（0..255）→ CIE Lab（D65）。
LabColor srgbToLab(int r, int g, int b) {
  final double linearR = _srgbToLinear(r);
  final double linearG = _srgbToLinear(g);
  final double linearB = _srgbToLinear(b);

  final double x =
      (linearR * 0.4124564 + linearG * 0.3575761 + linearB * 0.1804375) /
      _whiteX;
  final double y =
      (linearR * 0.2126729 + linearG * 0.7151522 + linearB * 0.0721750) /
      _whiteY;
  final double z =
      (linearR * 0.0193339 + linearG * 0.1191920 + linearB * 0.9503041) /
      _whiteZ;

  final double fx = _labF(x);
  final double fy = _labF(y);
  final double fz = _labF(z);

  return LabColor(116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
}

/// 0xAARRGGBB → Lab（忽略 alpha）。
LabColor argbToLab(int argb) =>
    srgbToLab((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);
