import 'package:bead_light_board/core/constants/app_strings.dart';
import 'package:bead_light_board/core/theme/app_theme.dart';
import 'package:bead_light_board/features/grid/presentation/grid_screen.dart';
import 'package:bead_light_board/features/import/domain/image_to_pattern.dart';
import 'package:bead_light_board/features/import/presentation/import_screen.dart';
import 'package:bead_light_board/features/projects/domain/project.dart';
import 'package:bead_light_board/features/projects/presentation/project_list_screen.dart';
import 'package:flutter/material.dart';

/// 首页：两个入口 —— 导入图片生成图纸（正路）、合成图案网格（开发/演示）。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const List<({String phase, String title, bool done})> _milestones =
      <({String phase, String title, bool done})>[
        (phase: 'M1', title: '导入图片 → 裁剪 → 像素化 → 色卡量化', done: true),
        (phase: 'M2', title: '全屏网格 + 物理对齐（最小可用产品）', done: true),
        (phase: 'M3', title: '单色高亮 / 分步引导 / 进度统计', done: true),
        (phase: 'M4', title: '护眼 / 沉浸式 / 屏幕常亮', done: true),
        (phase: 'M5', title: '项目保存与加载 / 透视补偿', done: false),
        (phase: 'M6', title: '编辑器 / 导出 PNG·PDF', done: false),
      ];

  /// 导入图片 → 生成图纸 → 直接进入网格页。
  Future<void> _importImage(BuildContext context) async {
    final ImportOutcome? outcome = await Navigator.of(context)
        .push<ImportOutcome>(
          MaterialPageRoute<ImportOutcome>(
            builder: (BuildContext context) => const ImportScreen(),
          ),
        );
    if (outcome == null || !context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => GridScreen(
          importedPattern: outcome.pattern,
          sourceImageName: outcome.sourceImageName,
        ),
      ),
    );
  }

  /// 我的图纸 → 打开选中的项目。
  Future<void> _openProjects(BuildContext context) async {
    final Project? picked = await Navigator.of(context).push<Project>(
      MaterialPageRoute<Project>(
        builder: (BuildContext context) => const ProjectListScreen(),
      ),
    );
    if (picked == null || !context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => GridScreen(project: picked),
      ),
    );
  }

  void _openSyntheticGrid(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const GridScreen(),
      ),
    );
  }

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
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => _importImage(context),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('导入图片生成图纸'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _openProjects(context),
                      icon: const Icon(Icons.folder_open_outlined),
                      label: const Text('我的图纸（保存与继续拼）'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _openSyntheticGrid(context),
                      icon: const Icon(Icons.grid_on),
                      label: const Text('打开网格（合成图案，用于校准）'),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '导入后先裁剪范围，再按选区平均色匹配到色卡，'
                      '然后进入 1:1 物理网格开始拼豆。',
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
                      final ({String phase, String title, bool done}) item =
                          _milestones[index];
                      return ListTile(
                        dense: true,
                        leading: Text(
                          item.phase,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: item.done
                                ? AppColors.accent
                                : AppColors.textSecondary,
                          ),
                        ),
                        title: Text(item.title),
                        trailing: item.done
                            ? const Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: AppColors.accent,
                              )
                            : null,
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
