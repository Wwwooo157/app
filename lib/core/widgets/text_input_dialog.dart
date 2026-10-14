import 'package:bead_light_board/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// 单行文本输入对话框（重命名 / 保存图纸共用）。
///
/// 为什么单独做成 StatefulWidget：`TextEditingController` 的生命周期必须与
/// 对话框完全一致。若在调用方 `await showDialog()` 之后立刻 dispose，
/// **对话框退场动画还在用它**，会抛
/// "A TextEditingController was used after being disposed"
/// （widget test 一跑就现形）。
class TextInputDialog extends StatefulWidget {
  const TextInputDialog({
    super.key,
    required this.title,
    required this.initialValue,
    this.labelText = '名称',
    this.confirmLabel = '保存',
  });

  final String title;
  final String initialValue;
  final String labelText;
  final String confirmLabel;

  /// 弹出对话框并等结果；取消返回 null。
  ///
  /// 返回空字符串时表示"使用者清空了输入"，由调用方决定回退策略。
  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String initialValue,
    String labelText = '名称',
    String confirmLabel = '保存',
  }) => showDialog<String>(
    context: context,
    builder: (BuildContext context) => TextInputDialog(
      title: title,
      initialValue: initialValue,
      labelText: labelText,
      confirmLabel: confirmLabel,
    ),
  );

  @override
  State<TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<TextInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.labelText),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
