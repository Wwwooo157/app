import 'package:bead_light_board/features/projects/domain/relative_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime(2026, 2, 14, 12);

  test('一分钟内显示"刚刚"', () {
    expect(formatRelativeTime(now, now), '刚刚');
    expect(
      formatRelativeTime(now.subtract(const Duration(seconds: 59)), now),
      '刚刚',
    );
  });

  test('分钟 / 小时 / 天', () {
    expect(
      formatRelativeTime(now.subtract(const Duration(minutes: 1)), now),
      '1 分钟前',
    );
    expect(
      formatRelativeTime(now.subtract(const Duration(minutes: 59)), now),
      '59 分钟前',
    );
    expect(
      formatRelativeTime(now.subtract(const Duration(hours: 3)), now),
      '3 小时前',
    );
    expect(
      formatRelativeTime(now.subtract(const Duration(days: 2)), now),
      '2 天前',
    );
    expect(
      formatRelativeTime(now.subtract(const Duration(days: 29)), now),
      '29 天前',
    );
  });

  test('超过 30 天显示日期；跨年时带上年份', () {
    expect(
      formatRelativeTime(now.subtract(const Duration(days: 40)), now),
      '1 月 5 日',
    );
    expect(formatRelativeTime(DateTime(2025, 6), now), '2025 年 6 月 1 日');
  });

  test('未来时间不显示成负数（设备时钟被改过也要能看）', () {
    expect(formatRelativeTime(now.add(const Duration(hours: 5)), now), '刚刚');
  });
}
