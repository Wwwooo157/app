import 'package:bead_light_board/features/guide/domain/guide_stats.dart';
import 'package:bead_light_board/features/guide/presentation/guide_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 4 色图纸、共 100 格、已放 40 格、1 色完成的固定夹具。
GuideStats statsFixture({int? active = 0}) => GuideStats(
  totalCells: 100,
  placedCells: 40,
  usedColorCount: 4,
  completedUsedColorCount: 1,
  activeColorIndex: active,
  activeColorTotal: 20,
  activeColorPlaced: 5,
);

const List<int> kOrder = <int>[0, 1, 2, 3];

Future<void> pumpPanel(
  WidgetTester tester, {
  GuideStats? stats,
  List<int> order = kOrder,
  Set<int> completed = const <int>{},
  bool hideOtherColors = false,
  bool blinkEnabled = true,
  bool perCellMarking = false,
  ValueChanged<int?>? onSelectColor,
  ValueChanged<int>? onStepColor,
  VoidCallback? onToggleCompleted,
  ValueChanged<bool>? onHideOthersChanged,
  ValueChanged<bool>? onBlinkChanged,
  ValueChanged<bool>? onPerCellMarkingChanged,
  VoidCallback? onResetProgress,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: GuidePanel(
            stats: stats ?? statsFixture(),
            usageOrder: order,
            colorOf: (int index) => Color(0xFF000010 + index),
            codeOf: (int index) => 'T0$index',
            remainingOf: (int index) => 100 - index,
            completedColors: completed,
            hideOtherColors: hideOtherColors,
            blinkEnabled: blinkEnabled,
            perCellMarking: perCellMarking,
            onSelectColor: onSelectColor ?? (int? _) {},
            onStepColor: onStepColor ?? (int _) {},
            onToggleCompleted: onToggleCompleted ?? () {},
            onHideOthersChanged: onHideOthersChanged ?? (bool _) {},
            onBlinkChanged: onBlinkChanged ?? (bool _) {},
            onPerCellMarkingChanged: onPerCellMarkingChanged ?? (bool _) {},
            onResetProgress: onResetProgress ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('进度显示', () {
    testWidgets('显示总进度、完成色数与当前色剩余颗数', (WidgetTester tester) async {
      await pumpPanel(tester, stats: statsFixture(active: 1));

      expect(find.textContaining('总进度 40%'), findsOneWidget);
      expect(find.textContaining('40/100 颗'), findsOneWidget);
      expect(find.textContaining('已完成 1/4 色'), findsOneWidget);
      expect(find.textContaining('当前色 T01'), findsOneWidget);
      expect(find.textContaining('剩 15 颗'), findsOneWidget);
      expect(find.textContaining('共 20 颗'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('未选色时提示"正常显示全部颜色"', (WidgetTester tester) async {
      await pumpPanel(tester, stats: statsFixture(active: null));
      expect(find.textContaining('未选色'), findsOneWidget);
    });

    testWidgets('进度条数值等于统计比例', (WidgetTester tester) async {
      await pumpPanel(tester);
      final LinearProgressIndicator bar = tester
          .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          );
      expect(bar.value, closeTo(0.4, 1e-9));
    });
  });

  group('色号条', () {
    testWidgets('每个色号都有色块、色号与剩余颗数', (WidgetTester tester) async {
      await pumpPanel(tester);
      for (final int index in kOrder) {
        expect(find.text('T0$index'), findsOneWidget);
        expect(find.text('剩 ${100 - index}'), findsOneWidget);
      }
    });

    testWidgets('点击色号回调该索引；再点已选中的色号回调 null（取消选中）', (WidgetTester tester) async {
      final List<int?> taps = <int?>[];
      await pumpPanel(
        tester,
        stats: statsFixture(active: 2),
        onSelectColor: taps.add,
      );

      await tester.tap(find.text('T01'));
      await tester.pump();
      expect(taps, <int?>[1]);

      await tester.tap(find.text('T02'));
      await tester.pump();
      expect(taps, <int?>[1, null]);
    });

    testWidgets('已完成的色号打勾显示', (WidgetTester tester) async {
      await pumpPanel(tester, completed: <int>{1});
      expect(find.text('T01 ✓'), findsOneWidget);
    });

    testWidgets('色卡为空时给出明确提示而不是空白', (WidgetTester tester) async {
      await pumpPanel(tester, order: const <int>[]);
      expect(find.textContaining('色卡为空'), findsOneWidget);
    });
  });

  group('按钮与开关', () {
    testWidgets('上一色/下一色回调方向', (WidgetTester tester) async {
      final List<int> steps = <int>[];
      await pumpPanel(tester, onStepColor: steps.add);

      await tester.tap(find.widgetWithText(OutlinedButton, '上一色'));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, '下一色'));
      await tester.pump();

      expect(steps, <int>[-1, 1]);
    });

    testWidgets('未选色时"标记当前色完成"禁用，选色后可用', (WidgetTester tester) async {
      await pumpPanel(tester, stats: statsFixture(active: null));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '标记当前色完成'))
            .onPressed,
        isNull,
      );

      await pumpPanel(tester, stats: statsFixture(active: 1));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '标记当前色完成'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('已是完成态时按钮显示"取消完成"', (WidgetTester tester) async {
      await pumpPanel(
        tester,
        stats: statsFixture(active: 1),
        completed: <int>{1},
      );
      expect(find.text('取消完成'), findsOneWidget);
    });

    testWidgets('三个开关与重置按钮都能回调', (WidgetTester tester) async {
      final List<String> events = <String>[];
      await pumpPanel(
        tester,
        onHideOthersChanged: (bool value) => events.add('hide=$value'),
        onBlinkChanged: (bool value) => events.add('blink=$value'),
        onPerCellMarkingChanged: (bool value) => events.add('perCell=$value'),
        onResetProgress: () => events.add('reset'),
      );

      await tester.tap(find.widgetWithText(FilterChip, '隐藏其他色'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, '闪烁'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, '逐格标记'));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, '重置进度'));
      await tester.pump();

      expect(events, <String>[
        'hide=true',
        'blink=false',
        'perCell=true',
        'reset',
      ]);
    });
  });
}
