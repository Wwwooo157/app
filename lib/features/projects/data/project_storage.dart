import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 项目文件读写接口。
///
/// 每个项目一个 JSON 文件，放在应用文档目录的 `projects/` 下。
/// **不维护索引文件**：列表直接从目录扫出来，就少了一份"可能与实际不同步"的状态
/// （索引与实际文件不一致是这类实现最经典的 bug 来源）。
///
/// 抽成接口是为了让单测用内存实现，完全不碰 path_provider 的平台通道
/// （widget test 里没有实现时该通道会永远不回应，见 docs/dev-notes.md）。
abstract interface class ProjectStorage {
  /// 读出所有项目（id → 原始文本）。
  Future<Map<String, String>> readAll();

  /// 写入单个项目（不存在则创建）。
  Future<void> write(String id, String content);

  /// 删除单个项目（不存在时静默返回）。
  Future<void> delete(String id);
}

/// 存到应用私有目录 `projects/<id>.json`。
final class FileProjectStorage implements ProjectStorage {
  FileProjectStorage({
    Future<Directory> Function()? directoryProvider,
    this.folderName = 'projects',
  }) : _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory;

  /// 子目录名（放在应用文档目录下）。
  final String folderName;

  /// 目录来源。默认走 path_provider；测试注入临时目录以脱离平台通道。
  final Future<Directory> Function() _directoryProvider;

  static const String _extension = '.json';

  @override
  Future<Map<String, String>> readAll() async {
    final Directory directory = await _directory();
    if (!await directory.exists()) {
      return <String, String>{};
    }
    final Map<String, String> result = <String, String>{};
    await for (final FileSystemEntity entity in directory.list()) {
      if (entity is! File) {
        continue;
      }
      final String name = entity.path.split(Platform.pathSeparator).last;
      if (!name.endsWith(_extension)) {
        continue;
      }
      result[name.substring(0, name.length - _extension.length)] = await entity
          .readAsString();
    }
    return result;
  }

  @override
  Future<void> write(String id, String content) async {
    final File file = await _file(id);
    await file.parent.create(recursive: true);
    await file.writeAsString(content, flush: true);
  }

  @override
  Future<void> delete(String id) async {
    final File file = await _file(id);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _directory() async {
    final Directory base = await _directoryProvider();
    return Directory('${base.path}${Platform.pathSeparator}$folderName');
  }

  Future<File> _file(String id) async {
    final Directory directory = await _directory();
    return File('${directory.path}${Platform.pathSeparator}$id$_extension');
  }
}

/// 内存实现，仅供测试。
final class InMemoryProjectStorage implements ProjectStorage {
  InMemoryProjectStorage([Map<String, String>? initial])
    : _files = <String, String>{...?initial};

  final Map<String, String> _files;

  /// 已写入 / 已删除的次数（测试用来断言"确实落盘了"）。
  int writeCount = 0;
  int deleteCount = 0;

  @override
  Future<Map<String, String>> readAll() async =>
      Map<String, String>.from(_files);

  @override
  Future<void> write(String id, String content) async {
    _files[id] = content;
    writeCount++;
  }

  @override
  Future<void> delete(String id) async {
    _files.remove(id);
    deleteCount++;
  }

  /// 便于测试断言当前存了什么。
  Map<String, String> get files => Map<String, String>.unmodifiable(_files);
}
