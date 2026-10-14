import 'package:bead_light_board/core/theme/app_theme.dart';
import 'package:bead_light_board/features/edit/domain/edit_tool.dart';
import 'package:bead_light_board/features/edit/domain/pattern_editor.dart';
import 'package:flutter/material.dart';

/// 编辑工具栏（编辑模式下顶替引导面板）。
///
/// 放在底部是因为透明板盖住屏幕时，下方的格子本来就在屏幕外 ——
/// 把常驻控件压在底部，对可拼区域的遮挡最小。
class EditToolbar extends StatelessWidget {
  const EditToolbar({
    super.key,
    required this.colorIndices,
    required this.colorOf,
    required this.codeOf,
    required this.activeColorIndex,
    required this.tool,
    required this.symmetry,
    required this.canUndo,
    required this.canRedo,
    required this.saveLabel,
    required this.onSelectColor,
    required this.onToolChanged,
    required this.onSymmetryChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onSave,
    required this.onResetPattern,
    required this.onDone,
  });

  /// 色卡里的**全部**色号（编辑时要能引入新颜色，不能只列已用到的）。
  final List<int> colorIndices;

  final Color Function(int colorIndex) colorOf;
  final String Function(int colorIndex) codeOf;
  final int? activeColorIndex;
  final EditTool tool;
  final SymmetryMode symmetry;
  final bool canUndo;
  final bool canRedo;

  /// 保存按钮的文案；null = 不显示保存按钮（已保存过的项目）。
  final String? saveLabel;

  final ValueChanged<int?> onSelectColor;
  final ValueChanged<EditTool> onToolChanged;
  final ValueChanged<SymmetryMode> onSymmetryChanged;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onSave;
  final VoidCallback onResetPattern;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final int? active = activeColorIndex;
    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                const Text(
                  '工具',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                for (final EditTool value in EditTool.values)
                  ChoiceChip(
                    label: Text(value.label),
                    selected: tool == value,
                    onSelected: (_) => onToolChanged(value),
                  ),
                const SizedBox(width: 8),
                const Text(
                  '对称',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                for (final SymmetryMode value in SymmetryMode.values)
                  ChoiceChip(
                    label: Text(value.label),
                    selected: symmetry == value,
                    // 填充与吸管没有"对称"可言，禁掉避免误导
                    onSelected: tool == EditTool.brush
                        ? (_) => onSymmetryChanged(value)
                        : null,
                  ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '撤销',
                  onPressed: canUndo ? onUndo : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: '重做',
                  onPressed: canRedo ? onRedo : null,
                  icon: const Icon(Icons.redo),
                ),
                TextButton.icon(
                  onPressed: onResetPattern,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('重来'),
                ),
                if (saveLabel != null)
                  FilledButton.tonalIcon(
                    onPressed: onSave,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(saveLabel!),
                  ),
                FilledButton.icon(
                  onPressed: onDone,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('完成'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 62,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: colorIndices.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (BuildContext context, int index) {
                  final int colorIndex = colorIndices[index];
                  final bool isActive = colorIndex == active;
                  return InkWell(
                    onTap: () => onSelectColor(colorIndex),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 74,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive
                              ? AppColors.accent
                              : AppColors.surfaceVariant,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: colorOf(colorIndex),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            codeOf(colorIndex),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
