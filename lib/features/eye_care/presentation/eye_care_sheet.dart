import 'package:bead_light_board/features/eye_care/domain/eye_care_settings.dart';
import 'package:flutter/material.dart';

/// 护眼设置面板（底部弹出）。
///
/// 做成弹出面板而不是常驻控件：透明板会盖住整块屏幕，
/// 这些设置只在"抬起板子"时才需要动，不该长期占着网格区域。
class EyeCareSheet extends StatefulWidget {
  const EyeCareSheet({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  final EyeCareSettings initial;

  /// 任何改动都会即时回调，让使用者当场看到效果。
  final ValueChanged<EyeCareSettings> onChanged;

  @override
  State<EyeCareSheet> createState() => _EyeCareSheetState();
}

class _EyeCareSheetState extends State<EyeCareSheet> {
  late EyeCareSettings _settings = widget.initial;

  void _update(EyeCareSettings next) {
    setState(() => _settings = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text('护眼与显示', style: theme.textTheme.titleMedium),
                const Spacer(),
                Switch(
                  value: _settings.enabled,
                  onChanged: (bool value) =>
                      _update(_settings.copyWith(enabled: value)),
                ),
              ],
            ),
            Text(
              '软件调光 + 暖色调，减少透明板下的反光与刺眼；不影响图纸数据的准确性。',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text('亮度（越小反光越弱）：${(_settings.brightness * 100).round()}%'),
            Slider(
              value: _settings.brightness,
              min: 0.15,
              divisions: 17,
              label: '${(_settings.brightness * 100).round()}%',
              onChanged: _settings.enabled
                  ? (double value) =>
                        _update(_settings.copyWith(brightness: value))
                  : null,
            ),
            Text('暖色：${(_settings.warmth * 100).round()}%'),
            Slider(
              value: _settings.warmth,
              divisions: 10,
              label: '${(_settings.warmth * 100).round()}%',
              onChanged: _settings.enabled
                  ? (double value) => _update(_settings.copyWith(warmth: value))
                  : null,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                FilterChip(
                  label: const Text('低对比'),
                  selected: _settings.lowContrast,
                  onSelected: _settings.enabled
                      ? (bool value) =>
                            _update(_settings.copyWith(lowContrast: value))
                      : null,
                ),
                FilterChip(
                  label: const Text('屏幕常亮'),
                  selected: _settings.keepScreenOn,
                  onSelected: (bool value) =>
                      _update(_settings.copyWith(keepScreenOn: value)),
                ),
                FilterChip(
                  label: const Text('沉浸式全屏'),
                  selected: _settings.immersive,
                  onSelected: (bool value) =>
                      _update(_settings.copyWith(immersive: value)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
