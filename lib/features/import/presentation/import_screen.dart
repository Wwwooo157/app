import 'dart:typed_data';

import 'package:bead_light_board/core/constants/app_assets.dart';
import 'package:bead_light_board/core/theme/app_theme.dart';
import 'package:bead_light_board/data/models/bead_color.dart';
import 'package:bead_light_board/data/models/palette.dart';
import 'package:bead_light_board/data/repositories/palette_repository.dart';
import 'package:bead_light_board/features/import/data/image_picker_service.dart';
import 'package:bead_light_board/features/import/domain/crop_geometry.dart';
import 'package:bead_light_board/features/import/domain/image_to_pattern.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;

/// 在后台 isolate 里跑导入：大图解码 + 量化不应该卡住界面。
Future<ImportOutcome> runImportInIsolate(ImportRequest request) =>
    compute(importImageToPattern, request);

/// 导入执行器（测试里注入同步实现，避免真实 isolate 与 fake async 打架）。
typedef ImportRunner = Future<ImportOutcome> Function(ImportRequest request);

/// 取景框的 key（测试里靠它做拖拽）。
const Key cropFrameKey = ValueKey<String>('crop-frame');

/// 内置示例图（不碰相册也能试跑整条链路）。
const String kSampleImageAsset = 'assets/samples/sample_heart.png';

/// 默认的示例图加载器。
Future<Uint8List> defaultSampleLoader() async {
  final ByteData data = await rootBundle.load(kSampleImageAsset);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// 导入图片 → 生成拼豆图纸。
///
/// 用手势自绘裁剪（零依赖）：拖动平移、双指缩放，取景框比例 = 目标格子的长宽比。
class ImportScreen extends StatefulWidget {
  const ImportScreen({
    super.key,
    this.picker,
    this.paletteLoader,
    this.runner = runImportInIsolate,
    this.paletteAssetPath = kFixturePaletteAsset,
    this.sampleLoader = defaultSampleLoader,
  });

  /// 选图服务；默认用 image_picker。
  final ImagePickerService? picker;

  /// 色卡加载器；默认从 assets 读。
  final Future<Palette> Function(String assetPath)? paletteLoader;

  /// 导入执行器。
  final ImportRunner runner;

  final String paletteAssetPath;

  /// 示例图加载器。
  final Future<Uint8List> Function() sampleLoader;

  @override
  State<ImportScreen> createState() => ImportScreenState();
}

/// 公开给测试使用。
class ImportScreenState extends State<ImportScreen> {
  /// 目标网格预设（与网格页保持一致）。
  static const List<({String label, int rows, int cols})> targetPresets =
      <({String label, int rows, int cols})>[
        (label: '29 × 29', rows: 29, cols: 29),
        (label: '52 × 52', rows: 52, cols: 52),
        (label: '30 × 20', rows: 20, cols: 30),
      ];

  /// 默认用 52×52（使用者确认过的主力板）。
  static const int defaultPresetIndex = 1;

  int _presetIndex = defaultPresetIndex;

  late final ImagePickerService _picker;
  Future<Palette> Function(String assetPath) _paletteLoader = (
    String assetPath,
  ) => PaletteRepository().loadPalette(assetPath);

  Palette? _palette;
  PickedImage? _picked;
  String? _error;
  bool _picking = false;
  bool _busy = false;

  /// 裁剪状态（相对 cover 居中位置的缩放与位移）。
  double _scale = 1;
  Offset _offset = Offset.zero;
  double _lastGestureScale = 1;

  /// 取景框实际尺寸（LayoutBuilder 里更新，供手势换算）。
  Size _frameSize = Size.zero;

  /// 原图像素尺寸（只读文件头，不解码整张图）。
  int _imageWidth = 0;
  int _imageHeight = 0;

  @override
  void initState() {
    super.initState();
    _picker = widget.picker ?? PlatformImagePickerService();
    _paletteLoader = widget.paletteLoader ?? _paletteLoader;
    _loadPalette();
  }

  Future<void> _loadPalette() async {
    try {
      final Palette palette = await _paletteLoader(widget.paletteAssetPath);
      if (!mounted) {
        return;
      }
      setState(() => _palette = palette);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '色卡读取失败：$error');
    }
  }

  ({String label, int rows, int cols}) get _preset =>
      targetPresets[_presetIndex];

  /// 当前裁剪几何（读的时候一律夹取，保证图片始终盖满取景框）。
  CropGeometry get cropGeometry => CropGeometry(
    frameSize: _frameSize,
    imageWidth: _imageWidth,
    imageHeight: _imageHeight,
    scale: _scale,
    offset: _offset,
  ).clamped();

  /// 供测试断言。
  PickedImage? get pickedImage => _picked;
  bool get isBusy => _busy;
  String? get errorMessage => _error;

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final PickedImage? picked = await _picker.pickImage();
      if (!mounted) {
        return;
      }
      if (picked == null) {
        setState(() => _picking = false);
        return;
      }
      _acceptImage(picked);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '打开相册失败：$error';
        _picking = false;
      });
    }
  }

  /// 用内置示例图试跑（不碰相册）。
  Future<void> _useSample() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final Uint8List bytes = await widget.sampleLoader();
      if (!mounted) {
        return;
      }
      _acceptImage(PickedImage(bytes: bytes, name: '示例图'));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '示例图读取失败：$error';
        _picking = false;
      });
    }
  }

  /// 接受一张图并进入裁剪页（相册与示例图共用同一条路径）。
  void _acceptImage(PickedImage picked) {
    final ({int width, int height})? size = readImageSize(picked.bytes);
    if (size == null) {
      setState(() {
        _error = '读不出这张图的尺寸，可能是格式不支持。';
        _picking = false;
      });
      return;
    }
    setState(() {
      _picked = picked;
      _imageWidth = size.width;
      _imageHeight = size.height;
      _scale = 1;
      _offset = Offset.zero;
      _picking = false;
    });
  }

  void _onScaleStart(ScaleStartDetails details) => _lastGestureScale = 1;

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final double factor = _lastGestureScale <= 0
        ? 1
        : details.scale / _lastGestureScale;
    _lastGestureScale = details.scale;

    final CropGeometry next = cropGeometry
        .zoomed(factor, details.localFocalPoint)
        .panned(details.focalPointDelta);

    setState(() {
      _scale = next.scale;
      _offset = next.offset;
    });
  }

  Future<void> _generate() async {
    final PickedImage? picked = _picked;
    final Palette? palette = _palette;
    if (picked == null || palette == null) {
      return;
    }
    final ({String label, int rows, int cols}) preset = _preset;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final ImportOutcome outcome = await widget.runner(
        ImportRequest(
          sourceBytes: picked.bytes,
          paletteArgb: <int>[
            for (final BeadColor color in palette.colors) color.argb,
          ],
          paletteId: palette.id,
          rows: preset.rows,
          cols: preset.cols,
          cropRegion: cropGeometry.normalizedCropRegion,
          sourceImageName: picked.name,
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(outcome);
    } on ImportException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = '生成失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('导入图片生成图纸'),
      ),
      body: _picked == null ? _buildPickerPage() : _buildCropperPage(),
    );
  }

  // ------------------------------------------------------------ 选择图片页

  Widget _buildPickerPage() {
    final Palette? palette = _palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.add_photo_alternate_outlined,
              size: 72,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              '选一张图，裁好范围，就能变成拼豆图纸',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              '每格会取选区里的平均色，再匹配到色卡上最接近的色号。',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (palette != null)
              Text(
                '色卡：${palette.name}（${palette.colors.length} 色'
                '${palette.id == 'test_fixture' ? ' · 非真实色号，仅供跑通流程' : ''}）',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              _buildError(),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _picking || palette == null ? null : _pick,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(_picking ? '正在打开相册…' : '选择图片'),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: _picking || palette == null ? null : _useSample,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('用示例图试试'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 裁剪页

  Widget _buildCropperPage() {
    final ({String label, int rows, int cols}) preset = _preset;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: <Widget>[
              const Text(
                '目标网格',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 12),
              for (int i = 0; i < targetPresets.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(targetPresets[i].label),
                    selected: i == _presetIndex,
                    onSelected: (bool value) {
                      if (value) {
                        setState(() => _presetIndex = i);
                      }
                    },
                  ),
                ),
              const Spacer(),
              const Text(
                '拖动平移 · 双指缩放',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AspectRatio(
                aspectRatio: preset.cols / preset.rows,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    _frameSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return _buildCropFrame();
                  },
                ),
              ),
            ),
          ),
        ),
        _buildFooter(preset),
      ],
    );
  }

  Widget _buildCropFrame() {
    final CropGeometry geometry = cropGeometry;
    final Size shown = geometry.displaySize;
    final Offset origin = geometry.topLeft;
    final PickedImage picked = _picked!;

    return GestureDetector(
      key: cropFrameKey,
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.accent, width: 2),
        ),
        child: ClipRect(
          child: Stack(
            children: <Widget>[
              Positioned(
                left: origin.dx,
                top: origin.dy,
                width: shown.width,
                height: shown.height,
                child: Image.memory(
                  picked.bytes,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(({String label, int rows, int cols}) preset) {
    final Rect rect = cropGeometry.sourcePixelRect;
    final double perCell =
        (rect.width * rect.height) / (preset.rows * preset.cols);
    final bool lowResolution = perCell < 4;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '选区 ${rect.width.round()} × ${rect.height.round()} 像素'
            ' → ${preset.cols} × ${preset.rows} 格',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            lowResolution
                ? '每格只有 ${perCell.toStringAsFixed(1)} 个像素：会偏糊，'
                      '建议把选区缩小（放大图片）或换张更清晰的图。'
                : '每格约 ${perCell.round()} 个像素，足够清晰。',
            style: TextStyle(
              color: lowResolution
                  ? AppColors.warning
                  : AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            _buildError(),
          ],
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _busy || _picking ? null : _pick,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('换一张'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _busy || _picking ? null : _generate,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.grid_on, size: 18),
                label: Text(_busy ? '正在生成…' : '生成图纸'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const Icon(Icons.error_outline, color: AppColors.warning, size: 18),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          _error!,
          style: const TextStyle(color: AppColors.warning, fontSize: 12),
        ),
      ),
    ],
  );
}
