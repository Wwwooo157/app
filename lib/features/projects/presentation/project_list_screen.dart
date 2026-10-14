import 'package:bead_light_board/core/theme/app_theme.dart';
import 'package:bead_light_board/core/widgets/text_input_dialog.dart';
import 'package:bead_light_board/features/projects/data/project_repository.dart';
import 'package:bead_light_board/features/projects/domain/project.dart';
import 'package:bead_light_board/features/projects/domain/relative_time.dart';
import 'package:flutter/material.dart';

/// 我的图纸：列出已保存的项目，可打开 / 重命名 / 删除。
class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key, this.repository, this.clock});

  /// 项目仓库；测试注入内存实现。
  final ProjectRepository? repository;

  /// 时间来源（便于测试"3 分钟前"这类文案）。
  final DateTime Function()? clock;

  @override
  State<ProjectListScreen> createState() => ProjectListScreenState();
}

/// 公开给测试使用。
class ProjectListScreenState extends State<ProjectListScreen> {
  late final ProjectRepository _repository =
      widget.repository ?? ProjectRepository();
  late final DateTime Function() _clock = widget.clock ?? DateTime.now;

  List<Project> _projects = const <Project>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final List<Object> errors = <Object>[];
    final List<Project> projects = await _repository.loadAll(
      onError: errors.add,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _projects = projects;
      _loading = false;
      if (errors.isNotEmpty) {
        // 坏文件不该让整个列表打不开：照常显示好项目，只提示有文件读不了。
        _error = '有 ${errors.length} 个图纸文件读不出来（已跳过）：${errors.first}';
      }
    });
  }

  void _open(Project project) {
    // 把选中的项目交回给调用方（首页据此进入网格页）。
    Navigator.of(context).pop(project);
  }

  Future<void> _rename(Project project) async {
    final String? name = await TextInputDialog.show(
      context,
      title: '重命名',
      initialValue: project.name,
      labelText: '图纸名称',
    );
    if (name == null || !mounted) {
      return;
    }
    final String trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == project.name) {
      return;
    }
    final bool ok = await _repository.save(
      _repository.touch(project, name: trimmed),
    );
    if (!mounted) {
      return;
    }
    if (!ok) {
      setState(() => _error = '重命名保存失败');
      return;
    }
    await _load();
  }

  Future<void> _delete(Project project) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('删除图纸？'),
        content: Text('「${project.name}」及其拼豆进度将被删除，无法撤回。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _repository.delete(project.id);
    if (!mounted) {
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('我的图纸'),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: <Widget>[
        if (_error != null)
          Container(
            width: double.infinity,
            color: AppColors.surfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.error_outline,
                  color: AppColors.warning,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _projects.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _projects.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int index) =>
                      _buildTile(_projects[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildEmpty() => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.folder_open_outlined,
            size: 56,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 12),
          Text(
            '还没有保存的图纸',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            '从首页导入一张图，或打开网格后点「保存图纸」。',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _buildTile(Project project) {
    final String updated = formatRelativeTime(project.updatedAt, _clock());
    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _open(project),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            project.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (project.isComplete) ...<Widget>[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppColors.accent,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${project.rows} × ${project.cols}'
                      ' · ${project.usedColorCount} 色'
                      '${project.sourceImageName == null ? '' : ' · 来自 ${project.sourceImageName}'}'
                      ' · $updated',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: LinearProgressIndicator(
                            value: project.percent / 100,
                            minHeight: 8,
                            backgroundColor: AppColors.surfaceVariant,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${project.percent}%'
                          '（${project.placedCells}/${project.totalCells}）',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '更多',
                onSelected: (String value) {
                  if (value == 'rename') {
                    _rename(project);
                  } else if (value == 'delete') {
                    _delete(project);
                  }
                },
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'rename',
                        child: Text('重命名'),
                      ),
                      PopupMenuItem<String>(value: 'delete', child: Text('删除')),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
