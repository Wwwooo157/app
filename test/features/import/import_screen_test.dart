import 'dart:async';
import 'dart:typed_data';

import 'package:bead_light_board/data/models/palette.dart';
import 'package:bead_light_board/features/import/data/image_picker_service.dart';
import 'package:bead_light_board/features/import/domain/image_to_pattern.dart';
import 'package:bead_light_board/features/import/presentation/import_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// 两色夹具色卡（非真实色号）。
const String kPaletteJson = '''
{
  "schemaVersion": 1,
  "id": "test_fixture",
  "name": "夹具色卡",
  "colors": [
    { "code": "T01", "hex": "#C0554F" },
    { "code": "T02", "hex": "#3A3F45" }
  ]
}
''';

Palette fakePalette() => Palette.fromJsonText(kPaletteJson);

/// 造一张纯色 PNG。
Uint8List solidPng(int width, int height, int r, int g, int b) {
  final img.Image image = img.Image(
    width: width,
    height: height,
    numChannels: 4,
  );
  img.fill(image, color: img.ColorRgba8(r, g, b, 255));
  return Uint8List.fromList(img.encodePng(image));
}

class FakePicker implements ImagePickerService {
  FakePicker({this.image});

  final PickedImage? image;
  int callCount = 0;

  @override
  Future<PickedImage?> pickImage() async {
    callCount++;
    return image;
  }
}

PickedImage picked(Uint8List bytes) =>
    PickedImage(bytes: bytes, name: 'test.png');

/// 用真实流水线当 runner：小图瞬间完成，同时等于端到端验证。
Future<ImportOutcome> realRunner(ImportRequest request) async =>
    importImageToPattern(request);

/// 在真实 Navigator 里跑，便于断言 pop 出来的结果。
Future<void> pumpImport(
  WidgetTester tester, {
  required ImagePickerService picker,
  required void Function(ImportOutcome? outcome) onResult,
  ImportRunner runner = realRunner,
  Future<Uint8List> Function()? sampleLoader,
}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final ImportOutcome? outcome = await Navigator.of(context)
                    .push<ImportOutcome>(
                      MaterialPageRoute<ImportOutcome>(
                        builder: (BuildContext context) => ImportScreen(
                          picker: picker,
                          runner: runner,
                          paletteLoader: (String _) async => fakePalette(),
                          sampleLoader:
                              sampleLoader ??
                              () async => solidPng(96, 96, 200, 60, 50),
                        ),
                      ),
                    );
                onResult(outcome);
              },
              child: const Text('进入导入'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('进入导入'));
  await tester.pumpAndSettle();
}

Future<void> pickImage(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, '选择图片'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {});

  group('选择图片页', () {
    testWidgets('显示入口与色卡信息（含"非真实色号"提示）', (WidgetTester tester) async {
      await pumpImport(
        tester,
        picker: FakePicker(),
        onResult: (ImportOutcome? _) {},
      );

      expect(find.text('导入图片生成图纸'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '选择图片'), findsOneWidget);
      expect(find.textContaining('夹具色卡'), findsOneWidget);
      expect(find.textContaining('非真实色号'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('取消选图（返回 null）后仍停在选择页', (WidgetTester tester) async {
      final FakePicker picker = FakePicker();
      await pumpImport(tester, picker: picker, onResult: (ImportOutcome? _) {});

      await pickImage(tester);

      expect(picker.callCount, 1);
      expect(find.widgetWithText(FilledButton, '选择图片'), findsOneWidget);
      expect(find.textContaining('拖动平移'), findsNothing);
    });

    testWidgets('选图后进入裁剪页', (WidgetTester tester) async {
      await pumpImport(
        tester,
        picker: FakePicker(image: picked(solidPng(64, 32, 200, 60, 50))),
        onResult: (ImportOutcome? _) {},
      );

      await pickImage(tester);

      expect(find.byKey(cropFrameKey), findsOneWidget);
      expect(find.textContaining('拖动平移'), findsOneWidget);
      expect(find.textContaining('像素 →'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '生成图纸'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('裁剪页信息', () {
    testWidgets('默认 52×52，并显示选区像素与每格像素数', (WidgetTester tester) async {
      await pumpImport(
        tester,
        picker: FakePicker(image: picked(solidPng(200, 200, 200, 60, 50))),
        onResult: (ImportOutcome? _) {},
      );
      await pickImage(tester);

      expect(find.textContaining('52 × 52 格'), findsOneWidget);
      // 正方形图 + 正方形取景框 = 整图，200x200 → 每格 200*200/2704 ≈ 14.8
      expect(find.textContaining('每格约 15 个像素'), findsOneWidget);
    });

    testWidgets('分辨率太低时给出告警而不是假装没问题', (WidgetTester tester) async {
      await pumpImport(
        tester,
        // 24x24 图配 52x52 网格 → 每格 0.2 像素
        picker: FakePicker(image: picked(solidPng(24, 24, 200, 60, 50))),
        onResult: (ImportOutcome? _) {},
      );
      await pickImage(tester);

      expect(find.textContaining('会偏糊'), findsOneWidget);
    });

    testWidgets('切换到 29×29 会改变提示', (WidgetTester tester) async {
      await pumpImport(
        tester,
        picker: FakePicker(image: picked(solidPng(200, 200, 200, 60, 50))),
        onResult: (ImportOutcome? _) {},
      );
      await pickImage(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, '29 × 29'));
      await tester.pumpAndSettle();

      expect(find.textContaining('29 × 29 格'), findsOneWidget);
      expect(find.textContaining('52 × 52 格'), findsNothing);
    });

    testWidgets('拖动会真的改变选区（宽图在方框里可左右移动）', (WidgetTester tester) async {
      await pumpImport(
        tester,
        picker: FakePicker(image: picked(solidPng(200, 100, 200, 60, 50))),
        onResult: (ImportOutcome? _) {},
      );
      await pickImage(tester);

      final String before = tester
          .widget<Text>(find.textContaining('像素 →'))
          .data!;

      await tester.drag(find.byKey(cropFrameKey), const Offset(-120, 0));
      await tester.pumpAndSettle();

      final String after = tester
          .widget<Text>(find.textContaining('像素 →'))
          .data!;
      expect(after, isNot(before));
    });
  });

  group('生成图纸', () {
    testWidgets('按当前目标尺寸产出图纸并返回（端到端跑真实流水线）', (WidgetTester tester) async {
      ImportOutcome? result;
      await pumpImport(
        tester,
        picker: FakePicker(image: picked(solidPng(128, 128, 200, 60, 50))),
        onResult: (ImportOutcome? outcome) => result = outcome,
      );
      await pickImage(tester);

      await tester.tap(find.widgetWithText(FilledButton, '生成图纸'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.pattern.rows, 52);
      expect(result!.pattern.cols, 52);
      // 纯 #C83C32 红图 → 匹配到夹具色卡里最接近的 T01（索引 0）
      expect(result!.pattern.colorIndexAt(0, 0), 0);
      expect(result!.pattern.usedColorCount, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('切到 30×20 后产出的图纸尺寸随之改变', (WidgetTester tester) async {
      ImportOutcome? result;
      await pumpImport(
        tester,
        picker: FakePicker(image: picked(solidPng(120, 80, 200, 60, 50))),
        onResult: (ImportOutcome? outcome) => result = outcome,
      );
      await pickImage(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, '30 × 20'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '生成图纸'));
      await tester.pumpAndSettle();

      expect(result!.pattern.rows, 20);
      expect(result!.pattern.cols, 30);
    });

    testWidgets('生成失败时显示可读原因，且不退出页面', (WidgetTester tester) async {
      ImportOutcome? result;
      await pumpImport(
        tester,
        picker: FakePicker(image: picked(solidPng(64, 64, 10, 20, 30))),
        onResult: (ImportOutcome? outcome) => result = outcome,
        runner: (ImportRequest _) async =>
            throw const ImportException('色卡是空的：请先填真实色号。'),
      );
      await pickImage(tester);

      await tester.tap(find.widgetWithText(FilledButton, '生成图纸'));
      await tester.pumpAndSettle();

      expect(result, isNull);
      expect(find.textContaining('色卡是空的'), findsOneWidget);
      expect(find.byKey(cropFrameKey), findsOneWidget);
    });

    testWidgets('生成过程中按钮禁用，避免重复点击', (WidgetTester tester) async {
      final Completer<ImportOutcome> gate = Completer<ImportOutcome>();
      await pumpImport(
        tester,
        picker: FakePicker(image: picked(solidPng(64, 64, 10, 20, 30))),
        onResult: (ImportOutcome? _) {},
        runner: (ImportRequest _) => gate.future,
      );
      await pickImage(tester);

      await tester.tap(find.widgetWithText(FilledButton, '生成图纸'));
      await tester.pump();

      expect(find.text('正在生成…'), findsOneWidget);
      final FilledButton generate = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '正在生成…'),
      );
      expect(generate.onPressed, isNull);
    });
  });

  group('示例图', () {
    testWidgets('示例图按钮会加载内置示例并进入裁剪页（不碰相册）', (WidgetTester tester) async {
      final FakePicker picker = FakePicker();
      await pumpImport(
        tester,
        picker: picker,
        onResult: (ImportOutcome? _) {},
        sampleLoader: () async => solidPng(150, 150, 200, 60, 50),
      );

      await tester.tap(find.widgetWithText(TextButton, '用示例图试试'));
      await tester.pumpAndSettle();

      expect(picker.callCount, 0, reason: '示例图路径不应触碰相册');
      expect(find.byKey(cropFrameKey), findsOneWidget);
      expect(find.textContaining('像素 →'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('换一张', () {
    testWidgets('可以重新选图并重置裁剪', (WidgetTester tester) async {
      final FakePicker picker = FakePicker(
        image: picked(solidPng(200, 100, 200, 60, 50)),
      );
      await pumpImport(tester, picker: picker, onResult: (ImportOutcome? _) {});
      await pickImage(tester);

      await tester.drag(find.byKey(cropFrameKey), const Offset(-100, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '换一张'));
      await tester.pumpAndSettle();

      expect(picker.callCount, 2);
      expect(find.byKey(cropFrameKey), findsOneWidget);
    });
  });
}
