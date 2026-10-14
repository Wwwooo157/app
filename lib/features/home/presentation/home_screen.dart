import 'package:bead_light_board/core/constants/app_strings.dart';
import 'package:bead_light_board/core/theme/app_theme.dart';
import 'package:bead_light_board/features/grid/presentation/grid_screen.dart';
import 'package:flutter/material.dart';

/// 首页（S0 占位）。
///
/// 当前只显示工程骨架状态与后续里程碑，用于验证：
/// 主题装配、横屏布局、以及"骨架能被启动"这条最小闭环。
/// 真正的功能入口会在 S1（图纸生成）之后逐步替换这里。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const List<({String phase, String title})> _milestones =
      <({String phase, String title})>[
        (phase: 'M2', title: '全屏网格 + 物理对齐（最小可用产品）'),
        (phase: 'M3', title: '单色高亮 / 分步引导 / 进度统计'),
        (phase: 'M4', title: '护眼模式 / 防误触 / 常亮'),
        (phase: 'M5', title: '项目保存与加载 / 透视补偿'),
        (phase: 'M6', title: '编辑器 / 导出 PNG·PDF'),
      ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.appTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      AppStrings.appTagline,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) => const GridScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.grid_on),
                      label: const Text('打开网格预览（S4 · 合成图纸）'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'S4 已就绪：1:1 物理网格、窗口平移、命中测试。'
                      '图纸暂时用夹具色卡的合成图案（非真实色号）。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '下一步 M1：导入图片 → 裁剪 → 像素化 → 色卡量化。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 3,
                child: Card(
                  color: AppColors.surface,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _milestones.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final ({String phase, String title}) item =
                          _milestones[index];
                      return ListTile(
                        dense: true,
                        leading: Text(
                          item.phase,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.accent,
                          ),
                        ),
                        title: Text(item.title),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
