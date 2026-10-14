import 'package:bead_light_board/features/edit/domain/edit_history.dart';
import 'package:bead_light_board/features/edit/domain/pattern_editor.dart';
import 'package:flutter_test/flutter_test.dart';

CellChange change(int row, int col, int before, int after) =>
    CellChange(row: row, col: col, before: before, after: after);

void main() {
  test('初始状态：不能撤销也不能重做', () {
    final PatternEditHistory history = PatternEditHistory();
    expect(history.canUndo, isFalse);
    expect(history.canRedo, isFalse);
    expect(history.undo(), isNull);
    expect(history.redo(), isNull);
  });

  test('一次笔画 = 一步撤销', () {
    final PatternEditHistory history = PatternEditHistory()
      ..beginBatch()
      ..record(<CellChange>[change(0, 0, 0, 5)])
      ..record(<CellChange>[change(0, 1, 0, 5)])
      ..endBatch();

    expect(history.canUndo, isTrue);
    expect(history.undoDepth, 1);
    final List<CellChange> changes = history.undo()!;
    expect(changes, hasLength(2), reason: '一整笔应当一起撤销');
    expect(history.canUndo, isFalse);
    expect(history.canRedo, isTrue);
  });

  test('没有实际变化的批不入栈（避免"撤销了但什么都没变"）', () {
    final PatternEditHistory history = PatternEditHistory()..beginBatch();
    expect(history.endBatch(), isFalse);
    expect(history.canUndo, isFalse);
  });

  test('单击（未显式开批）也会记一步', () {
    final PatternEditHistory history = PatternEditHistory()
      ..record(<CellChange>[change(1, 1, 0, 3)]);
    expect(history.canUndo, isTrue);
    expect(history.undo()!.single, change(1, 1, 0, 3));
  });

  test('未开批且没有改动时不记录', () {
    final PatternEditHistory history = PatternEditHistory()
      ..record(const <CellChange>[]);
    expect(history.canUndo, isFalse);
  });

  test('重做返回同一批改动', () {
    final PatternEditHistory history = PatternEditHistory()
      ..record(<CellChange>[change(2, 2, 1, 9)]);
    final List<CellChange> undone = history.undo()!;
    final List<CellChange> redone = history.redo()!;
    expect(redone, undone);
    expect(history.canUndo, isTrue);
    expect(history.canRedo, isFalse);
  });

  test('新的改动会作废重做分支（编辑器通行语义）', () {
    final PatternEditHistory history = PatternEditHistory()
      ..record(<CellChange>[change(0, 0, 0, 1)])
      ..undo();
    expect(history.canRedo, isTrue);

    history.record(<CellChange>[change(0, 0, 0, 2)]);
    expect(history.canRedo, isFalse);
    expect(history.undo()!.single.after, 2);
  });

  test('超过 maxDepth 时丢掉最旧的步骤', () {
    final PatternEditHistory history = PatternEditHistory(maxDepth: 3);
    for (int i = 0; i < 5; i++) {
      history.record(<CellChange>[change(0, i, 0, i + 1)]);
    }
    expect(history.undoDepth, 3);
    // 最旧的两次已被丢弃，剩下的是第 3、4、5 步
    expect(history.undo()!.single.col, 4);
    expect(history.undo()!.single.col, 3);
    expect(history.undo()!.single.col, 2);
    expect(history.canUndo, isFalse);
  });

  test('上一批没结束就开新批：先收尾，不丢改动', () {
    final PatternEditHistory history = PatternEditHistory()
      ..beginBatch()
      ..record(<CellChange>[change(0, 0, 0, 1)])
      ..beginBatch() // 隐式收尾上一批
      ..record(<CellChange>[change(1, 1, 0, 1)])
      ..endBatch();

    expect(history.undoDepth, 2);
    expect(history.undo()!.single.row, 1);
    expect(history.undo()!.single.row, 0);
  });

  test('未收尾就撤销：自动收尾后再撤销', () {
    final PatternEditHistory history = PatternEditHistory()
      ..beginBatch()
      ..record(<CellChange>[change(0, 0, 0, 1)]);
    expect(history.isCollecting, isTrue);

    final List<CellChange> changes = history.undo()!;
    expect(changes.single, change(0, 0, 0, 1));
    expect(history.isCollecting, isFalse);
  });

  test('clear 清空一切（切换图纸后使用）', () {
    final PatternEditHistory history = PatternEditHistory()
      ..record(<CellChange>[change(0, 0, 0, 1)])
      ..undo()
      ..clear();
    expect(history.canUndo, isFalse);
    expect(history.canRedo, isFalse);
    expect(history.undoDepth, 0);
  });

  test('撤销顺序：先撤最新的一步；重做顺序与之相反', () {
    final PatternEditHistory history = PatternEditHistory()
      ..record(<CellChange>[change(0, 0, 0, 1)]) // A
      ..record(<CellChange>[change(2, 2, 0, 2)]); // B

    // 先撤销最新的一步 B，再撤销 A
    expect(history.undo()!.single, change(2, 2, 0, 2));
    expect(history.undo()!.single, change(0, 0, 0, 1));
    expect(history.redoDepth, 2);

    // 重做按相反顺序：先回到"做完 A"的状态，再回到"做完 B"
    expect(history.redo()!.single, change(0, 0, 0, 1));
    expect(history.redo()!.single, change(2, 2, 0, 2));
    expect(history.canRedo, isFalse);
    expect(history.canUndo, isTrue);

    // 再撤销一次，仍然是最新的 B
    expect(history.undo()!.single, change(2, 2, 0, 2));
  });
}
