/// 把时间转成"人话"，用于项目列表。
///
/// 单独放一个纯函数：这类"看起来无所谓"的格式化最容易在边界上出错
/// （负数、未来时间、跨月），值得单测。
library;

/// 相对时间描述。
///
/// [now] 显式传入而不是内部取 `DateTime.now()`，这样测试完全确定。
String formatRelativeTime(DateTime time, DateTime now) {
  final Duration diff = now.difference(time);

  // 未来时间（设备时钟被改动过）不应该显示成"-3 分钟前"
  if (diff.isNegative) {
    return '刚刚';
  }
  if (diff.inMinutes < 1) {
    return '刚刚';
  }
  if (diff.inHours < 1) {
    return '${diff.inMinutes} 分钟前';
  }
  if (diff.inDays < 1) {
    return '${diff.inHours} 小时前';
  }
  if (diff.inDays < 30) {
    return '${diff.inDays} 天前';
  }

  final DateTime local = time.toLocal();
  final String monthDay = '${local.month} 月 ${local.day} 日';
  return local.year == now.toLocal().year
      ? monthDay
      : '${local.year} 年 $monthDay';
}
