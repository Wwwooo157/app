import 'dart:async';

import 'package:bead_light_board/features/grid/data/physical_dpi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(physicalDpiChannelName);
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('正常返回 xdpi/ydpi', () async {
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'getPhysicalDpi');
      return <String, Object?>{
        'xdpi': 276.462,
        'ydpi': 275.525,
        'densityDpi': 360,
      };
    });

    final PhysicalDpi? dpi = await loadPhysicalDpiFromPlatform();
    expect(dpi, isNotNull);
    expect(dpi!.xdpi, closeTo(276.462, 1e-9));
    expect(dpi.ydpi, closeTo(275.525, 1e-9));
  });

  test('平台没有实现时返回 null（绝不编造默认 DPI）', () async {
    final PhysicalDpi? dpi = await loadPhysicalDpiFromPlatform();
    expect(dpi, isNull);
  });

  test('字段缺失或类型不对时返回 null', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (MethodCall call) async => <String, Object?>{'xdpi': 'oops'},
    );
    expect(await loadPhysicalDpiFromPlatform(), isNull);

    messenger.setMockMethodCallHandler(
      channel,
      (MethodCall call) async => <String, Object?>{'xdpi': 0, 'ydpi': 275.5},
    );
    expect(await loadPhysicalDpiFromPlatform(), isNull);

    messenger.setMockMethodCallHandler(
      channel,
      (MethodCall call) async => <String, Object?>{'ydpi': -1, 'xdpi': 275.5},
    );
    expect(await loadPhysicalDpiFromPlatform(), isNull);
  });

  test('平台抛异常时返回 null 而不是崩掉', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (MethodCall call) async => throw PlatformException(code: 'boom'),
    );
    expect(await loadPhysicalDpiFromPlatform(), isNull);
  });

  test('平台永不回应时按超时处理，返回 null（不让界面无限等下去）', () async {
    // flutter_test 里没有 handler 的通道就是这种表现：永远不回应。
    messenger.setMockMethodCallHandler(
      channel,
      (MethodCall call) => Completer<Object?>().future,
    );
    final PhysicalDpi? dpi = await loadPhysicalDpiFromPlatform(
      timeout: const Duration(milliseconds: 30),
    );
    expect(dpi, isNull);
  });
}
