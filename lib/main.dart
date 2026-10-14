import 'package:bead_light_board/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 横屏优先：拼豆板铺满屏幕时，竖屏会让 29x29 网格被压扁，物理对齐失真。
  // 手机也一并锁横屏；若日后要让手机竖屏用，改这里即可。
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const BeadLightBoardApp());
}
