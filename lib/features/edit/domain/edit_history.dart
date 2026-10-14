import 'package:bead_light_board/features/edit/domain/pattern_editor.dart';

/// 一批改动（一次笔画 / 一次填充 = 一步撤销）。
final class EditBatch {
  EditBatch(this.changes);

  final List<CellChange> changes;

  bool get isEmpty => changes.isEmpty;
}

/// 撤销/重做栈。
///
/// 只存**稀疏差异**（哪些格从什么色变成什么色），不存整图快照：
/// 52×52 一次填充最多 2704 个改动，也不过几十 KB；而整图快照每步就是 5KB 起。
///
/// 这个类**不碰图纸**：`undo()` / `redo()` 只返回"该写回哪些格"，
/// 由调用方决定何时应用 —— 于是它可以完全脱离 Flutter 单测。
final class PatternEditHistory {
  PatternEditHistory({this.maxDepth = 100});

  /// 最多保留多少步（超出后丢最旧的）。
  final int maxDepth;

  final List<EditBatch> _undoStack = <EditBatch>[];
  final List<EditBatch> _redoStack = <EditBatch>[];

  /// 正在收集的一批改动。
  List<CellChange>? _pending;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// 已记录的步数（测试用）。
  int get undoDepth => _undoStack.length;
  int get redoDepth => _redoStack.length;

  /// 是否正在收集一批改动。
  bool get isCollecting => _pending != null;

  /// 开始收集一批改动（一次笔画 / 一次填充）。
  void beginBatch() {
    // 上一批没结束就又开始：先把上一批收尾，避免丢掉真实改动。
    if (_pending != null) {
      endBatch();
    }
    _pending = <CellChange>[];
  }

  /// 记录一批里的改动（应在 [beginBatch] 与 [endBatch] 之间调用）。
  void record(Iterable<CellChange> changes) {
    final List<CellChange>? pending = _pending;
    if (pending == null) {
      // 没显式开批（例如单击落笔）：自己开一批并立刻收尾。
      final List<CellChange> single = changes.toList(growable: false);
      if (single.isNotEmpty) {
        _push(EditBatch(single));
      }
      return;
    }
    pending.addAll(changes);
  }

  /// 结束当前批。返回是否真的记下了一步（全无变化则丢弃）。
  bool endBatch() {
    final List<CellChange>? pending = _pending;
    _pending = null;
    if (pending == null || pending.isEmpty) {
      return false;
    }
    _push(EditBatch(pending));
    return true;
  }

  /// 撤销一步：返回需要写回 **before** 的改动；没有可撤销时返回 null。
  List<CellChange>? undo() {
    if (_pending != null) {
      endBatch();
    }
    if (_undoStack.isEmpty) {
      return null;
    }
    final EditBatch batch = _undoStack.removeLast();
    _redoStack.add(batch);
    return batch.changes;
  }

  /// 重做一步：返回需要写回 **after** 的改动；没有可重做时返回 null。
  List<CellChange>? redo() {
    if (_redoStack.isEmpty) {
      return null;
    }
    final EditBatch batch = _redoStack.removeLast();
    _undoStack.add(batch);
    return batch.changes;
  }

  /// 清空历史（例如切换图纸后）。
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    _pending = null;
  }

  void _push(EditBatch batch) {
    _undoStack.add(batch);
    // 新的改动会作废"重做"分支 —— 这是编辑器的通行语义
    _redoStack.clear();
    while (_undoStack.length > maxDepth) {
      _undoStack.removeAt(0);
    }
  }

  @override
  String toString() =>
      'PatternEditHistory(可撤销=${_undoStack.length}, 可重做=${_redoStack.length})';
}
