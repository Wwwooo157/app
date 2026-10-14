import 'package:bead_light_board/features/eye_care/domain/eye_care_settings.dart';
import 'package:bead_light_board/features/eye_care/presentation/eye_care_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<EyeCareSettings>> pumpSheet(
  WidgetTester tester, {
  EyeCareSettings initial = const EyeCareSettings(),
}) async {
  final List<EyeCareSettings> changes = <EyeCareSettings>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EyeCareSheet(initial: initial, onChanged: changes.add),
      ),
    ),
  );
  await tester.pump();
  return changes;
}

void main() {
  testWidgets('展示默认值：亮度 85%、暖色 25%', (WidgetTester tester) async {
    await pumpSheet(tester);
    expect(find.textContaining('亮度（越小反光越弱）：85%'), findsOneWidget);
    expect(find.textContaining('暖色：25%'), findsOneWidget);
    expect(find.textContaining('不影响图纸数据的准确性'), findsOneWidget);
  });

  testWidgets('总开关默认打开，关掉后即时回调', (WidgetTester tester) async {
    final List<EyeCareSettings> changes = await pumpSheet(tester);

    final Switch toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(changes, hasLength(1));
    expect(changes.single.enabled, isFalse);
  });

  testWidgets('护眼关闭时亮度/暖色/低对比不可调（但常亮与沉浸式仍可改）', (WidgetTester tester) async {
    await pumpSheet(tester, initial: const EyeCareSettings(enabled: false));

    final Slider brightness = tester.widget<Slider>(find.byType(Slider).first);
    expect(brightness.onChanged, isNull);

    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, '低对比'))
          .onSelected,
      isNull,
    );
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, '屏幕常亮'))
          .onSelected,
      isNotNull,
    );
  });

  testWidgets('切换低对比/常亮/沉浸式都会即时回调', (WidgetTester tester) async {
    final List<EyeCareSettings> changes = await pumpSheet(tester);

    await tester.tap(find.widgetWithText(FilterChip, '低对比'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, '屏幕常亮'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, '沉浸式全屏'));
    await tester.pump();

    expect(changes, hasLength(3));
    expect(changes[0].lowContrast, isTrue);
    expect(changes[1].keepScreenOn, isFalse);
    expect(changes[2].immersive, isFalse);
  });

  testWidgets('拖动亮度滑杆会回调新的亮度值', (WidgetTester tester) async {
    final List<EyeCareSettings> changes = await pumpSheet(tester);

    final Slider brightness = tester.widget<Slider>(find.byType(Slider).first);
    brightness.onChanged!(0.5);
    await tester.pump();

    expect(changes, hasLength(1));
    expect(changes.single.brightness, closeTo(0.5, 1e-9));
  });
}
