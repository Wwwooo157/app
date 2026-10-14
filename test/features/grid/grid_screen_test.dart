import 'package:bead_light_board/features/calibrate/data/calibration_storage.dart';
import 'package:bead_light_board/features/grid/data/physical_dpi.dart';
import 'package:bead_light_board/features/grid/domain/grid_style.dart';
import 'package:bead_light_board/features/grid/presentation/grid_canvas.dart';
import 'package:bead_light_board/features/grid/presentation/grid_painter.dart';
import 'package:bead_light_board/features/grid/presentation/grid_screen.dart';
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
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GridScreen(
          calibrationRepository: repository ?? makeCalibration().repository,
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
}
