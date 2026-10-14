/// 全局文案。
///
/// 先集中放在这里，等真要做多语言（i18n）时再统一替换为 arb 方案。
abstract final class AppStrings {
  /// App 显示名，同时被 smoke test 断言，改动需同步测试。
  static const String appTitle = '透明板拼豆辅助';

  /// 首页副标题，说明本 App 的核心工作方式。
  static const String appTagline = '把透明拼豆板放在平板上，屏幕就是灯板';
}
