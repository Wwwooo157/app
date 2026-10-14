/// 每毫米对应多少逻辑像素。
///
/// 这是"屏幕当灯板"的物理基础：只有知道 1 毫米在屏幕上占多少逻辑像素，
/// 才能把 5mm 的钉位间距画成真实尺寸（真 1:1），让透明板的孔与屏幕格子对齐。
///
/// 数据来源：[fromDeviceDpi] 用 Android 原生侧上报的 xdpi/ydpi（真实物理 DPI）。
/// 注意 Flutter 的 `MediaQuery` **不提供** xdpi/ydpi，只有 devicePixelRatio，
/// 所以必须走平台通道，拿不到时上层要明确告知"当前不是 1:1"，不能蒙混。
library;

import 'dart:math' as math;

final class PegMetrics {
  const PegMetrics({
    required this.pxPerMmX,
    required this.pxPerMmY,
    required this.pitchMm,
  });

  /// 每英寸 = 25.4 毫米。
  static const double mmPerInch = 25.4;

  /// 水平方向：逻辑像素 / 毫米。
  final double pxPerMmX;

  /// 垂直方向：逻辑像素 / 毫米。
  ///
  /// 与 [pxPerMmX] 分开保存，是因为真实面板的 xdpi 与 ydpi 通常有零点几个百分点的差异
  /// （本机实测 276.462 vs 275.525）。分开算可以吃掉这点各向异性，
  /// 拼 52 格时能差出约 0.17mm。
  final double pxPerMmY;

  /// 豆子中心间距（毫米）。默认 5mm，是使用者确认过的值，S5 校准可微调。
  final double pitchMm;

  /// 由设备物理 DPI 构造。
  ///
  /// [devicePixelRatio] 用于把物理像素换算成 Flutter 的逻辑像素。
  factory PegMetrics.fromDeviceDpi({
    required double pitchMm,
    required double xdpi,
    required double ydpi,
    required double devicePixelRatio,
  }) {
    if (pitchMm <= 0) {
      throw ArgumentError.value(pitchMm, 'pitchMm', '必须大于 0');
    }
    if (xdpi <= 0 || ydpi <= 0) {
      throw ArgumentError('xdpi/ydpi 必须大于 0，实际为 $xdpi / $ydpi');
    }
    if (devicePixelRatio <= 0) {
      throw ArgumentError.value(devicePixelRatio, 'devicePixelRatio', '必须大于 0');
    }
    return PegMetrics(
      pxPerMmX: xdpi / mmPerInch / devicePixelRatio,
      pxPerMmY: ydpi / mmPerInch / devicePixelRatio,
      pitchMm: pitchMm,
    );
  }

  /// 水平方向：一个钉位的逻辑像素跨度。
  double get pxPerPegX => pxPerMmX * pitchMm;

  /// 垂直方向：一个钉位的逻辑像素跨度。
  double get pxPerPegY => pxPerMmY * pitchMm;

  /// 两个方向的平均钉位跨度（用于取整显示与"需要多大屏幕"的估算）。
  double get pxPerPeg => (pxPerPegX + pxPerPegY) / 2;

  /// 毫米 -> 逻辑像素（水平）。
  double mmToPxX(double mm) => mm * pxPerMmX;

  /// 毫米 -> 逻辑像素（垂直）。
  double mmToPxY(double mm) => mm * pxPerMmY;

  /// 逻辑像素 -> 毫米（水平）。
  double pxToMmX(double px) => px / pxPerMmX;

  /// 逻辑像素 -> 毫米（垂直）。
  double pxToMmY(double px) => px / pxPerMmY;

  /// 改变标称间距（保持物理 DPI 不变）。
  PegMetrics withPitch(double pitchMm) =>
      PegMetrics(pxPerMmX: pxPerMmX, pxPerMmY: pxPerMmY, pitchMm: pitchMm);

  /// 整体缩放（总览模式用它把整图缩到屏幕内；缩放后**不再**是 1:1）。
  PegMetrics scaled(double factor) {
    if (!factor.isFinite || factor <= 0) {
      throw ArgumentError.value(factor, 'factor', '必须是有限正数');
    }
    return PegMetrics(
      pxPerMmX: pxPerMmX * factor,
      pxPerMmY: pxPerMmY * factor,
      pitchMm: pitchMm,
    );
  }

  /// 在 [availableMm] 毫米的空间里最多能放下几个钉位（向下取整）。
  static int maxPegsAcross({
    required double availableMm,
    required double pitchMm,
  }) {
    if (pitchMm <= 0) {
      throw ArgumentError.value(pitchMm, 'pitchMm', '必须大于 0');
    }
    return math.max(0, (availableMm / pitchMm).floor());
  }

  @override
  String toString() =>
      'PegMetrics(pitch=${pitchMm}mm, pxPerPeg=${pxPerPeg.toStringAsFixed(2)}, '
      'pxPerMm=${pxPerMmX.toStringAsFixed(3)}/${pxPerMmY.toStringAsFixed(3)})';
}
