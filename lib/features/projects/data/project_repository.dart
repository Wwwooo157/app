import 'dart:async';
import 'dart:convert';

import 'package:bead_light_board/data/models/bead_pattern.dart';
import 'package:bead_light_board/data/models/json_support.dart';
import 'package:bead_light_board/features/guide/domain/beading_progress.dart';
import 'package:bead_light_board/features/projects/data/project_storage.dart';
import 'package:bead_light_board/features/projects/domain/project.dart';

/// 项目仓库：负责序列化、容错与"新建/保存/删除"。
final class ProjectRepository {
  ProjectRepository({ProjectStorage? storage, DateTime Function()? clock})
    : _storage = storage ?? FileProjectStorage(),
      _clock = clock ?? DateTime.now;

  final ProjectStorage _storage;
  final DateTime Function() _clock;

  /// 同一时刻连续新建两个项目时的区分后缀。
  int _created = 0;

  /// 读出全部项目（按修改时间倒序）。
  ///
  /// **单个项目坏掉不影响其他项目**：这是"文件即数据库"必须有的容错 ——
  /// 一个文件被改坏，不该让整个项目列表打不开。
  Future<List<Project>> loadAll({
    void Function(Object error)? onError,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final Map<String, String> raw;
    try {
      // 超时兜底：平台通道没有实现时（桌面/测试环境）可能永远不回应。
      raw = await _storage.readAll().timeout(timeout);
    } on TimeoutException {
      onError?.call(TimeoutException('读取项目列表超时（${timeout.inSeconds}s）'));
      return <Project>[];
    } catch (error) {
      onError?.call(error);
      return <Project>[];
    }

    final List<Project> projects = <Project>[];
    for (final MapEntry<String, String> entry in raw.entries) {
      try {
        projects.add(Project.fromJsonText(entry.value));
      } catch (error) {
        onError?.call(ModelFormatException('projects.${entry.key}', '$error'));
      }
    }
    projects.sort((Project a, Project b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  /// 保存（写失败只上报，不抛给界面）。
  Future<bool> save(
    Project project, {
    void Function(Object error)? onError,
  }) async {
    try {
      await _storage.write(project.id, encode(project));
      return true;
    } catch (error) {
      onError?.call(error);
      return false;
    }
  }

  /// 删除。
  Future<bool> delete(String id, {void Function(Object error)? onError}) async {
    try {
      await _storage.delete(id);
      return true;
    } catch (error) {
      onError?.call(error);
      return false;
    }
  }

  /// 新建项目（生成 id 与时间戳）。
  Project create({
    required String name,
    required BeadPattern pattern,
    BeadingProgress? progress,
    String? sourceImageName,
  }) {
    final DateTime now = _clock();
    final String trimmed = name.trim();
    return Project(
      id: 'p${now.microsecondsSinceEpoch}_${(_created++).toRadixString(36)}',
      name: trimmed.isEmpty ? '未命名图纸' : trimmed,
      pattern: pattern,
      progress:
          progress ?? BeadingProgress(rows: pattern.rows, cols: pattern.cols),
      createdAt: now,
      updatedAt: now,
      sourceImageName: sourceImageName,
    );
  }

  /// 记录一次修改（刷新 updatedAt），供"进度变了要保存"使用。
  Project touch(Project project, {BeadingProgress? progress, String? name}) =>
      project.copyWith(progress: progress, name: name, updatedAt: _clock());

  /// 编码成人类可读的缩进 JSON（方便直接打开文件看/改）。
  static String encode(Project project) =>
      '${const JsonEncoder.withIndent('  ').convert(project.toJson())}\n';
}
