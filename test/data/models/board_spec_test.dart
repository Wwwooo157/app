import 'package:bead_light_board/data/models/board_spec.dart';
import 'package:bead_light_board/data/models/json_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BoardSpec.fromJson', () {
    test('解析 29x29 且未确认间距时物理尺寸为 null', () {
      final BoardSpec spec = BoardSpec.fromJson(<String, Object?>{
        'id': 'square_29',
        'name': '29 × 29 标准方板',
        'rows': 29,
        'cols': 29,
      }, path: 'boards[0]');

      expect(spec.id, 'square_29');
      expect(spec.rows, 29);
      expect(spec.cols, 29);
      expect(spec.pegCount, 841);
      expect(spec.isSquare, isTrue);
      expect(spec.pitchMm, isNull);
      expect(spec.physicalWidthMm, isNull);
      expect(spec.physicalHeightMm, isNull);
    });

    test('确认间距后能算出物理边长', () {
      final BoardSpec spec = BoardSpec.fromJson(<String, Object?>{
        'id': 'square_29',
        'name': '29 × 29',
        'rows': 29,
        'cols': 29,
        'pitchMm': 5,
      }, path: 'boards[0]');
      expect(spec.physicalWidthMm, 145);
      expect(spec.physicalHeightMm, 145);
    });

    test('非方板', () {
      final BoardSpec spec = BoardSpec.fromJson(<String, Object?>{
        'id': 'rect',
        'name': '矩形板',
        'rows': 20,
        'cols': 30,
      }, path: 'boards[1]');
      expect(spec.isSquare, isFalse);
      expect(spec.pegCount, 600);
    });

    test('rows/cols 必须为正整数', () {
      for (final Object? bad in <Object?>[0, -3, '29', null, 2.5]) {
        expect(
          () => BoardSpec.fromJson(<String, Object?>{
            'id': 'x',
            'name': 'X',
            'rows': bad,
            'cols': 29,
          }, path: 'boards[0]'),
          throwsA(isA<ModelFormatException>()),
        );
      }
    });

    test('id / name 缺失或为空时报错', () {
      expect(
        () => BoardSpec.fromJson(<String, Object?>{
          'name': 'X',
          'rows': 1,
          'cols': 1,
        }, path: 'boards[0]'),
        throwsA(isA<ModelFormatException>()),
      );
      expect(
        () => BoardSpec.fromJson(<String, Object?>{
          'id': 'x',
          'name': '  ',
          'rows': 1,
          'cols': 1,
        }, path: 'boards[0]'),
        throwsA(isA<ModelFormatException>()),
      );
    });

    test('pitchMm 为 0 或负数时报错', () {
      expect(
        () => BoardSpec.fromJson(<String, Object?>{
          'id': 'x',
          'name': 'X',
          'rows': 1,
          'cols': 1,
          'pitchMm': 0,
        }, path: 'boards[0]'),
        throwsA(isA<ModelFormatException>()),
      );
    });
  });
}
