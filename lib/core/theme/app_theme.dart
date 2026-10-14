import 'package:flutter/material.dart';

/// 全局配色。
///
/// 设计约束（来自项目需求，非审美选择）：
/// - 屏幕要垫在透明拼豆板下面当灯板用，**纯白/纯黑会反光刺眼**，因此底色用深暖灰、
///   文字用米白，全项目禁用 `Colors.white` / `Colors.black` 作为大面积色。
/// - 高亮色要柔和不刺眼（S7 护眼模式会在这条基线上继续做暖色调与亮度控制）。
abstract final class AppColors {
  /// 页面底色：深暖灰，替代纯黑。
  static const Color background = Color(0xFF1B1D1F);

  /// 卡片/面板底色。
  static const Color surface = Color(0xFF24272B);

  /// 次级面板、选中态底色。
  static const Color surfaceVariant = Color(0xFF2E3237);

  /// 主文字：米白，替代纯白。
  static const Color textPrimary = Color(0xFFE4E2DE);

  /// 次文字。
  static const Color textSecondary = Color(0xFF9BA1A8);

  /// 主强调色：柔和青绿。
  static const Color accent = Color(0xFF7FB3A3);

  /// 警示/提示色：柔和琥珀。
  static const Color warning = Color(0xFFD9A05B);

  /// 网格线默认色（S4 网格渲染用，避免纯白线条）。
  static const Color gridLine = Color(0xFF4A5057);
}

/// 主题装配。
abstract final class AppTheme {
  /// 深色主题（本 App 唯一主题：屏幕当灯板，暗底才不刺眼）。
  static ThemeData dark() {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
        ).copyWith(
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          primary: AppColors.accent,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textPrimary,
        iconColor: AppColors.textSecondary,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.surfaceVariant),
    );
  }
}
