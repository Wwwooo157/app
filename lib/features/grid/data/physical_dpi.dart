import 'dart:async';

import 'package:flutter/services.dart';

/// 屏幕的真实物理 DPI。
///
/// Flutter 的 `MediaQuery` 只给 `devicePixelRatio`，**不给** xdpi/ydpi，
/// 而 1:1 物理对齐必须要后者，所以这里走平台通道向 Android 原生要。
final class PhysicalDpi {
  const PhysicalDpi({required this.xdpi, required this.ydpi});

  final double xdpi;
  final double ydpi;

  @override
  String toString() => 'PhysicalDpi(x=$xdpi, y=$ydpi)';
}

/// 平台通道名（Android 侧实现见 `MainActivity.kt`）。
const String physicalDpiChannelName = 'bead_light_board/display';

/// 取物理 DPI；**拿不到就返回 null**，不编造默认值。
///
/// 返回 null 时上层必须明确显示"当前不是 1:1"，而不是拿 160dpi 之类的
/// 假值算出一个看着像真的、实际上错位的网格。
Future<PhysicalDpi?> loadPhysicalDpiFromPlatform({
  MethodChannel channel = const MethodChannel(physicalDpiChannelName),
  Duration timeout = const Duration(seconds: 3),
}) async {
  final Map<Object?, Object?>? result;
  try {
    // 超时兜底：平台通道没有对应实现时，Flutter 并不保证抛
    // MissingPluginException —— 实测在 widget test 里会**永远不回应**。
    // 宁可超时后当作"拿不到"，也不能让界面无限等在加载态。
    result = await channel
        .invokeMapMethod<Object?, Object?>('getPhysicalDpi')
        .timeout(timeout);
  } on MissingPluginException {
    // 桌面/Web 等没有该实现，属预期内。
    return null;
  } on PlatformException {
    return null;
  } on TimeoutException {
    return null;
  }
  if (result == null) {
    return null;
  }
  final Object? x = result['xdpi'];
  final Object? y = result['ydpi'];
  if (x is! num || y is! num || x <= 0 || y <= 0) {
    return null;
  }
  return PhysicalDpi(xdpi: x.toDouble(), ydpi: y.toDouble());
}
