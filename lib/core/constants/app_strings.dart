/// 全局文案。
///
/// 先集中放在这里，等真要做多语言（i18n）时再统一替换为 arb 方案。
abstract final class AppStrings {
  /// App 显示名（应用栏标题、桌面图标名）。
  ///
  /// 改这里只影响**显示名**；Dart 包名（`bead_light_board`）与 Android
  /// applicationId（`com.dsh.beadlightboard`）**刻意不动** ——
  /// 改 applicationId 会让系统认成另一个 App，已有的图纸与校准会一起"消失"。
  static const String appTitle = '豆';

  /// 首页副标题，说明本 App 的核心工作方式。
  static const String appTagline = '把透明拼豆板放在平板上，屏幕就是灯板';
}
