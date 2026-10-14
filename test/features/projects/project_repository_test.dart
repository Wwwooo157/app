import 'dart:async';
import 'dart:io';

import 'package:bead_light_board/data/models/json_support.dart';
import 'package:bead_light_board/features/projects/data/project_repository.dart';
import 'package:bead_light_board/features/projects/data/project_storage.dart';
import 'package:bead_light_board/features/projects/domain/project.dart';
import 'package:flutter_test/flutter_test.dart';

import 'project_test.dart' show samplePattern;

/// 永不回应的存储：验证超时兜底（真实场景 = 平台通道没有实现）。
final class NeverRespondingStorage implements ProjectStorage {
  @override
  Future<Map<String, String>> readAll() =>
      Completer<Map<String, String>>().future;

  @override
  Future<void> write(String id, String content) async {}

  @override
  Future<void> delete(String id) async {}
}

void main() {
  group('create', () {
    test('生成 id 与时间戳，并自动建一个空进度', () {
      final InMemoryProjectStorage storage = InMemoryProjectStorage();
      final ProjectRepository repository = ProjectRepository(
        storage: storage,
        clock: () => DateTime.utc(2026, 2, 14, 10),
      );

      final Project project = repository.create(
        name: '  心形  ',
        pattern: samplePattern(),
        sourceImageName: 'heart.png',
      );

      expect(project.id, startsWith('p'));
      expect(project.name, '心形', reason: '应去掉首尾空格');
      expect(project.createdAt, DateTime.utc(2026, 2, 14, 10));
      expect(project.updatedAt, project.createdAt);
      expect(project.sourceImageName, 'heart.png');
      expect(project.progress.rows, 4);
      expect(project.progress.cols, 5);
      expect(project.progress.directlyPlacedCount, 0);
    });

    test('名字为空时用默认名', () {
      final ProjectRepository repository = ProjectRepository(
        storage: InMemoryProjectStorage(),
      );
      expect(
        repository.create(name: '   ', pattern: samplePattern()).name,
        '未命名图纸',
      );
    });

    test('同一时刻连续新建也不会撞 id', () {
      final ProjectRepository repository = ProjectRepository(
        storage: InMemoryProjectStorage(),
        clock: () => DateTime.utc(2026),
      );
      final String a = repository
          .create(name: 'a', pattern: samplePattern())
          .id;
      final String b = repository
          .create(name: 'b', pattern: samplePattern())
          .id;
      expect(a, isNot(b));
    });
  });

  group('保存与读取', () {
    test('save 后能读回（内容一致）', () async {
      final InMemoryProjectStorage storage = InMemoryProjectStorage();
      final ProjectRepository repository = ProjectRepository(storage: storage);
      final Project project = repository.create(
        name: '测试',
        pattern: samplePattern(),
      )..progress.setPlaced(0, 0, placed: true);

      expect(await repository.save(project), isTrue);
      expect(storage.writeCount, 1);

      final List<Project> loaded = await repository.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.id, project.id);
      expect(loaded.single.name, '测试');
      expect(loaded.single.progress.isPlacedDirectly(0, 0), isTrue);
      expect(loaded.single.pattern.colorIndexAt(3, 4), 700);
    });

    test('存的是可读的缩进 JSON', () async {
      final InMemoryProjectStorage storage = InMemoryProjectStorage();
      final ProjectRepository repository = ProjectRepository(storage: storage);
      await repository.save(
        repository.create(name: 'x', pattern: samplePattern()),
      );
      final String text = storage.files.values.single;
      expect(text, contains('\n  "schemaVersion": 1'));
      expect(text.endsWith('\n'), isTrue);
    });

    test('按修改时间倒序返回', () async {
      final InMemoryProjectStorage storage = InMemoryProjectStorage();
      final ProjectRepository repository = ProjectRepository(storage: storage);
      final Project base = repository.create(
        name: 'base',
        pattern: samplePattern(),
      );

      final Project old = Project(
        id: 'old',
        name: '旧的',
        pattern: base.pattern,
        progress: base.progress,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      final Project recent = Project(
        id: 'new',
        name: '新的',
        pattern: base.pattern,
        progress: base.progress,
        createdAt: DateTime.utc(2026, 2),
        updatedAt: DateTime.utc(2026, 2),
      );
      // 故意先写新的、再写旧的，验证排序确实按 updatedAt 而不是写入顺序
      await repository.save(recent);
      await repository.save(old);

      final List<Project> loaded = await repository.loadAll();
      expect(loaded.map((Project p) => p.id), <String>['new', 'old']);
    });

    test('坏文件被跳过并上报，好文件照常读出', () async {
      final InMemoryProjectStorage storage = InMemoryProjectStorage();
      final ProjectRepository repository = ProjectRepository(storage: storage);
      await repository.save(
        repository.create(name: '好的', pattern: samplePattern()),
      );
      await storage.write('broken', '{"schemaVersion":1,"id":"broken"}');
      await storage.write('garbage', 'not json at all');

      final List<Object> errors = <Object>[];
      final List<Project> loaded = await repository.loadAll(
        onError: errors.add,
      );

      expect(loaded, hasLength(1));
      expect(loaded.single.name, '好的');
      expect(errors, hasLength(2));
      expect(errors.every((Object e) => e is ModelFormatException), isTrue);
      // 报错信息里要带上是哪个文件，便于使用者自己去看
      expect(
        errors.map((Object e) => '$e').join(' '),
        allOf(contains('broken'), contains('garbage')),
      );
    });

    test('读取超时时返回空列表并上报，不卡住界面', () async {
      final ProjectRepository repository = ProjectRepository(
        storage: NeverRespondingStorage(),
      );
      final List<Object> errors = <Object>[];
      final List<Project> loaded = await repository.loadAll(
        onError: errors.add,
        timeout: const Duration(milliseconds: 30),
      );
      expect(loaded, isEmpty);
      expect(errors.single, isA<TimeoutException>());
    });

    test('写入失败只上报，不抛给界面', () async {
      final ProjectRepository repository = ProjectRepository(
        storage: _FailingStorage(),
      );
      final List<Object> errors = <Object>[];
      final bool ok = await repository.save(
        repository.create(name: 'x', pattern: samplePattern()),
        onError: errors.add,
      );
      expect(ok, isFalse);
      expect(errors.single, isA<FileSystemException>());
    });
  });

  group('删除与修改时间', () {
    test('delete 之后就读不到了', () async {
      final InMemoryProjectStorage storage = InMemoryProjectStorage();
      final ProjectRepository repository = ProjectRepository(storage: storage);
      final Project project = repository.create(
        name: 'x',
        pattern: samplePattern(),
      );
      await repository.save(project);
      expect(await repository.loadAll(), hasLength(1));

      expect(await repository.delete(project.id), isTrue);
      expect(storage.deleteCount, 1);
      expect(await repository.loadAll(), isEmpty);
    });

    test('touch 刷新 updatedAt，但保留 id 与 createdAt', () async {
      final ProjectRepository repository = ProjectRepository(
        storage: InMemoryProjectStorage(),
        clock: () => DateTime.utc(2026, 5),
      );
      final Project created = repository.create(
        name: 'x',
        pattern: samplePattern(),
      );
      expect(created.updatedAt, DateTime.utc(2026, 5));

      final Project touched = repository.touch(created, name: '改名了');
      expect(touched.updatedAt, DateTime.utc(2026, 5));
      expect(touched.createdAt, created.createdAt);
      expect(touched.name, '改名了');
      expect(touched.id, created.id);
    });
  });

  group('FileProjectStorage（真实文件 IO）', () {
    late Directory tempDir;
    late FileProjectStorage storage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('dsh_projects_test');
      storage = FileProjectStorage(directoryProvider: () async => tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('目录不存在时读出空表（首次启动不报错）', () async {
      expect(await storage.readAll(), isEmpty);
    });

    test('写入 → 读取 → 删除', () async {
      await storage.write('p1', '{"hello":"世界"}');
      final Map<String, String> all = await storage.readAll();
      expect(all.keys, <String>['p1']);
      expect(all['p1'], contains('世界'));

      // 文件确实落在 projects/ 子目录里，且是可读的 UTF-8
      final File file = File(
        '${tempDir.path}${Platform.pathSeparator}projects'
        '${Platform.pathSeparator}p1.json',
      );
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), contains('世界'));

      await storage.delete('p1');
      expect(await storage.readAll(), isEmpty);
    });

    test('删除不存在的项目不报错', () async {
      await storage.delete('nope');
      expect(await storage.readAll(), isEmpty);
    });

    test('忽略非 .json 文件与子目录', () async {
      await storage.write('p1', '{}');
      final Directory dir = Directory(
        '${tempDir.path}${Platform.pathSeparator}projects',
      );
      await File('${dir.path}${Platform.pathSeparator}notes.txt')
          .writeAsString('ignore me');
      await Directory('${dir.path}${Platform.pathSeparator}sub.json')
          .create(recursive: true);

      final Map<String, String> all = await storage.readAll();
      expect(all.keys, <String>['p1']);
    });

    test('与仓储串起来：保存后重新构造仓储仍能读回（模拟重启）', () async {
      final ProjectRepository first = ProjectRepository(storage: storage);
      final Project project = first.create(
        name: '重启也要在',
        pattern: samplePattern(),
      )..progress.setPlaced(1, 1, placed: true);
      expect(await first.save(project), isTrue);

      // 换一个仓储实例，等价于重启 App
      final ProjectRepository second = ProjectRepository(storage: storage);
      final List<Project> loaded = await second.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.name, '重启也要在');
      expect(loaded.single.progress.isPlacedDirectly(1, 1), isTrue);
      expect(loaded.single.pattern.colorIndexAt(0, 0), 3);
    });
  });
}

/// 写入必定失败：验证错误被上报而不是抛出。
final class _FailingStorage implements ProjectStorage {
  @override
  Future<Map<String, String>> readAll() async => <String, String>{};

  @override
  Future<void> write(String id, String content) async =>
      throw const FileSystemException('磁盘满了');

  @override
  Future<void> delete(String id) async =>
      throw const FileSystemException('删不掉');
}
