import 'dart:async';

import 'package:bead_light_board/features/grid/data/physical_dpi.dart';
import 'package:flutter/services.dart';

/// 屏幕常亮。
///
/// **为什么不用 wakelock 插件**：Android 侧只需要给 Window 加一个
/// `FLAG_KEEP_SCREEN_ON`，复用已有的 `bead_light_board/display` 平台通道即可
/// （少一个依赖，也避开 Windows 桌面上"带原生代码的插件需要软链接"的限制）。
///
/// 失败一律返回 false 而不是抛异常：常亮只是体验优化，
/// 不该因为它让拼豆流程崩掉。
abstract final class ScreenAwake {
  /// 设置常亮。返回是否设置成功。
  static Future<bool> setKeepScreenOn(
    bool keepOn, {
    MethodChannel channel = const MethodChannel(physicalDpiChannelName),
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final Object? result = await channel
          .invokeMethod<Object?>('setKeepScreenOn', <String, Object?>{
            'on': keepOn,
          })
          .timeout(timeout);
      return result is bool ? result : false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } on TimeoutException {
      return false;
    }
  }
}
