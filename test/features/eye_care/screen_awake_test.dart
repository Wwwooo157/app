import 'dart:async';

import 'package:bead_light_board/features/eye_care/data/screen_awake.dart';
import 'package:bead_light_board/features/grid/data/physical_dpi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(physicalDpiChannelName);
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('走的是 display 通道的 setKeepScreenOn，且参数正确', () async {
    MethodCall? captured;
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      captured = call;
      return true;
    });

    final bool ok = await ScreenAwake.setKeepScreenOn(true);

    expect(ok, isTrue);
    expect(captured, isNotNull);
    expect(captured!.method, 'setKeepScreenOn');
    expect(captured!.arguments, <String, Object?>{'on': true});
  });

  test('关闭常亮也能正确传参', () async {
    MethodCall? captured;
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      captured = call;
      return true;
    });

    await ScreenAwake.setKeepScreenOn(false);
    expect(captured!.arguments, <String, Object?>{'on': false});
  });

  test('平台返回非布尔值时按失败处理，不崩', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (MethodCall call) async => <String, Object?>{'unexpected': true},
    );
    expect(await ScreenAwake.setKeepScreenOn(true), isFalse);
  });

  test('平台抛异常时返回 false 而不是崩掉', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (MethodCall call) async => throw PlatformException(code: 'boom'),
    );
    expect(await ScreenAwake.setKeepScreenOn(true), isFalse);
  });

  test('平台永不回应时按超时处理，返回 false（不让界面卡住）', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (MethodCall call) => Completer<Object?>().future,
    );
    final bool ok = await ScreenAwake.setKeepScreenOn(
      true,
      timeout: const Duration(milliseconds: 30),
    );
    expect(ok, isFalse);
  });
}
