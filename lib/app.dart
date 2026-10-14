import 'package:bead_light_board/core/constants/app_strings.dart';
import 'package:bead_light_board/core/theme/app_theme.dart';
import 'package:bead_light_board/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';

/// 应用根组件。
class BeadLightBoardApp extends StatelessWidget {
  const BeadLightBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      // 本 App 只有深色主题：屏幕要垫在透明板下当灯板，暗底才不会反光刺眼。
      theme: AppTheme.dark(),
      home: const HomeScreen(),
    );
  }
}
