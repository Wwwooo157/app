import 'dart:io';

import 'package:bead_light_board/data/models/bead_pattern.dart';
import 'package:bead_light_board/features/calibrate/data/calibration_storage.dart';
import 'package:bead_light_board/features/edit/presentation/edit_toolbar.dart';
import 'package:bead_light_board/features/grid/data/physical_dpi.dart';
import 'package:bead_light_board/features/grid/domain/grid_style.dart';
import 'package:bead_light_board/features/grid/presentation/grid_canvas.dart';
import 'package:bead_light_board/features/grid/presentation/grid_painter.dart';
import 'package:bead_light_board/features/grid/presentation/grid_screen.dart';
import 'package:bead_light_board/features/guide/presentation/guide_panel.dart';
import 'package:bead_light_board/features/projects/data/project_repository.dart';
import 'package:bead_light_board/features/projects/data/project_storage.dart';
import 'package:bead_light_board/features/projects/domain/project.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(physicalDpiChannelName);
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  /// 用本机平板的真实参数铺满测试窗口（OPPO Pad：2560x1600 @ 2.25）。
  void useTabletViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2.25;
    addTearDown(tester.view.reset);
  }

  /// 注册平台通道 mock。
  ///
  /// **必须注册**：不注册的话平台调用永不回应，`loadPhysicalDpiFromPlatform`
  /// 的超时定时器会一直挂着，测试结束时报 "A Timer is still pending"。
  /// [available] 为 false 时返回 null，等价于"平台没有实现"。
  void mockDpi({bool available = true}) {
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      if (!available) {
        return null;
      }
      return <String, Object?>{
        'xdpi': 276.462,
        'ydpi': 275.525,
        'densityDpi': 360,
      };
    });
  }

  /// 内存版校准存储（不碰 path_provider）。
  ({CalibrationRepository repository, InMemoryCalibrationStorage storage})
  makeCalibration([String? initial]) {
    final InMemoryCalibrationStorage storage = InMemoryCalibrationStorage(
      initial,
    );
    return (
      repository: CalibrationRepository(storage: storage),
      storage: storage,
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    CalibrationRepository? repository,
    BeadPattern? importedPattern,
    Project? project,
    ProjectRepository? projectRepository,
    String? sourceImageName,
    Duration autoSaveDebounce = Duration.zero,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GridScreen(
          calibrationRepository: repository ?? makeCalibration().repository,
          importedPattern: importedPattern,
          project: project,
          projectRepository: projectRepository,
          sourceImageName: sourceImageName,
          autoSaveDebounce: autoSaveDebounce,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder nudgeButton(IconData icon) => find.widgetWithIcon(IconButton, icon);

  testWidgets('拿不到物理 DPI 时明确提示，并强制切到总览（不假装 1:1）', (WidgetTester tester) async {
    useTabletViewport(tester);
    mockDpi(available: false);

    await pumpScreen(tester);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('未取到设备物理 DPI'), findsOneWidget);
    expect(find.textContaining('总览（非 1:1）'), findsOneWidget);
  });

  testWidgets('拿到真实 DPI 后走 1:1，可见窗口按真实物理尺寸算出', (WidgetTester tester) async {
    useTabletViewport(tester);
    mockDpi();

    await pumpScreen(tester);

    expect(tester.takeException(), isNull);
    // 1 格 = 24.19 逻辑像素（5mm / 25.4 * 276.462 / 2.25）
    expect(find.textContaining('24.19'), findsOneWidget);
    expect(find.textContaining('1:1（与物理钉位对应）'), findsOneWidget);
    // 屏幕逻辑尺寸 1137.78 x 711.11：
    //   列：1137.78 / 24.1874 = 47.04 -> 完整放下 47 列，与画布相交 48 列（第 47 列只露一点）
    //   行： 711.11 / 24.1054 = 29.50 -> 完整放下 29 行，与画布相交 30 行
    expect(find.textContaining('可见窗口 48 列 × 30 行（含边缘不完整格）'), findsOneWidget);
    expect(find.textContaining('图纸 52 × 52'), findsOneWidget);
    // 默认就是严格 1:1
    expect(find.textContaining('严格 1:1（未做手动缩放）'), findsOneWidget);
  });

  testWidgets('切换图案尺寸与画法不崩，并能选格', (WidgetTester tester) async {
    useTabletViewport(tester);
    mockDpi();

    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, '29 × 29'));
    await tester.pumpAndSettle();
    expect(find.textContaining('图纸 29 × 29'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '填充'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(ChoiceChip, '棋盘'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 点屏幕中间应命中一个格子（1:1 时格子很大，中心必然在图纸内）
    await tester.tapAt(const Offset(500, 400));
    await tester.pumpAndSettle();
    expect(find.textContaining('已选中：第'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('隐藏控件后只剩网格与一个恢复按钮', (WidgetTester tester) async {
    useTabletViewport(tester);
    mockDpi(available: false);

    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, '隐藏控件'));
    await tester.pumpAndSettle();

    expect(find.text('隐藏控件'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('S5 校准', () {
    testWidgets('微调按钮移动网格，并立刻写入存储', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      final ({
        CalibrationRepository repository,
        InMemoryCalibrationStorage storage,
      })
      calibration = makeCalibration();

      await pumpScreen(tester, repository: calibration.repository);
      expect(find.textContaining('原点 (0.0, 0.0)'), findsOneWidget);

      await tester.tap(nudgeButton(Icons.keyboard_arrow_right));
      await tester.pumpAndSettle();

      // 0.5mm × 4.83748 px/mm ≈ 2.42 逻辑像素
      expect(find.textContaining('原点 (2.4, 0.0)'), findsOneWidget);
      expect(calibration.storage.writeCount, 1);
      expect(await calibration.storage.read(), contains('originDx'));

      // 按格数移动：1 格 = 5mm ≈ 24.19 逻辑像素
      await tester.tap(find.widgetWithText(ChoiceChip, '1 格 (5.0mm)'));
      await tester.pumpAndSettle();
      await tester.tap(nudgeButton(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();
      expect(find.textContaining('原点 (2.4, 24.1)'), findsOneWidget);
    });

    testWidgets('锁定后微调按钮禁用、手势失效；长按可解锁', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();

      await pumpScreen(tester);

      await tester.tap(find.text('未锁定（点击锁定）'));
      await tester.pumpAndSettle();
      expect(find.text('🔒 已锁定（长按解锁）'), findsOneWidget);

      // 按钮被禁用
      final IconButton right = tester.widget<IconButton>(
        nudgeButton(Icons.keyboard_arrow_right),
      );
      expect(right.onPressed, isNull);

      // 即使强行点也不动
      await tester.tap(
        nudgeButton(Icons.keyboard_arrow_right),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('原点 (0.0, 0.0)'), findsOneWidget);

      // 长按解锁 → 恢复可调
      await tester.longPress(find.text('🔒 已锁定（长按解锁）'));
      await tester.pumpAndSettle();
      expect(find.text('未锁定（点击锁定）'), findsOneWidget);
      final IconButton rightAfter = tester.widget<IconButton>(
        nudgeButton(Icons.keyboard_arrow_right),
      );
      expect(rightAfter.onPressed, isNotNull);
    });

    testWidgets('捏合缩放会明确标出"不是严格 1:1"，并把缩放写进存储', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      final ({
        CalibrationRepository repository,
        InMemoryCalibrationStorage storage,
      })
      calibration = makeCalibration();

      await pumpScreen(tester, repository: calibration.repository);
      expect(find.textContaining('严格 1:1（未做手动缩放）'), findsOneWidget);

      final Offset center = tester.getCenter(find.byType(GridCanvas));
      final TestGesture first = await tester.startGesture(
        center - const Offset(60, 0),
      );
      final TestGesture second = await tester.startGesture(
        center + const Offset(60, 0),
      );
      await first.moveBy(const Offset(-60, 0));
      await second.moveBy(const Offset(60, 0));
      await first.up();
      await second.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('已手动缩放'), findsOneWidget);
      expect(find.textContaining('当前不是严格 1:1'), findsOneWidget);
      expect(await calibration.storage.read(), contains('scaleFactor'));
    });

    testWidgets('归位把缩放与位移清回严格 1:1，但保留锁定状态', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      const String saved =
          '{"schemaVersion":1,"pitchMm":5,"scaleFactor":1.01,'
          '"originDx":-12.0,"originDy":-30.0,"locked":true}';
      final ({
        CalibrationRepository repository,
        InMemoryCalibrationStorage storage,
      })
      calibration = makeCalibration(saved);

      await pumpScreen(tester, repository: calibration.repository);
      expect(find.textContaining('已手动缩放'), findsOneWidget);
      expect(find.textContaining('🔒 已锁定（长按解锁）'), findsOneWidget);

      // 锁定状态下"归位"按钮是禁用的
      final OutlinedButton reset = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '归位'),
      );
      expect(reset.onPressed, isNull);

      // 解锁后归位
      await tester.longPress(find.text('🔒 已锁定（长按解锁）'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '归位'));
      await tester.pumpAndSettle();

      expect(find.textContaining('严格 1:1（未做手动缩放）'), findsOneWidget);
      expect(find.textContaining('原点 (0.0, 0.0)'), findsOneWidget);
    });

    testWidgets('启动时恢复已保存的校准（位置 + 缩放 + 锁定）', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      const String saved =
          '{"schemaVersion":1,"pitchMm":5,"scaleFactor":1.0,'
          '"originDx":-12.0,"originDy":-30.0,"locked":true}';

      await pumpScreen(tester, repository: makeCalibration(saved).repository);

      expect(find.textContaining('原点 (-12.0, -30.0)'), findsOneWidget);
      expect(find.textContaining('🔒 已锁定（长按解锁）'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('校准文件损坏时回退到严格 1:1 并给出提示，不影响使用', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      const String broken =
          '{"schemaVersion":1,"pitchMm":5,"scaleFactor":99,'
          '"originDx":0,"originDy":0,"locked":false}';

      await pumpScreen(tester, repository: makeCalibration(broken).repository);

      expect(find.textContaining('校准参数读写异常'), findsOneWidget);
      expect(find.textContaining('严格 1:1（未做手动缩放）'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('四角锚点开关可切换且不崩', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();

      await pumpScreen(tester);

      await tester.tap(find.widgetWithText(FilterChip, '四角锚点'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(FilterChip, '四角锚点'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('S7 护眼', () {
    /// 取出当前实际用于绘制的网格样式。
    GridStyle currentGridStyle(WidgetTester tester) {
      final CustomPaint paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(GridCanvas),
          matching: find.byType(CustomPaint),
        ),
      );
      return (paint.painter! as GridPainter).style;
    }

    testWidgets('默认护眼开启，可打开设置面板并改动设置', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      await pumpScreen(tester);

      expect(find.text('护眼 开'), findsOneWidget);

      await tester.tap(find.text('护眼 开'));
      await tester.pumpAndSettle();
      expect(find.text('护眼与显示'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, '屏幕常亮'));
      await tester.pumpAndSettle();

      final GridScreenState state = tester.state<GridScreenState>(
        find.byType(GridScreen),
      );
      expect(state.eyeCareSettings.keepScreenOn, isFalse);
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(FilledButton, '完成'));
      await tester.pumpAndSettle();
      expect(find.text('护眼与显示'), findsNothing);
    });

    testWidgets('低对比开关会让网格线变暗', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      await pumpScreen(tester);

      final Color normalLine = currentGridStyle(tester).lineColor;

      await tester.tap(find.text('护眼 开'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, '低对比'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '完成'));
      await tester.pumpAndSettle();

      final Color lowLine = currentGridStyle(tester).lineColor;
      expect(lowLine, isNot(normalLine));
      expect(
        lowLine.computeLuminance(),
        lessThan(normalLine.computeLuminance()),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('护眼开启时叠加调光与暖色层，且不拦截网格手势', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      await pumpScreen(tester);

      // 默认 brightness 0.85 -> 有调光层；warmth 0.25 -> 有暖色滤镜
      expect(find.byType(ColorFiltered), findsOneWidget);
      expect(find.byType(IgnorePointer), findsWidgets);

      // 调光层不能拦住网格：仍然能选格
      await tester.tapAt(const Offset(500, 400));
      await tester.pump();
      expect(find.textContaining('已选中：第'), findsOneWidget);
    });
  });

  group('M1 导入的图纸', () {
    BeadPattern imported() => BeadPattern.filled(
      rows: 20,
      cols: 30,
      paletteId: 'test_fixture',
      colorIndex: 1,
    )..setColorIndexAt(0, 0, 0);

    testWidgets('显示导入图纸的尺寸，并禁用尺寸/合成图案预设', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();

      await pumpScreen(tester, importedPattern: imported());

      expect(find.textContaining('已导入图纸 20 × 30'), findsOneWidget);
      // 图纸状态栏也报出真实尺寸
      expect(find.textContaining('图纸 30 × 20'), findsOneWidget);

      for (final String label in <String>['29 × 29', '52 × 52', '色带', '棋盘']) {
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
              .onSelected,
          isNull,
          reason: '$label 在导入图纸后应被禁用',
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('没有导入图纸时预设仍可用（回归保护）', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();

      await pumpScreen(tester);

      expect(find.textContaining('已导入图纸'), findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '29 × 29'))
            .onSelected,
        isNotNull,
      );
    });

    testWidgets('导入图纸的颜色能正常进入引导（用量统计生效）', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();

      await pumpScreen(tester, importedPattern: imported());

      // 600 格里 1 格是色号 0，其余是色号 1
      expect(find.textContaining('0/600 颗'), findsOneWidget);
      expect(find.textContaining('已完成 0/2 色'), findsOneWidget);
      expect(find.textContaining('剩 599'), findsOneWidget);
      expect(find.text('剩 1'), findsOneWidget);
    });
  });

  group('M5 项目保存与继续', () {
    BeadPattern pattern() => BeadPattern.filled(
      rows: 20,
      cols: 30,
      paletteId: 'test_fixture',
      colorIndex: 1,
    )..setColorIndexAt(0, 0, 0);

    ({ProjectRepository repository, InMemoryProjectStorage storage})
    makeProjects() {
      final InMemoryProjectStorage storage = InMemoryProjectStorage();
      return (
        repository: ProjectRepository(
          storage: storage,
          clock: () => DateTime(2026, 2, 14, 12),
        ),
        storage: storage,
      );
    }

    testWidgets('打开已保存的项目：图纸与进度都恢复', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      final ({ProjectRepository repository, InMemoryProjectStorage storage})
      projects = makeProjects();
      final Project project = projects.repository.create(
        name: '心形',
        pattern: pattern(),
      );
      // 让项目带上真实进度：把用量最多的那色标记为完成
      project.progress.setColorCompleted(1, completed: true);

      await pumpScreen(
        tester,
        project: project,
        projectRepository: projects.repository,
      );

      expect(find.textContaining('已保存 · 心形'), findsOneWidget);
      // 600 格里 599 格是色号 1 → 完成该色后进度立刻可见
      expect(find.textContaining('599/600 颗'), findsOneWidget);
      expect(find.textContaining('已完成 1/2 色'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('标记当前色完成后自动落盘（重启能接着拼）', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      final ({ProjectRepository repository, InMemoryProjectStorage storage})
      projects = makeProjects();
      final Project project = projects.repository.create(
        name: '心形',
        pattern: pattern(),
      );
      await projects.repository.save(project);
      final int writesBefore = projects.storage.writeCount;

      await pumpScreen(
        tester,
        project: project,
        projectRepository: projects.repository,
      );

      // 关掉闪烁，避免页面一直有动画（否则 pumpAndSettle 等不到静止）
      await tester.tap(find.widgetWithText(FilterChip, '闪烁'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '下一色'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '标记当前色完成'));
      await tester.pumpAndSettle();

      expect(
        projects.storage.writeCount,
        greaterThan(writesBefore),
        reason: '进度变化后应当自动保存',
      );
      final Project reloaded = (await projects.repository.loadAll()).single;
      expect(reloaded.progress.completedColorCount, 1);
      expect(reloaded.name, '心形');
    });

    testWidgets('未保存的导入图纸：点徽章能保存成项目，默认名取自图片名', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      final ({ProjectRepository repository, InMemoryProjectStorage storage})
      projects = makeProjects();

      await pumpScreen(
        tester,
        importedPattern: pattern(),
        projectRepository: projects.repository,
        sourceImageName: 'sample_heart.png',
      );

      expect(find.textContaining('点此保存'), findsOneWidget);
      await tester.tap(find.textContaining('点此保存'));
      await tester.pumpAndSettle();

      expect(find.text('保存图纸'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'sample_heart',
      );

      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      expect(find.textContaining('已保存 · sample_heart'), findsOneWidget);
      final Project saved = (await projects.repository.loadAll()).single;
      expect(saved.name, 'sample_heart');
      expect(saved.sourceImageName, 'sample_heart.png');
      expect(saved.pattern.rows, 20);
      expect(saved.pattern.cols, 30);
    });

    testWidgets('保存对话框取消时不建项目', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      final ({ProjectRepository repository, InMemoryProjectStorage storage})
      projects = makeProjects();

      await pumpScreen(
        tester,
        importedPattern: pattern(),
        projectRepository: projects.repository,
      );

      await tester.tap(find.textContaining('点此保存'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();

      expect(await projects.repository.loadAll(), isEmpty);
      expect(find.textContaining('点此保存'), findsOneWidget);
    });

    testWidgets('写盘失败时明确报错，不假装已保存', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();

      await pumpScreen(
        tester,
        importedPattern: pattern(),
        projectRepository: ProjectRepository(storage: FailingProjectStorage()),
      );

      await tester.tap(find.textContaining('点此保存'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      expect(find.textContaining('保存失败'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('合成图案（非导入）不显示保存徽章', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();

      await pumpScreen(tester, projectRepository: makeProjects().repository);

      expect(find.textContaining('点此保存'), findsNothing);
      expect(find.textContaining('已保存'), findsNothing);
    });
  });

  group('S10 图纸编辑', () {
    /// 两色图纸：底色 1，左上角一格是 0（于是"用量最多的颜色"是 1）。
    BeadPattern pattern() => BeadPattern.filled(
      rows: 20,
      cols: 30,
      paletteId: 'test_fixture',
      colorIndex: 1,
    )..setColorIndexAt(0, 0, 0);

    /// 画布上确定落在图纸内的一点（逻辑坐标，避开上下两块面板）。
    const Offset canvasPoint = Offset(267, 400);

    ({ProjectRepository repository, InMemoryProjectStorage storage})
    makeProjects() {
      final InMemoryProjectStorage storage = InMemoryProjectStorage();
      return (
        repository: ProjectRepository(
          storage: storage,
          clock: () => DateTime(2026, 2, 14, 12),
        ),
        storage: storage,
      );
    }

    List<int> colorsOf(BeadPattern p) => <int>[
      for (int row = 0; row < p.rows; row++)
        for (int col = 0; col < p.cols; col++) p.colorIndexAt(row, col),
    ];

    int diffCount(List<int> a, List<int> b) {
      int count = 0;
      for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) {
          count++;
        }
      }
      return count;
    }

    /// 在工具栏内部查找文案。
    ///
    /// 必须限定范围：顶部面板也有「填充」（格子样式），全局 find.text 会撞名。
    Finder inToolbar(String label) => find.descendant(
      of: find.byType(EditToolbar),
      matching: find.text(label),
    );

    Future<void> enterEdit(WidgetTester tester) async {
      await tester.tap(find.byTooltip('编辑图纸'));
      await tester.pumpAndSettle();
      expect(find.byType(EditToolbar), findsOneWidget);
    }

    testWidgets('进入编辑模式：工具栏顶替引导面板', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      await pumpScreen(tester, importedPattern: pattern());

      expect(find.byType(GuidePanel), findsOneWidget);
      expect(find.byType(EditToolbar), findsNothing);

      await enterEdit(tester);

      final GridScreenState state = tester.state<GridScreenState>(
        find.byType(GridScreen),
      );
      expect(state.isEditing, isTrue);
      expect(find.byType(EditToolbar), findsOneWidget);
      expect(find.byType(GuidePanel), findsNothing);
      expect(inToolbar('画笔'), findsOneWidget);
      expect(inToolbar('填充'), findsOneWidget);
      expect(inToolbar('吸管'), findsOneWidget);
      expect(inToolbar('四向'), findsOneWidget);
      expect(find.textContaining('点此保存'), findsOneWidget);
      // 色卡必须真的加载出来了，否则色号会退化成 ?N
      expect(inToolbar('T06'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('拖动绘制改色，且整笔只算一步撤销（撤销/重做都对）', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      final BeadPattern editable = pattern();
      await pumpScreen(tester, importedPattern: editable);

      final List<int> before = colorsOf(editable);
      await enterEdit(tester);

      // 换一个与图纸现有颜色不同的刷子色（夹具色卡含 T01..T08）
      await tester.tap(inToolbar('T06'));
      await tester.pumpAndSettle();

      await tester.dragFrom(canvasPoint, const Offset(80, 0));
      await tester.pumpAndSettle();

      final GridScreenState state = tester.state<GridScreenState>(
        find.byType(GridScreen),
      );
      final List<int> afterDrag = colorsOf(editable);
      expect(
        diffCount(before, afterDrag),
        greaterThan(1),
        reason: '拖动应当改到多格（说明插值生效）',
      );
      expect(state.editHistory.undoDepth, 1, reason: '整笔只算一步');

      await tester.tap(find.byTooltip('撤销'));
      await tester.pumpAndSettle();
      expect(colorsOf(editable), before, reason: '撤销应当完全恢复');

      await tester.tap(find.byTooltip('重做'));
      await tester.pumpAndSettle();
      expect(colorsOf(editable), afterDrag, reason: '重做应当回到绘制后');

      // 撤销按钮此时应当可用（历史还在）
      expect(state.editHistory.canUndo, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('左右对称：一次落笔同时改两侧（格数为偶数）', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      final BeadPattern editable = pattern();
      await pumpScreen(tester, importedPattern: editable);
      await enterEdit(tester);

      await tester.tap(inToolbar('T06'));
      await tester.pumpAndSettle();
      await tester.tap(inToolbar('左右'));
      await tester.pumpAndSettle();

      await tester.tapAt(canvasPoint);
      await tester.pumpAndSettle();

      final int changed = diffCount(colorsOf(pattern()), colorsOf(editable));
      expect(changed, greaterThanOrEqualTo(2), reason: '对称应当至少改两格');
      expect(changed.isEven, isTrue, reason: '左右对称改的格数必须是偶数');
    });

    testWidgets('填充工具一次改一大片', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      final BeadPattern editable = pattern();
      await pumpScreen(tester, importedPattern: editable);
      await enterEdit(tester);

      await tester.tap(inToolbar('T06'));
      await tester.pumpAndSettle();
      await tester.tap(inToolbar('填充'));
      await tester.pumpAndSettle();
      await tester.tapAt(canvasPoint);
      await tester.pumpAndSettle();

      expect(
        diffCount(colorsOf(pattern()), colorsOf(editable)),
        greaterThan(50),
        reason: '油漆桶应当一次改一大片',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('吸管：取走那格的颜色，之后用画笔涂同色不应有变化', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      final BeadPattern editable = pattern();
      await pumpScreen(tester, importedPattern: editable);
      await enterEdit(tester);

      await tester.tap(inToolbar('T06'));
      await tester.pumpAndSettle();
      await tester.tap(inToolbar('吸管'));
      await tester.pumpAndSettle();
      // 画布上那一点的底色是色号 1（T02）
      await tester.tapAt(canvasPoint);
      await tester.pumpAndSettle();

      await tester.tap(inToolbar('画笔'));
      await tester.pumpAndSettle();
      await tester.tapAt(canvasPoint);
      await tester.pumpAndSettle();

      expect(
        colorsOf(editable),
        colorsOf(pattern()),
        reason: '吸管取到的就是底色，再涂一遍不该产生任何变化',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('编辑模式下点击不再选中格子（两种含义不冲突）', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      await pumpScreen(tester, importedPattern: pattern());

      await tester.tapAt(canvasPoint);
      await tester.pumpAndSettle();
      expect(find.textContaining('已选中：第'), findsOneWidget);

      await enterEdit(tester);
      await tester.tapAt(const Offset(400, 430));
      await tester.pumpAndSettle();
      expect(find.textContaining('已选中：第'), findsNothing);
    });

    testWidgets('编辑后退出会把新图纸写回项目', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      final ({ProjectRepository repository, InMemoryProjectStorage storage})
      projects = makeProjects();
      final Project project = projects.repository.create(
        name: '可编辑',
        pattern: pattern(),
      );
      await projects.repository.save(project);
      final int writesBefore = projects.storage.writeCount;

      await pumpScreen(
        tester,
        project: project,
        projectRepository: projects.repository,
      );
      await enterEdit(tester);

      await tester.tap(inToolbar('T06'));
      await tester.pumpAndSettle();
      await tester.tapAt(canvasPoint);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, '完成'));
      // 不能用 pumpAndSettle：退出编辑会恢复引导闪烁动画，永远等不到静止。
      // 显式 pump 一次，让防抖保存（Duration.zero）的定时器跑掉即可。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      final GridScreenState state = tester.state<GridScreenState>(
        find.byType(GridScreen),
      );
      expect(state.isEditing, isFalse);
      expect(find.byType(GuidePanel), findsOneWidget);
      expect(
        projects.storage.writeCount,
        greaterThan(writesBefore),
        reason: '编辑后应当自动落盘',
      );

      final Project reloaded = (await projects.repository.loadAll()).single;
      expect(
        colorsOf(reloaded.pattern),
        colorsOf(project.pattern),
        reason: '存回去的应当是编辑后的图纸',
      );
      expect(reloaded.name, '可编辑');
    });

    testWidgets('重来按钮把图纸恢复成进入编辑时的样子', (WidgetTester tester) async {
      useTabletViewport(tester);
      mockDpi();
      final BeadPattern editable = pattern();
      await pumpScreen(tester, importedPattern: editable);
      final List<int> baseline = colorsOf(editable);

      await enterEdit(tester);
      await tester.tap(inToolbar('T06'));
      await tester.pumpAndSettle();
      await tester.dragFrom(canvasPoint, const Offset(80, 0));
      await tester.pumpAndSettle();
      expect(colorsOf(editable), isNot(baseline));

      await tester.tap(find.widgetWithText(TextButton, '重来'));
      await tester.pumpAndSettle();
      expect(colorsOf(editable), baseline);
      expect(tester.takeException(), isNull);
    });
  });
}

/// 写入必定失败：验证界面会明确报错而不是假装成功。
final class FailingProjectStorage implements ProjectStorage {
  @override
  Future<Map<String, String>> readAll() async => <String, String>{};

  @override
  Future<void> write(String id, String content) async =>
      throw const FileSystemException('磁盘满了');

  @override
  Future<void> delete(String id) async {}
}
