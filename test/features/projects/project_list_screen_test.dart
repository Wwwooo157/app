import 'package:bead_light_board/features/projects/data/project_repository.dart';
import 'package:bead_light_board/features/projects/data/project_storage.dart';
import 'package:bead_light_board/features/projects/domain/project.dart';
import 'package:bead_light_board/features/projects/presentation/project_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'project_test.dart' show samplePattern;

void main() {
  late InMemoryProjectStorage storage;
  late ProjectRepository repository;

  setUp(() {
    storage = InMemoryProjectStorage();
    repository = ProjectRepository(
      storage: storage,
      clock: () => DateTime(2026, 2, 14, 12),
    );
  });

  Future<void> pumpList(
    WidgetTester tester, {
    void Function(Project? picked)? onPicked,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final Project? picked = await Navigator.of(context)
                      .push<Project>(
                        MaterialPageRoute<Project>(
                          builder: (BuildContext context) => ProjectListScreen(
                            repository: repository,
                            clock: () => DateTime(2026, 2, 14, 12),
                          ),
                        ),
                      );
                  onPicked?.call(picked);
                },
                child: const Text('进入列表'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('进入列表'));
    await tester.pumpAndSettle();
  }

  Future<Project> saveProject({
    String name = '心形',
    String? sourceImageName,
    int placedCells = 0,
  }) async {
    final Project project = repository.create(
      name: name,
      pattern: samplePattern(),
      sourceImageName: sourceImageName,
    );
    for (int i = 0; i < placedCells; i++) {
      project.progress.setPlaced(0, i % 5, placed: true);
    }
    await repository.save(project);
    return project;
  }

  testWidgets('没有项目时显示空状态与引导', (WidgetTester tester) async {
    await pumpList(tester);

    expect(find.text('我的图纸'), findsOneWidget);
    expect(find.text('还没有保存的图纸'), findsOneWidget);
    expect(find.textContaining('从首页导入一张图'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('列出项目名称、尺寸、色数、来源图与进度', (WidgetTester tester) async {
    await saveProject(
      name: '小红心',
      sourceImageName: 'heart.png',
      placedCells: 2,
    );
    await pumpList(tester);

    expect(find.text('小红心'), findsOneWidget);
    expect(find.textContaining('4 × 5'), findsOneWidget);
    expect(find.textContaining('来自 heart.png'), findsOneWidget);
    expect(find.textContaining('刚刚'), findsOneWidget);
    // 4x5 = 20 格，放了 2 格 -> 10%
    expect(find.textContaining('10%'), findsOneWidget);
    expect(find.textContaining('2/20'), findsOneWidget);
  });

  testWidgets('拼完的图纸带对勾', (WidgetTester tester) async {
    final Project project = repository.create(
      name: '拼完了',
      pattern: samplePattern(),
    );
    // 把所有用到的颜色标记为完成 -> 100%
    for (final int colorIndex in project.pattern.usageByColorIndex.keys) {
      project.progress.setColorCompleted(colorIndex, completed: true);
    }
    await repository.save(project);

    await pumpList(tester);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.textContaining('100%'), findsOneWidget);
  });

  testWidgets('点项目会把该项目交回调用方', (WidgetTester tester) async {
    Project? picked;
    await saveProject(name: '点我');
    await pumpList(tester, onPicked: (Project? p) => picked = p);

    await tester.tap(find.text('点我'));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.name, '点我');
  });

  testWidgets('重命名会保存并刷新列表', (WidgetTester tester) async {
    await saveProject(name: '旧名字');
    await pumpList(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '新名字');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('新名字'), findsOneWidget);
    expect(find.text('旧名字'), findsNothing);
    expect((await repository.loadAll()).single.name, '新名字');
  });

  testWidgets('重命名取消时什么都不改', (WidgetTester tester) async {
    await saveProject(name: '原名');
    await pumpList(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '不该生效');
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(find.text('原名'), findsOneWidget);
    expect((await repository.loadAll()).single.name, '原名');
  });

  testWidgets('删除需要二次确认，确认后真的删掉', (WidgetTester tester) async {
    await saveProject(name: '要删的');
    await pumpList(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('删除图纸？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('要删的'), findsNothing);
    expect(await repository.loadAll(), isEmpty);
    expect(find.text('还没有保存的图纸'), findsOneWidget);
  });

  testWidgets('删除时取消则保留', (WidgetTester tester) async {
    await saveProject(name: '留着');
    await pumpList(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(find.text('留着'), findsOneWidget);
    expect(await repository.loadAll(), hasLength(1));
  });

  testWidgets('有坏文件时照常列出好项目，并提示有文件读不出来', (WidgetTester tester) async {
    await saveProject(name: '好的');
    await storage.write('broken', '{"schemaVersion":1,"id":"broken"}');
    await pumpList(tester);

    expect(find.text('好的'), findsOneWidget);
    expect(find.textContaining('读不出来'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('刷新按钮能重新读盘', (WidgetTester tester) async {
    await pumpList(tester);
    expect(find.text('还没有保存的图纸'), findsOneWidget);

    // 绕过界面直接落一个项目，再点刷新（模拟"另一个入口保存了图纸"）
    await saveProject(name: '外部添加');
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.text('外部添加'), findsOneWidget);
  });
}
