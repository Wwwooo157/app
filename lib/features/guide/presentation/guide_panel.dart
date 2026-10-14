import 'package:bead_light_board/core/theme/app_theme.dart';
import 'package:bead_light_board/features/guide/domain/guide_stats.dart';
import 'package:flutter/material.dart';

/// 引导面板（S6）：进度、分步切色、标记完成、色号条。
///
/// 使用时机要注意：透明板会把屏幕**完全盖住**（52×52 板 260mm > 屏幕 235×148mm），
/// 所以面板上的操作只能发生在**抬起板子**的时刻 —— 换区、换色、标记完成时
/// 本来就要挪板子，正好吻合。
class GuidePanel extends StatelessWidget {
  const GuidePanel({
    super.key,
    required this.stats,
    required this.usageOrder,
    required this.colorOf,
    required this.codeOf,
    required this.remainingOf,
    required this.completedColors,
    required this.hideOtherColors,
    required this.blinkEnabled,
    required this.perCellMarking,
    required this.onSelectColor,
    required this.onStepColor,
    required this.onToggleCompleted,
    required this.onHideOthersChanged,
    required this.onBlinkChanged,
    required this.onPerCellMarkingChanged,
    required this.onResetProgress,
  });

  final GuideStats stats;

  /// 色号索引顺序（按用量降序），分步引导就按这个顺序走。
  final List<int> usageOrder;

  final Color Function(int colorIndex) colorOf;
  final String Function(int colorIndex) codeOf;

  /// 某色还剩多少颗。
  final int Function(int colorIndex) remainingOf;

  final Set<int> completedColors;
  final bool hideOtherColors;
  final bool blinkEnabled;
  final bool perCellMarking;

  /// 点色号：选中；点已选中的色号则取消选中（null 表示显示全部颜色）。
  final ValueChanged<int?> onSelectColor;

  /// +1 下一色 / -1 上一色。
  final ValueChanged<int> onStepColor;

  final VoidCallback onToggleCompleted;
  final ValueChanged<bool> onHideOthersChanged;
  final ValueChanged<bool> onBlinkChanged;
  final ValueChanged<bool> onPerCellMarkingChanged;
  final VoidCallback onResetProgress;

  @override
  Widget build(BuildContext context) {
    final int? active = stats.activeColorIndex;
    final bool activeDone = active != null && completedColors.contains(active);

    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: LinearProgressIndicator(
                    value: stats.fraction,
                    minHeight: 10,
                    backgroundColor: AppColors.surfaceVariant,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '总进度 ${stats.percent}%'
                  '（${stats.placedCells}/${stats.totalCells} 颗 · '
                  '已完成 ${stats.completedUsedColorCount}/${stats.usedColorCount} 色）',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  active == null
                      ? '未选色：正常显示全部颜色'
                      : '当前色 ${codeOf(active)}　'
                            '剩 ${stats.activeColorRemaining} 颗'
                            '（共 ${stats.activeColorTotal} 颗）',
                  style: TextStyle(
                    color: active == null
                        ? AppColors.textSecondary
                        : AppColors.accent,
                    fontSize: 12,
                  ),
                ),
                OutlinedButton(
                  onPressed: usageOrder.isEmpty ? null : () => onStepColor(-1),
                  child: const Text('上一色'),
                ),
                OutlinedButton(
                  onPressed: usageOrder.isEmpty ? null : () => onStepColor(1),
                  child: const Text('下一色'),
                ),
                FilledButton(
                  onPressed: active == null ? null : onToggleCompleted,
                  child: Text(activeDone ? '取消完成' : '标记当前色完成'),
                ),
                FilterChip(
                  label: const Text('隐藏其他色'),
                  selected: hideOtherColors,
                  onSelected: onHideOthersChanged,
                ),
                FilterChip(
                  label: const Text('闪烁'),
                  selected: blinkEnabled,
                  onSelected: onBlinkChanged,
                ),
                FilterChip(
                  label: const Text('逐格标记'),
                  selected: perCellMarking,
                  onSelected: onPerCellMarkingChanged,
                ),
                OutlinedButton(
                  onPressed: onResetProgress,
                  child: const Text('重置进度'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 78,
              child: usageOrder.isEmpty
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '色卡为空，无法生成引导（请先填写真实色号）',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: usageOrder.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          const SizedBox(width: 6),
                      itemBuilder: (BuildContext context, int index) {
                        final int colorIndex = usageOrder[index];
                        return _ColorChip(
                          colorIndex: colorIndex,
                          color: colorOf(colorIndex),
                          code: codeOf(colorIndex),
                          remaining: remainingOf(colorIndex),
                          isActive: colorIndex == active,
                          isDone: completedColors.contains(colorIndex),
                          onTap: () => onSelectColor(
                            colorIndex == active ? null : colorIndex,
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

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.colorIndex,
    required this.color,
    required this.code,
    required this.remaining,
    required this.isActive,
    required this.isDone,
    required this.onTap,
  });

  final int colorIndex;
  final Color color;
  final String code;
  final int remaining;
  final bool isActive;
  final bool isDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 88,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.accent : AppColors.surfaceVariant,
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
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isDone ? '$code ✓' : code,
              style: TextStyle(
                fontSize: 10,
                color: isDone ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
            Text(
              '剩 $remaining',
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
