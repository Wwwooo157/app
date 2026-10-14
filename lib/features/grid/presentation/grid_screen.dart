import 'dart:async';
import 'dart:math' as math;

import 'package:bead_light_board/core/constants/app_assets.dart';
import 'package:bead_light_board/core/theme/app_theme.dart';
import 'package:bead_light_board/core/widgets/text_input_dialog.dart';
import 'package:bead_light_board/data/models/bead_color.dart';
import 'package:bead_light_board/data/models/bead_pattern.dart';
import 'package:bead_light_board/data/models/palette.dart';
import 'package:bead_light_board/data/repositories/palette_repository.dart';
import 'package:bead_light_board/features/calibrate/data/calibration_storage.dart';
import 'package:bead_light_board/features/calibrate/domain/calibration.dart';
import 'package:bead_light_board/features/edit/domain/edit_history.dart';
import 'package:bead_light_board/features/edit/domain/edit_tool.dart';
import 'package:bead_light_board/features/edit/domain/pattern_editor.dart';
import 'package:bead_light_board/features/edit/presentation/edit_toolbar.dart';
import 'package:bead_light_board/features/eye_care/data/screen_awake.dart';
import 'package:bead_light_board/features/eye_care/domain/eye_care_palette.dart';
import 'package:bead_light_board/features/eye_care/domain/eye_care_settings.dart';
import 'package:bead_light_board/features/eye_care/presentation/eye_care_sheet.dart';
import 'package:bead_light_board/features/grid/data/physical_dpi.dart';
import 'package:bead_light_board/features/grid/domain/grid_style.dart';
import 'package:bead_light_board/features/grid/domain/grid_transform.dart';
import 'package:bead_light_board/features/grid/domain/peg_metrics.dart';
import 'package:bead_light_board/features/grid/domain/sample_patterns.dart';
import 'package:bead_light_board/features/grid/presentation/grid_canvas.dart';
import 'package:bead_light_board/features/grid/presentation/grid_painter.dart';
import 'package:bead_light_board/features/guide/domain/beading_progress.dart';
import 'package:bead_light_board/features/guide/domain/guide_stats.dart';
import 'package:bead_light_board/features/guide/domain/guide_style.dart';
import 'package:bead_light_board/features/guide/presentation/guide_panel.dart';
import 'package:bead_light_board/features/projects/data/project_repository.dart';
import 'package:bead_light_board/features/projects/domain/project.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 网格引导屏（S4 渲染 + S5 校准）。
///
/// 两种显示模式：
/// - **1:1 窗口**：按设备真实物理 DPI 把 5mm 钉位画成真实尺寸，可平移/捏合微调。
///   这是"屏幕当灯板"的主力模式，透明板的孔应该能与格子对上。
/// - **总览**：把整图缩进屏幕，只看配色与形状。**不是 1:1**，界面会明确标注。
///
/// 两条底线：
/// 1. 拿不到设备物理 DPI 时**强制**只能总览 —— 宁可说"做不到 1:1"，
///    也不能拿假数据算出一个看着对齐、实际错位的网格。
/// 2. 一旦手动缩放偏离 1，界面必须明确标出"当前非严格 1:1"。
class GridScreen extends StatefulWidget {
  const GridScreen({
    super.key,
    this.calibrationRepository,
    this.importedPattern,
    this.project,
    this.projectRepository,
    this.sourceImageName,
    this.autoSaveDebounce = const Duration(milliseconds: 800),
  });

  /// 校准参数的读写；测试注入内存实现，避免触碰 path_provider 平台通道。
  final CalibrationRepository? calibrationRepository;

  /// 从图片导入的图纸；null = 用合成图案（开发/演示用）。
  final BeadPattern? importedPattern;

  /// 已保存的项目（从「我的图纸」打开时传入）。
  ///
  /// 图纸与进度都取自它，进度变化会自动落盘；为空表示这份图纸还没保存过。
  final Project? project;

  /// 项目仓库；测试注入内存实现。
  final ProjectRepository? projectRepository;

  /// 来源图片名（保存为新项目时记录，便于日后认出是哪张图）。
  final String? sourceImageName;

  /// 进度自动保存的防抖时长（测试传 Duration.zero 以便立即触发）。
  final Duration autoSaveDebounce;

  @override
  State<GridScreen> createState() => GridScreenState();
}

/// 公开给测试使用（widget test 需要拿到内部状态做断言）。
class GridScreenState extends State<GridScreen>
    with SingleTickerProviderStateMixin {
  /// 夹具色卡（非真实色号）。导入与网格**必须**用同一张色卡，
  /// 否则量化出的索引与显示的颜色会对不上（见 app_assets.dart）。
  static const String fixtureAssetPath = kFixturePaletteAsset;

  /// 使用者确认过的豆子中心间距。
  static const double pitchMm = 5;

  static const List<({String label, int rows, int cols})> sizePresets =
      <({String label, int rows, int cols})>[
        (label: '29 × 29', rows: 29, cols: 29),
        (label: '52 × 52', rows: 52, cols: 52),
        (label: '30 × 20', rows: 20, cols: 30),
      ];

  int _presetIndex = 1;
  SyntheticKind _kind = SyntheticKind.diagonalCross;
  bool _oneToOne = true;
  bool _showControls = true;
  bool _showRuler = false;
  bool _showAnchors = false;
  int _rulerPegSpan = 10;
  double _lineWidth = 0.6;
  double _nudgeStepMm = 0.5;
  PegCellStyle _cellStyle = PegCellStyle.centeredDot;

  // ---------------------------------------------------------------- 引导 S6

  /// 当前引导的色号索引；null = 未选色（正常显示全部颜色）。
  int? _activeColorIndex;

  /// 非当前色：隐藏（true）还是压暗（false）。
  bool _hideOtherColors = false;

  /// 是否闪烁。闪烁更醒目，但有人觉得晃眼/费电，所以做成开关。
  bool _blinkEnabled = true;

  /// 逐格标记开关。默认**关闭**：板子盖住屏幕时无法触摸，实际拼豆靠
  /// "整色完成"标记；逐格标记只在抬起板子补记/纠错时用。
  bool _perCellMarking = false;

  /// 拼豆进度（与图纸尺寸绑定，换图纸时自动重建）。
  BeadingProgress? _progress;

  late final AnimationController _blinkController;

  // ---------------------------------------------------------------- 项目 M5

  late final ProjectRepository _projectRepository =
      widget.projectRepository ?? ProjectRepository();

  /// 当前项目；null = 这份图纸还没保存过。
  Project? _project;

  /// 自动保存防抖计时器。
  Timer? _autoSaveTimer;

  String? _saveError;

  // ---------------------------------------------------------------- 编辑 S10

  /// 是否处于编辑模式（此时单指绘制，双指仍可平移缩放）。
  bool _editing = false;

  EditTool _editTool = EditTool.brush;
  SymmetryMode _symmetry = SymmetryMode.none;

  final PatternEditHistory _history = PatternEditHistory();

  /// 当前这一笔的上一格（用于两次回调之间插值，快速划也不漏格）。
  GridCell? _lastPaintCell;

  /// 是否正在画一笔。
  bool _paintStroke = false;

  /// "重来"用的基准图（进入编辑模式时的样子）。
  BeadPattern? _editBaseline;

  /// 图纸/进度**内容版本号**。
  ///
  /// 图纸与进度都是就地修改的（同一个对象），`identical` 比不出变化 ——
  /// 没有这个计数器，逐格标记与编辑都不会触发重绘。
  int _revision = 0;

  /// 供测试断言。
  @visibleForTesting
  bool get isEditing => _editing;

  /// 供测试断言。
  @visibleForTesting
  PatternEditHistory get editHistory => _history;

  /// 供测试断言。
  @visibleForTesting
  Project? get currentProject => _project;

  /// 供测试断言。
  @visibleForTesting
  String? get saveError => _saveError;

  // ---------------------------------------------------------------- 护眼 S7

  /// 护眼与显示设置（默认开启软调光 + 暖色）。
  EyeCareSettings _eyeCare = const EyeCareSettings();

  /// 供测试断言当前护眼设置。
  @visibleForTesting
  EyeCareSettings get eyeCareSettings => _eyeCare;

  /// 校准参数（含窗口原点、缩放、锁定）。默认就是严格物理 1:1。
  Calibration _calibration = Calibration.defaults(pitchMm: pitchMm);

  /// 捏合开始时的缩放系数（ScaleUpdateDetails.scale 是相对手势起点的累计值）。
  double _scaleAtGestureStart = 1;

  /// 最近一次布局算出的物理度量，供微调按钮换算毫米->像素。
  PegMetrics? _lastPhysical;

  GridCell? _selected;

  PhysicalDpi? _dpi;
  bool _dpiChecked = false;
  List<Color> _paletteColors = const <Color>[];
  List<String> _paletteCodes = const <String>[];
  String? _paletteError;
  String? _calibrationError;
  BeadPattern? _pattern;

  late final CalibrationRepository _calibrationRepository;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    // 注意：这里**不**启动动画。只有"选了色 + 开了闪烁"时才跑 ——
    // AnimationController 若一直 repeat，`pumpAndSettle` 会永远等不到静止
    // （widget test 直接超时），实机上也是无谓耗电。
    _calibrationRepository =
        widget.calibrationRepository ?? CalibrationRepository();
    // 打开已保存的项目：直接用它的图纸与进度对象（进度是可变对象，
    // 所以就地修改即可，保存时整体写回）。
    _project = widget.project;
    if (_project != null) {
      _progress = _project!.progress;
    }
    unawaited(_applySystemUi());
    _applyKeepScreenOn();
    _loadDpi();
    _loadPalette();
    _loadCalibration();
  }

  @override
  void dispose() {
    // 退出前把没落盘的进度写掉（dispose 不能 await，所以不等结果）。
    _autoSaveTimer?.cancel();
    final Project? project = _project;
    if (project != null) {
      unawaited(_projectRepository.save(_projectRepository.touch(project)));
    }
    _blinkController.dispose();
    // 离开网格页：恢复系统 UI，并释放屏幕常亮（否则会一直亮着耗电）。
    unawaited(_restoreSystemUi());
    unawaited(ScreenAwake.setKeepScreenOn(false));
    super.dispose();
  }

  Future<void> _loadDpi() async {
    final PhysicalDpi? dpi = await loadPhysicalDpiFromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      _dpi = dpi;
      _dpiChecked = true;
      if (dpi == null) {
        _oneToOne = false;
      }
      _pattern = null;
    });
  }

  Future<void> _loadPalette() async {
    try {
      // 超时兜底：资源读取若卡住，界面必须说出来，而不是悄悄没有颜色。
      final Palette palette = await PaletteRepository()
          .loadPalette(fixtureAssetPath)
          .timeout(const Duration(seconds: 3));
      if (!mounted) {
        return;
      }
      setState(() {
        _paletteColors = palette.colors
            .map((BeadColor color) => Color(color.argb))
            .toList();
        _paletteCodes = palette.colors.map((BeadColor c) => c.code).toList();
        _pattern = null;
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      setState(() => _paletteError = '读取超时（3s）');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _paletteError = '$error');
    }
  }

  Future<void> _loadCalibration() async {
    final Calibration loaded = await _calibrationRepository.load(
      fallback: Calibration.defaults(pitchMm: pitchMm),
      onError: (Object error) {
        if (mounted) {
          setState(() => _calibrationError = '$error');
        }
      },
    );
    if (!mounted) {
      return;
    }
    setState(() => _calibration = loaded);
  }

  /// 保存校准参数。写失败只提示，不打断操作。
  void _persistCalibration() {
    final Future<bool> pending = _calibrationRepository.save(
      _calibration,
      onError: (Object error) {
        if (mounted) {
          setState(() => _calibrationError = '$error');
        }
      },
    );
    unawaited(pending);
  }

  ({String label, int rows, int cols}) get _preset => sizePresets[_presetIndex];

  /// 固定图纸：导入的，或已保存项目里的；null = 用合成图案。
  BeadPattern? get _fixedPattern => widget.importedPattern ?? _project?.pattern;

  /// 是否正在显示固定图纸（导入的或项目里的）。
  ///
  /// 此时尺寸/图案预设没有意义（图纸尺寸由图片与裁剪决定），需要禁用，
  /// 否则点了没反应会让人以为是坏了。
  bool get hasImportedPattern => _fixedPattern != null;

  BeadPattern get _currentPattern => _pattern ??=
      _fixedPattern ??
      buildSyntheticPattern(
        rows: _preset.rows,
        cols: _preset.cols,
        kind: _kind,
        paletteSize: math.max(1, _paletteColors.length),
      );

  // ------------------------------------------------------------ 引导逻辑 S6

  /// 确保进度对象与当前图纸尺寸一致（换图纸时自动重建）。
  BeadingProgress _ensureProgress() {
    final BeadPattern pattern = _currentPattern;
    final BeadingProgress? existing = _progress;
    if (existing != null &&
        existing.rows == pattern.rows &&
        existing.cols == pattern.cols) {
      return existing;
    }
    final BeadingProgress created = BeadingProgress(
      rows: pattern.rows,
      cols: pattern.cols,
    );
    _progress = created;
    return created;
  }

  /// 色号顺序：按用量降序（分步引导就走这个顺序）。
  List<int> get usageOrder =>
      _currentPattern.usageByColorIndex.keys.toList(growable: false);

  /// 色号文本；越界时给出可辨认的占位而不是崩溃。
  String colorCodeOf(int colorIndex) =>
      colorIndex >= 0 && colorIndex < _paletteCodes.length
      ? _paletteCodes[colorIndex]
      : '?$colorIndex';

  /// 色号颜色；越界时用告警色，避免"看着正常其实是错图"。
  Color colorOf(int colorIndex) =>
      colorIndex >= 0 && colorIndex < _paletteColors.length
      ? _paletteColors[colorIndex]
      : GridPainter.outOfPaletteColor;

  void _selectColor(int? colorIndex) {
    setState(() => _activeColorIndex = colorIndex);
    _syncBlinkAnimation();
  }

  /// 分步切色。未选色时 +1 选最常用的色、-1 选最少的色。
  void _stepColor(int delta) {
    final List<int> order = usageOrder;
    if (order.isEmpty) {
      return;
    }
    final int? current = _activeColorIndex;
    if (current == null) {
      setState(() => _activeColorIndex = delta >= 0 ? order.first : order.last);
      _syncBlinkAnimation();
      return;
    }
    final int index = order.indexOf(current);
    final int next = ((index < 0 ? 0 : index) + delta).clamp(
      0,
      order.length - 1,
    );
    setState(() => _activeColorIndex = order[next]);
    _syncBlinkAnimation();
  }

  /// 标记/取消当前色完成；标记完成后自动跳到下一个未完成的颜色。
  void _toggleActiveColorCompleted() {
    final int? active = _activeColorIndex;
    if (active == null) {
      return;
    }
    final BeadingProgress progress = _ensureProgress();
    final bool willComplete = !progress.isColorCompleted(active);

    setState(() {
      progress.setColorCompleted(active, completed: willComplete);
      _revision++;
      if (!willComplete) {
        return;
      }
      final List<int> order = usageOrder;
      final int index = order.indexOf(active);
      for (int step = 1; step <= order.length; step++) {
        final int candidate = order[(index + step) % order.length];
        if (!progress.isColorCompleted(candidate)) {
          _activeColorIndex = candidate;
          return;
        }
      }
      // 所有用到的颜色都完成了：保持当前色，进度自然到 100%。
    });
    _syncBlinkAnimation();
    _scheduleProjectSave();
  }

  void _toggleBlink() {
    setState(() => _blinkEnabled = !_blinkEnabled);
    _syncBlinkAnimation();
  }

  /// 只在"选了色 + 开了闪烁"时跑动画。
  ///
  /// 这一点很重要：AnimationController 若一直 repeat，`pumpAndSettle` 会
  /// 永远等不到静止（widget test 直接超时），实机上也无谓耗电。
  void _syncBlinkAnimation() {
    // 编辑模式下不高亮也不闪烁：编辑时要看到图纸的**真实颜色**。
    final bool shouldRun =
        !_editing && _blinkEnabled && _activeColorIndex != null;
    if (shouldRun) {
      if (!_blinkController.isAnimating) {
        _blinkController.repeat(reverse: true);
      }
    } else if (_blinkController.isAnimating) {
      _blinkController.stop();
    }
  }

  void _resetProgress() {
    setState(() {
      _ensureProgress().reset();
      _revision++;
    });
    _scheduleProjectSave();
  }

  // ------------------------------------------------------------ 编辑逻辑 S10

  void _enterEditMode() {
    setState(() {
      _editing = true;
      // 逐格标记与绘制互斥：同样是"点格子"，含义不能有两种。
      _perCellMarking = false;
      _selected = null;
      _history.clear();
      _paintStroke = false;
      _lastPaintCell = null;
      _editBaseline = _copyPattern(_currentPattern);
      // 没选色时默认用量最多的颜色，避免"点了没反应"。
      _activeColorIndex ??= usageOrder.isEmpty ? null : usageOrder.first;
    });
    // 进编辑模式要停掉闪烁，否则编辑时图案会被高亮盖住，测试里也会等不到静止。
    _syncBlinkAnimation();
  }

  void _exitEditMode() {
    _finishStroke();
    setState(() {
      _editing = false;
      _lastPaintCell = null;
      _editBaseline = null;
    });
    _syncBlinkAnimation();
    _scheduleProjectSave();
  }

  /// 落笔或移动：按当前工具修改图纸。
  void _handlePaintCell(GridCell cell) {
    final BeadPattern pattern = _currentPattern;

    if (_editTool == EditTool.picker) {
      final int? picked = PatternEditor.pick(pattern, cell.row, cell.col);
      if (picked != null) {
        setState(() => _activeColorIndex = picked);
      }
      return;
    }

    final int? colorIndex = _activeColorIndex;
    if (colorIndex == null) {
      return;
    }

    // 一笔 = 一步撤销
    if (!_paintStroke) {
      _history.beginBatch();
      _paintStroke = true;
      _lastPaintCell = null;
    }

    final List<CellChange> changes;
    if (_editTool == EditTool.fill) {
      changes = PatternEditor.floodFill(
        pattern,
        row: cell.row,
        col: cell.col,
        colorIndex: colorIndex,
      );
    } else {
      final GridCell? last = _lastPaintCell;
      changes = last == null
          ? PatternEditor.paint(
              pattern,
              row: cell.row,
              col: cell.col,
              colorIndex: colorIndex,
              symmetry: _symmetry,
            )
          : PatternEditor.paintLine(
              pattern,
              fromRow: last.row,
              fromCol: last.col,
              toRow: cell.row,
              toCol: cell.col,
              colorIndex: colorIndex,
              symmetry: _symmetry,
            );
    }

    _lastPaintCell = cell;
    _history.record(changes);
    if (changes.isNotEmpty) {
      setState(() => _revision++);
    }
  }

  /// 手势结束：给这一笔收尾（变成一步可撤销的操作）。
  void _finishStroke() {
    if (!_paintStroke) {
      return;
    }
    _paintStroke = false;
    _lastPaintCell = null;
    if (_history.endBatch()) {
      _scheduleProjectSave();
    }
  }

  void _undoEdit() {
    final List<CellChange>? changes = _history.undo();
    if (changes == null) {
      return;
    }
    PatternEditor.applyChanges(_currentPattern, changes, useBefore: true);
    setState(() => _revision++);
    _scheduleProjectSave();
  }

  void _redoEdit() {
    final List<CellChange>? changes = _history.redo();
    if (changes == null) {
      return;
    }
    PatternEditor.applyChanges(_currentPattern, changes, useBefore: false);
    setState(() => _revision++);
    _scheduleProjectSave();
  }

  /// 重来：把图纸恢复成进入编辑模式时的样子（这一步本身也可撤销）。
  void _resetPattern() {
    final BeadPattern? baseline = _editBaseline;
    if (baseline == null) {
      return;
    }
    final BeadPattern pattern = _currentPattern;
    final List<CellChange> changes = <CellChange>[];
    for (int row = 0; row < pattern.rows; row++) {
      for (int col = 0; col < pattern.cols; col++) {
        final int before = pattern.colorIndexAt(row, col);
        final int after = baseline.colorIndexAt(row, col);
        if (before != after) {
          changes.add(
            CellChange(row: row, col: col, before: before, after: after),
          );
        }
      }
    }
    if (changes.isEmpty) {
      return;
    }
    PatternEditor.applyChanges(pattern, changes, useBefore: false);
    _history.record(changes);
    setState(() => _revision++);
    _scheduleProjectSave();
  }

  static BeadPattern _copyPattern(BeadPattern source) {
    final BeadPattern copy = BeadPattern.filled(
      rows: source.rows,
      cols: source.cols,
      paletteId: source.paletteId,
    );
    for (int row = 0; row < source.rows; row++) {
      for (int col = 0; col < source.cols; col++) {
        copy.setColorIndexAt(row, col, source.colorIndexAt(row, col));
      }
    }
    return copy;
  }

  // ------------------------------------------------------------ 项目保存 M5

  /// 进度或图纸变了：若是已保存的项目，稍后自动落盘。
  ///
  /// 防抖是必要的：逐格标记与拖动绘制都会连点，每次都写文件既慢又费闪存。
  void _scheduleProjectSave() {
    if (_project == null) {
      return;
    }
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(widget.autoSaveDebounce, () {
      unawaited(_saveProject());
    });
  }

  /// 立刻保存当前项目。
  Future<void> _saveProject() async {
    final Project? project = _project;
    if (project == null) {
      return;
    }
    final Project touched = _projectRepository.touch(project);
    final bool ok = await _projectRepository.save(touched);
    if (!mounted) {
      return;
    }
    setState(() {
      _project = touched;
      _saveError = ok ? null : '进度保存失败（只影响这次写入）';
    });
  }

  /// 把当前图纸保存成一个新项目。
  Future<void> _saveAsNewProject() async {
    final String? name = await _askProjectName(_suggestedProjectName());
    if (name == null || !mounted) {
      return;
    }
    final Project created = _projectRepository.create(
      name: name,
      pattern: _currentPattern,
      progress: _ensureProgress(),
      sourceImageName: widget.sourceImageName,
    );
    final bool ok = await _projectRepository.save(created);
    if (!mounted) {
      return;
    }
    setState(() {
      _project = created;
      _saveError = ok ? null : '保存失败，请检查存储空间';
    });
  }

  /// 默认名称：优先用来源图片名（去掉扩展名）。
  String _suggestedProjectName() {
    final String? source = widget.sourceImageName;
    if (source != null && source.trim().isNotEmpty) {
      final int dot = source.lastIndexOf('.');
      return dot > 0 ? source.substring(0, dot) : source;
    }
    return '${_currentPattern.rows} × ${_currentPattern.cols} 图纸';
  }

  Future<String?> _askProjectName(String suggested) async {
    final String? name = await TextInputDialog.show(
      context,
      title: '保存图纸',
      initialValue: suggested,
      labelText: '图纸名称',
    );
    if (name == null) {
      return null;
    }
    final String trimmed = name.trim();
    return trimmed.isEmpty ? suggested : trimmed;
  }

  // ------------------------------------------------------------ 护眼逻辑 S7

  /// 应用沉浸式设置（进入网格页或改动设置时调用）。
  Future<void> _applySystemUi() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        _eyeCare.immersive
            ? SystemUiMode.immersiveSticky
            : SystemUiMode.edgeToEdge,
      );
    } catch (_) {
      // 桌面/测试环境可能不支持；这属于体验优化，不该让流程失败。
    }
  }

  /// 离开网格页时恢复系统 UI。
  Future<void> _restoreSystemUi() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {
      // 同上
    }
  }

  /// 应用屏幕常亮设置（失败静默：拼豆时若息屏，使用者会直接发现）。
  void _applyKeepScreenOn() {
    unawaited(ScreenAwake.setKeepScreenOn(_eyeCare.keepScreenOn));
  }

  /// 打开护眼设置面板。
  Future<void> _openEyeCareSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (BuildContext context) => EyeCareSheet(
        initial: _eyeCare,
        onChanged: (EyeCareSettings next) {
          setState(() => _eyeCare = next);
          _applyKeepScreenOn();
          unawaited(_applySystemUi());
        },
      ),
    );
  }

  /// 某色还剩多少颗（面板上显示用）。
  int _remainingOfColor(BeadingProgress progress, int colorIndex) {
    final BeadPattern pattern = _currentPattern;
    if (progress.isColorCompleted(colorIndex)) {
      return 0;
    }
    int total = 0;
    int placed = 0;
    for (int row = 0; row < pattern.rows; row++) {
      for (int col = 0; col < pattern.cols; col++) {
        if (pattern.colorIndexAt(row, col) != colorIndex) {
          continue;
        }
        total++;
        if (progress.isPlacedDirectly(row, col)) {
          placed++;
        }
      }
    }
    return total - placed;
  }

  /// 1:1 所需的物理度量；拿不到真实 DPI 时为 null。
  PegMetrics? physicalMetrics(double devicePixelRatio) {
    final PhysicalDpi? dpi = _dpi;
    if (dpi == null) {
      return null;
    }
    return PegMetrics.fromDeviceDpi(
      pitchMm: _calibration.pitchMm,
      xdpi: dpi.xdpi,
      ydpi: dpi.ydpi,
      devicePixelRatio: devicePixelRatio,
    );
  }

  /// 总览模式的兜底度量（绝对值无意义，只用于缩放）。
  static const PegMetrics _nominalMetrics = PegMetrics(
    pxPerMmX: 4,
    pxPerMmY: 4,
    pitchMm: pitchMm,
  );

  GridTransform buildTransform({
    required Size canvasSize,
    required PegMetrics? physical,
  }) {
    final ({String label, int rows, int cols}) preset = _preset;
    if (_oneToOne && physical != null) {
      // 校准叠加在物理真相之上：先按实际间距，再乘手动缩放。
      return GridTransform(
        origin: _calibration.origin,
        metrics: physical.scaled(_calibration.scaleFactor),
      );
    }
    return GridTransform.fit(
      canvasSize: canvasSize,
      rows: preset.rows,
      cols: preset.cols,
      metrics: physical ?? _nominalMetrics,
      padding: 12,
    );
  }

  /// 当前是否允许改校准（锁定时一律禁止）。
  bool get _canAdjust =>
      !_calibration.locked &&
      _oneToOne &&
      _dpi != null &&
      _lastPhysical != null;

  void _onScaleStart(ScaleStartDetails details) {
    _scaleAtGestureStart = _calibration.scaleFactor;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_canAdjust) {
      return;
    }
    final double target = (_scaleAtGestureStart * details.scale).clamp(
      Calibration.minScaleFactor,
      Calibration.maxScaleFactor,
    );
    final double ratio = target / _calibration.scaleFactor;
    // 以捏合中心为不动点缩放，再叠加平移量：手指按住的那个格子不会跑。
    final Offset focal = details.localFocalPoint;
    final Offset newOrigin =
        focal - (focal - _calibration.origin) * ratio + details.focalPointDelta;

    setState(() {
      _calibration = _calibration.copyWith(
        scaleFactor: target,
        origin: newOrigin,
      );
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _finishStroke();
    _persistCalibration();
  }

  /// 微调：按毫米或按格数平移网格。
  void _nudge({int dxSteps = 0, int dySteps = 0, bool byPeg = false}) {
    final PegMetrics? physical = _lastPhysical;
    if (!_canAdjust || physical == null) {
      return;
    }
    final double mm = byPeg ? _calibration.pitchMm : _nudgeStepMm;
    setState(() {
      _calibration = _calibration.copyWith(
        origin:
            _calibration.origin +
            Offset(
              physical.pxPerMmX * mm * dxSteps,
              physical.pxPerMmY * mm * dySteps,
            ),
      );
    });
    _persistCalibration();
  }

  void _toggleLock() {
    setState(() {
      _calibration = _calibration.copyWith(locked: !_calibration.locked);
    });
    _persistCalibration();
  }

  /// 归位：清掉平移与缩放，回到严格物理 1:1（保留锁定状态）。
  void _resetCalibration() {
    setState(() {
      _calibration = Calibration.defaults(pitchMm: _calibration.pitchMm)
          .copyWith(locked: _calibration.locked);
      _selected = null;
    });
    _persistCalibration();
  }

  void _handleCellTap(GridCell? cell) {
    if (cell == null) {
      setState(() => _selected = null);
      return;
    }
    if (_perCellMarking) {
      // 逐格标记：抬起板子补记/纠错时用。
      setState(() {
        _ensureProgress().togglePlaced(cell.row, cell.col);
        _revision++;
      });
      _scheduleProjectSave();
      return;
    }
    setState(() => _selected = cell);
  }

  void _changePreset(int index) => setState(() {
    _presetIndex = index;
    _selected = null;
    _pattern = null;
    // 图纸变了：进度与当前色都重置（尺寸不同时进度必须重建）。
    _progress = null;
    _activeColorIndex = null;
    _syncBlinkAnimation();
  });

  void _changeKind(SyntheticKind kind) => setState(() {
    _kind = kind;
    _selected = null;
    _pattern = null;
    _progress = null;
    _activeColorIndex = null;
    _syncBlinkAnimation();
  });

  void _setOneToOne(bool value) {
    if (value && _dpi == null) {
      return;
    }
    setState(() => _oneToOne = value);
  }

  String _selectedReadout(BeadPattern pattern) {
    final GridCell? cell = _selected;
    if (cell == null) {
      return '未选中（点一下网格试试命中测试）';
    }
    final int colorIndex = pattern.colorIndexAt(cell.row, cell.col);
    final String code = colorIndex < _paletteCodes.length
        ? _paletteCodes[colorIndex]
        : '越界($colorIndex)';
    return '已选中：第 ${cell.row} 行 · 第 ${cell.col} 列 · 色号 $code';
  }

  @override
  Widget build(BuildContext context) {
    final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final PegMetrics? physical = physicalMetrics(devicePixelRatio);
    _lastPhysical = physical;
    final BeadPattern pattern = _currentPattern;
    final bool lowContrast = _eyeCare.enabled && _eyeCare.lowContrast;
    final GridStyle style = EyeCarePalette.gridStyle(
      lowContrast: lowContrast,
      lineWidth: _lineWidth,
      cellStyle: _cellStyle,
    );
    final GuideStyle guideStyle = EyeCarePalette.guideStyle(
      lowContrast: lowContrast,
    );
    final bool locked = _calibration.locked;
    final BeadingProgress progress = _ensureProgress();
    final GuideStats guideStats = computeGuideStats(
      pattern: pattern,
      progress: progress,
      activeColorIndex: _activeColorIndex,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size canvasSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          final GridTransform transform = buildTransform(
            canvasSize: canvasSize,
            physical: physical,
          );
          final GridRange visible = transform.visibleRange(
            canvasSize,
            rows: pattern.rows,
            cols: pattern.cols,
          );
          final double topInset = MediaQuery.paddingOf(context).top;

          Widget content = Stack(
            children: <Widget>[
              Positioned.fill(
                child: GridCanvas(
                  pattern: pattern,
                  transform: transform,
                  style: style,
                  paletteColors: _paletteColors,
                  selectedCell: _selected,
                  showScaleRuler: _showRuler,
                  rulerPegSpan: _rulerPegSpan,
                  showAnchors: _showAnchors,
                  guideStyle: guideStyle,
                  // 编辑模式下不高亮、不压暗、不闪烁：要看图纸的真实颜色。
                  activeColorIndex: _editing ? null : _activeColorIndex,
                  hideOtherColors: _editing ? false : _hideOtherColors,
                  progress: progress,
                  revision: _revision,
                  // 只有"选了色 + 开了闪烁 + 非编辑"才把动画接上，避免无意义的重绘。
                  blink: !_editing && _activeColorIndex != null && _blinkEnabled
                      ? _blinkController
                      : null,
                  // 编辑模式下单指绘制，点击选格让位给绘制。
                  onCellTap: locked || _editing ? null : _handleCellTap,
                  onPaintCell: locked || !_editing ? null : _handlePaintCell,
                  // 锁定时传 null，彻底禁用手势（防误触）。
                  onScaleStart: locked ? null : _onScaleStart,
                  onScaleUpdate: locked ? null : _onScaleUpdate,
                  onScaleEnd: locked ? null : _onScaleEnd,
                ),
              ),
              if (_showControls)
                Positioned(
                  top: topInset + 8,
                  left: 8,
                  right: 8,
                  child: _buildControls(
                    pattern: pattern,
                    transform: transform,
                    visible: visible,
                    physical: physical,
                  ),
                )
              else
                Positioned(
                  top: topInset + 8,
                  left: 8,
                  child: IconButton.filledTonal(
                    tooltip: '显示控件',
                    onPressed: () => setState(() => _showControls = true),
                    icon: const Icon(Icons.tune),
                  ),
                ),
              if (_showControls)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: _editing
                      ? _buildEditToolbar()
                      : GuidePanel(
                          stats: guideStats,
                          usageOrder: usageOrder,
                          colorOf: colorOf,
                          codeOf: colorCodeOf,
                          remainingOf: (int colorIndex) =>
                              _remainingOfColor(progress, colorIndex),
                          completedColors: progress.completedColors,
                          hideOtherColors: _hideOtherColors,
                          blinkEnabled: _blinkEnabled,
                          perCellMarking: _perCellMarking,
                          onSelectColor: _selectColor,
                          onStepColor: _stepColor,
                          onToggleCompleted: _toggleActiveColorCompleted,
                          onHideOthersChanged: (bool value) =>
                              setState(() => _hideOtherColors = value),
                          onBlinkChanged: (_) => _toggleBlink(),
                          onPerCellMarkingChanged: (bool value) =>
                              setState(() => _perCellMarking = value),
                          onResetProgress: _resetProgress,
                        ),
                ),
              // 软件调光：整屏叠一层深暖棕，降低反光与刺眼。不拦截触摸。
              if (_eyeCare.enabled && _eyeCare.hasDim)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(color: _eyeCare.dimOverlayColor),
                  ),
                ),
            ],
          );
          if (_eyeCare.enabled && _eyeCare.hasWarmth) {
            content = ColorFiltered(
              colorFilter: ColorFilter.matrix(_eyeCare.warmthMatrix),
              child: content,
            );
          }
          return content;
        },
      ),
    );
  }

  /// 编辑模式下的底部工具栏（顶替引导面板）。
  Widget _buildEditToolbar() => EditToolbar(
    // 列出**整张色卡**：编辑时要能引入还没用过的新颜色。
    colorIndices: List<int>.generate(_paletteColors.length, (int i) => i),
    colorOf: colorOf,
    codeOf: colorCodeOf,
    activeColorIndex: _activeColorIndex,
    tool: _editTool,
    symmetry: _symmetry,
    canUndo: _history.canUndo,
    canRedo: _history.canRedo,
    saveLabel: _project == null ? '保存图纸' : null,
    onSelectColor: _selectColor,
    onToolChanged: (EditTool tool) => setState(() => _editTool = tool),
    onSymmetryChanged: (SymmetryMode value) =>
        setState(() => _symmetry = value),
    onUndo: _undoEdit,
    onRedo: _redoEdit,
    onSave: _saveAsNewProject,
    onResetPattern: _resetPattern,
    onDone: _exitEditMode,
  );

  Widget _buildControls({
    required BeadPattern pattern,
    required GridTransform transform,
    required GridRange visible,
    required PegMetrics? physical,
  }) {
    final bool isOneToOne = _oneToOne && physical != null;
    final bool locked = _calibration.locked;
    final String metricsLine = physical == null
        ? '物理 DPI：未取到 → 只能总览'
        : '物理 DPI：${_dpi!.xdpi.toStringAsFixed(2)} / '
              '${_dpi!.ydpi.toStringAsFixed(2)}　'
              '1 格 = ${physical.pxPerPegX.toStringAsFixed(2)} × '
              '${physical.pxPerPegY.toStringAsFixed(2)} 逻辑像素';
    final String calibrationLine = _calibration.isStrictlyOneToOne
        ? '校准：严格 1:1（未做手动缩放）　原点 '
              '(${transform.origin.dx.toStringAsFixed(1)}, '
              '${transform.origin.dy.toStringAsFixed(1)})'
        : '⚠ 已手动缩放 ×${_calibration.scaleFactor.toStringAsFixed(4)}，'
              '当前不是严格 1:1；原点是 '
              '(${transform.origin.dx.toStringAsFixed(1)}, '
              '${transform.origin.dy.toStringAsFixed(1)})';

    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_dpiChecked && _dpi == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  '⚠ 未取到设备物理 DPI，无法做 1:1（已切到总览）。'
                  '此模式下格子与物理钉位不对应。',
                  style: TextStyle(color: AppColors.warning),
                ),
              ),
            if (_paletteError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '⚠ 夹具色卡加载失败：$_paletteError',
                  style: const TextStyle(color: AppColors.warning),
                ),
              ),
            if (_calibrationError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '⚠ 校准参数读写异常：$_calibrationError',
                  style: const TextStyle(color: AppColors.warning),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('1:1 窗口'),
                  selected: _oneToOne && physical != null,
                  onSelected: (_) => _setOneToOne(true),
                ),
                ChoiceChip(
                  label: const Text('总览'),
                  selected: !_oneToOne || physical == null,
                  onSelected: (_) => _setOneToOne(false),
                ),
                const SizedBox(width: 8),
                if (hasImportedPattern)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    // 一枚徽章兼两职：说明"这是导入的图纸"，点它即可保存。
                    // 刻意不新增控件 —— 顶部面板已够挤，多一行会挡住网格。
                    child: ActionChip(
                      avatar: Icon(
                        _project == null
                            ? Icons.save_outlined
                            : (_saveError == null
                                  ? Icons.save
                                  : Icons.error_outline),
                        size: 16,
                        color: _saveError == null ? null : AppColors.warning,
                      ),
                      label: Text(
                        _saveError ??
                            (_project == null
                                ? '已导入图纸 ${pattern.rows} × ${pattern.cols} · 点此保存'
                                : '已保存 · ${_project!.name}'),
                      ),
                      onPressed: _project == null
                          ? _saveAsNewProject
                          : () => unawaited(_saveProject()),
                    ),
                  ),
                for (int i = 0; i < sizePresets.length; i++)
                  ChoiceChip(
                    label: Text(sizePresets[i].label),
                    selected: _presetIndex == i,
                    // 导入的图纸尺寸固定，预设尺寸无意义 -> 禁用
                    onSelected: hasImportedPattern
                        ? null
                        : (_) => _changePreset(i),
                  ),
                const SizedBox(width: 8),
                for (final SyntheticKind kind in SyntheticKind.values)
                  ChoiceChip(
                    label: Text(switch (kind) {
                      SyntheticKind.diagonalCross => '对角十字',
                      SyntheticKind.bands => '色带',
                      SyntheticKind.checker => '棋盘',
                    }),
                    selected: _kind == kind,
                    onSelected: hasImportedPattern
                        ? null
                        : (_) => _changeKind(kind),
                  ),
                // 编辑入口刻意做成**图标按钮**：顶部面板已经很挤，
                // 再加带文字的控件会多占一行，直接压到网格上。
                IconButton.filledTonal(
                  tooltip: _editing ? '退出编辑' : '编辑图纸',
                  onPressed: _editing ? _exitEditMode : _enterEditMode,
                  icon: Icon(_editing ? Icons.edit_off : Icons.edit),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('亮点'),
                  selected: _cellStyle == PegCellStyle.centeredDot,
                  onSelected: (_) =>
                      setState(() => _cellStyle = PegCellStyle.centeredDot),
                ),
                ChoiceChip(
                  label: const Text('填充'),
                  selected: _cellStyle == PegCellStyle.filled,
                  onSelected: (_) =>
                      setState(() => _cellStyle = PegCellStyle.filled),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('标尺校验'),
                  selected: _showRuler,
                  onSelected: (bool value) =>
                      setState(() => _showRuler = value),
                ),
                ChoiceChip(
                  label: const Text('10 格/50mm'),
                  selected: _rulerPegSpan == 10,
                  onSelected: (_) => setState(() => _rulerPegSpan = 10),
                ),
                ChoiceChip(
                  label: const Text('20 格/100mm'),
                  selected: _rulerPegSpan == 20,
                  onSelected: (_) => setState(() => _rulerPegSpan = 20),
                ),
                FilterChip(
                  label: const Text('四角锚点'),
                  selected: _showAnchors,
                  onSelected: (bool value) =>
                      setState(() => _showAnchors = value),
                ),
                FilledButton.tonalIcon(
                  onPressed: _openEyeCareSheet,
                  icon: const Icon(Icons.remove_red_eye, size: 18),
                  label: Text(_eyeCare.enabled ? '护眼 开' : '护眼 关'),
                ),
                OutlinedButton(
                  onPressed: locked ? null : _resetCalibration,
                  child: const Text('归位'),
                ),
                OutlinedButton(
                  onPressed: () => setState(() => _showControls = false),
                  child: const Text('隐藏控件'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                const Text('微调步长'),
                ChoiceChip(
                  label: const Text('0.5 mm'),
                  selected: _nudgeStepMm == 0.5,
                  onSelected: (_) => setState(() => _nudgeStepMm = 0.5),
                ),
                ChoiceChip(
                  label: Text('1 格 (${_calibration.pitchMm}mm)'),
                  selected: _nudgeStepMm == _calibration.pitchMm,
                  onSelected: (_) =>
                      setState(() => _nudgeStepMm = _calibration.pitchMm),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: '网格上移',
                  onPressed: _canAdjust ? () => _nudge(dySteps: -1) : null,
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
                IconButton(
                  tooltip: '网格下移',
                  onPressed: _canAdjust ? () => _nudge(dySteps: 1) : null,
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
                IconButton(
                  tooltip: '网格左移',
                  onPressed: _canAdjust ? () => _nudge(dxSteps: -1) : null,
                  icon: const Icon(Icons.keyboard_arrow_left),
                ),
                IconButton(
                  tooltip: '网格右移',
                  onPressed: _canAdjust ? () => _nudge(dxSteps: 1) : null,
                  icon: const Icon(Icons.keyboard_arrow_right),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  // 锁定后只保留"长按解锁"这一条出路，避免误触改坏校准。
                  onLongPress: locked ? _toggleLock : null,
                  child: FilterChip(
                    label: Text(locked ? '🔒 已锁定（长按解锁）' : '未锁定（点击锁定）'),
                    selected: locked,
                    onSelected: (_) {
                      if (!locked) {
                        _toggleLock();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                const Text('网格线宽'),
                SizedBox(
                  width: 180,
                  child: Slider(
                    value: _lineWidth,
                    max: 2,
                    divisions: 20,
                    label: _lineWidth.toStringAsFixed(2),
                    onChanged: (double value) =>
                        setState(() => _lineWidth = value),
                  ),
                ),
                Text(_lineWidth.toStringAsFixed(2)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              metricsLine,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            Text(
              '显示：${isOneToOne ? "1:1（与物理钉位对应）" : "总览（非 1:1）"}　'
              '可见窗口 ${visible.colCount} 列 × ${visible.rowCount} 行（含边缘不完整格）　'
              '图纸 ${pattern.cols} × ${pattern.rows}　'
              '窗口原点 (${transform.origin.dx.toStringAsFixed(0)}, '
              '${transform.origin.dy.toStringAsFixed(0)})',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            Text(
              calibrationLine,
              style: TextStyle(
                color: _calibration.isStrictlyOneToOne
                    ? AppColors.textSecondary
                    : AppColors.warning,
                fontSize: 12,
              ),
            ),
            Text(
              _selectedReadout(pattern),
              style: const TextStyle(color: AppColors.accent, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
