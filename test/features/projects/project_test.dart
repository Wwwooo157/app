import 'dart:convert';
import 'dart:typed_data';

import 'package:bead_light_board/data/models/bead_pattern.dart';
import 'package:bead_light_board/data/models/json_support.dart';
import 'package:bead_light_board/features/guide/domain/beading_progress.dart';
import 'package:bead_light_board/features/projects/domain/project.dart';
import 'package:flutter_test/flutter_test.dart';

/// 4x5 的小图纸，含一个**大于 255 的色号索引**（验证 16 位编码，不是 8 位）。
BeadPattern samplePattern({int rows = 4, int cols = 5}) {
  final BeadPattern pattern =
      BeadPattern.filled(rows: rows, cols: cols, paletteId: 'test_fixture')
        ..setColorIndexAt(0, 0, 3)
        ..setColorIndexAt(rows - 1, cols - 1, 700);
  return pattern;
}

Project sampleProject({
  String name = '心形图纸',
  BeadingProgress? progress,
  String? sourceImageName,
}) {
  final BeadPattern pattern = samplePattern();
  return Project(
    id: 'p1',
    name: name,
    pattern: pattern,
    progress:
        progress ?? BeadingProgress(rows: pattern.rows, cols: pattern.cols),
    createdAt: DateTime.utc(2026, 2, 14, 2),
    updatedAt: DateTime.utc(2026, 2, 14, 3),
    sourceImageName: sourceImageName,
  );
}

void main() {
  group('往返序列化', () {
    test('图纸逐格一致（含 >255 的色号索引）', () {
      final Project original = sampleProject();
      final Project restored = Project.fromJsonText(
        jsonEncode(original.toJson()),
      );

      expect(restored.rows, original.rows);
      expect(restored.cols, original.cols);
      expect(restored.pattern.paletteId, 'test_fixture');
      for (int row = 0; row < original.rows; row++) {
        for (int col = 0; col < original.cols; col++) {
          expect(
            restored.pattern.colorIndexAt(row, col),
            original.pattern.colorIndexAt(row, col),
            reason: '($row, $col)',
          );
        }
      }
      expect(restored.pattern.colorIndexAt(3, 4), 700);
    });

    test('进度一致：逐格标记 + 整色完成', () {
      final BeadingProgress progress = BeadingProgress(rows: 4, cols: 5)
        ..setPlaced(0, 0, placed: true)
        ..setPlaced(2, 3, placed: true)
        ..setColorCompleted(4, completed: true)
        ..setColorCompleted(700, completed: true);

      final Project restored = Project.fromJsonText(
        jsonEncode(sampleProject(progress: progress).toJson()),
      );

      expect(restored.progress.isPlacedDirectly(0, 0), isTrue);
      expect(restored.progress.isPlacedDirectly(2, 3), isTrue);
      expect(restored.progress.isPlacedDirectly(1, 1), isFalse);
      expect(restored.progress.directlyPlacedCount, 2);
      expect(restored.progress.completedColors, <int>{4, 700});
    });

    test('元数据一致（含中文名与来源图名）', () {
      final Project restored = Project.fromJsonText(
        jsonEncode(
          sampleProject(
            name: '小红心 ❤️ 52×52',
            sourceImageName: 'sample_heart.png',
          ).toJson(),
        ),
      );
      expect(restored.id, 'p1');
      expect(restored.name, '小红心 ❤️ 52×52');
      expect(restored.sourceImageName, 'sample_heart.png');
      expect(restored.createdAt, DateTime.utc(2026, 2, 14, 2));
      expect(restored.updatedAt, DateTime.utc(2026, 2, 14, 3));
    });

    test('没有来源图名时不写出该字段，读回为 null', () {
      final Map<String, Object?> json = sampleProject().toJson();
      expect(json.containsKey('sourceImageName'), isFalse);
      expect(Project.fromJsonText(jsonEncode(json)).sourceImageName, isNull);
    });

    test('缩进输出是可读 JSON（人能直接打开看）', () {
      final String text = const JsonEncoder.withIndent('  ')
          .convert(sampleProject().toJson());
      expect(text, contains('\n  "id": "p1"'));
      expect(text, contains('"rows": 4'));
    });
  });

  group('位图编码', () {
    test('小端序显式写出（不依赖平台字节序）', () {
      final BeadPattern pattern = BeadPattern.filled(
        rows: 1,
        cols: 2,
        paletteId: 'x',
      )..setColorIndexAt(0, 0, 0x1234);
      final String encoded = Project.encodeCellIndices(pattern);
      final List<int> bytes = base64Decode(encoded);
      expect(bytes, <int>[0x34, 0x12, 0x00, 0x00]);
    });

    test('解码后长度不符时明确报错', () {
      expect(
        () => Project.decodeCellIndices(
          base64Encode(<int>[1, 2, 3]),
          rows: 2,
          cols: 2,
        ),
        throwsA(
          isA<ModelFormatException>().having(
            (ModelFormatException e) => e.path,
            'path',
            'project.cells',
          ),
        ),
      );
    });

    test('cells 不是合法 base64 时报错', () {
      expect(
        () => Project.decodeCellIndices('!!!not-base64!!!', rows: 1, cols: 1),
        throwsA(isA<ModelFormatException>()),
      );
    });
  });

  group('严格校验：坏数据必须明确失败', () {
    Map<String, Object?> validJson() => sampleProject().toJson();

    test('版本不支持时给出可读原因', () {
      final Map<String, Object?> json = validJson()..['schemaVersion'] = 99;
      expect(
        () => Project.fromJsonText(jsonEncode(json)),
        throwsA(
          isA<ModelFormatException>().having(
            (ModelFormatException e) => e.message,
            'message',
            contains('不支持的版本 99'),
          ),
        ),
      );
    });

    test('缺少必填字段时报错', () {
      for (final String key in <String>[
        'id',
        'name',
        'rows',
        'cols',
        'cells',
        'placed',
        'paletteId',
        'createdAt',
        'updatedAt',
        'completedColors',
      ]) {
        final Map<String, Object?> json = validJson()..remove(key);
        expect(
          () => Project.fromJsonText(jsonEncode(json)),
          throwsA(isA<ModelFormatException>()),
          reason: '缺少 $key 时应当报错',
        );
      }
    });

    test('rows/cols 非正数时报错', () {
      final Map<String, Object?> json = validJson()..['rows'] = 0;
      expect(
        () => Project.fromJsonText(jsonEncode(json)),
        throwsA(isA<ModelFormatException>()),
      );
    });

    test('进度位图长度与 rows×cols 不符时报错（宁可失败也不加载错位进度）', () {
      final Map<String, Object?> json = validJson();
      json['placed'] = base64Encode(<int>[1, 2, 3]); // 应为 20 字节
      expect(
        () => Project.fromJsonText(jsonEncode(json)),
        throwsA(
          isA<ModelFormatException>().having(
            (ModelFormatException e) => e.message,
            'message',
            contains('不匹配'),
          ),
        ),
      );
    });

    test('时间格式非法时报错', () {
      final Map<String, Object?> json = validJson()..['createdAt'] = '昨天';
      expect(
        () => Project.fromJsonText(jsonEncode(json)),
        throwsA(isA<ModelFormatException>()),
      );
    });

    test('completedColors 含非整数时报错', () {
      final Map<String, Object?> json = validJson();
      json['completedColors'] = <Object?>[1, 'red'];
      expect(
        () => Project.fromJsonText(jsonEncode(json)),
        throwsA(isA<ModelFormatException>()),
      );
    });

    test('顶层不是对象时报错', () {
      expect(
        () => Project.fromJsonText('[1,2,3]'),
        throwsA(isA<ModelFormatException>()),
      );
    });
  });

  group('统计与 copyWith', () {
    test('进度百分比按整色完成一并计算', () {
      final BeadPattern pattern = BeadPattern.filled(
        rows: 2,
        cols: 2,
        paletteId: 'x',
      )..setColorIndexAt(0, 0, 1);

      final BeadingProgress progress = BeadingProgress(rows: 2, cols: 2)
        ..setPlaced(0, 0, placed: true);
      final Project project = Project(
        id: 'p',
        name: 'n',
        pattern: pattern,
        progress: progress,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      expect(project.totalCells, 4);
      expect(project.placedCells, 1);
      expect(project.percent, 25);
      expect(project.usedColorCount, 2);
      expect(project.isComplete, isFalse);

      progress
        ..setColorCompleted(0, completed: true)
        ..setColorCompleted(1, completed: true);
      expect(project.placedCells, 4);
      expect(project.percent, 100);
      expect(project.isComplete, isTrue);
      expect(project.completedColorCount, 2);
    });

    test('copyWith 保留 id 与 createdAt，只改指定字段', () {
      final Project original = sampleProject();
      final DateTime later = DateTime.utc(2026, 3);
      final Project updated = original.copyWith(name: '改个名', updatedAt: later);
      expect(updated.id, original.id);
      expect(updated.createdAt, original.createdAt);
      expect(updated.name, '改个名');
      expect(updated.updatedAt, later);
      expect(updated.sourceImageName, original.sourceImageName);
    });
  });

  group('进度位图出入口', () {
    test('toByteMap / fromByteMap 往返一致', () {
      final BeadingProgress original = BeadingProgress(rows: 3, cols: 4)
        ..setPlaced(0, 0, placed: true)
        ..setPlaced(2, 3, placed: true)
        ..setColorCompleted(9, completed: true);

      final BeadingProgress restored = BeadingProgress.fromByteMap(
        rows: 3,
        cols: 4,
        placed: original.toByteMap(),
        completedColors: original.completedColors,
      );

      expect(restored.directlyPlacedCount, 2);
      expect(restored.isPlacedDirectly(0, 0), isTrue);
      expect(restored.isPlacedDirectly(2, 3), isTrue);
      expect(restored.isColorCompleted(9), isTrue);
    });

    test('长度不符时抛 ArgumentError', () {
      expect(
        () =>
            BeadingProgress.fromByteMap(rows: 2, cols: 2, placed: Uint8List(3)),
        throwsArgumentError,
      );
    });

    test('toByteMap 返回副本，改它不影响原进度', () {
      final BeadingProgress progress = BeadingProgress(rows: 2, cols: 2)
        ..setPlaced(0, 0, placed: true);
      final Uint8List bytes = progress.toByteMap()..[0] = 0;
      expect(bytes[0], 0);
      expect(progress.isPlacedDirectly(0, 0), isTrue);
    });
  });
}
