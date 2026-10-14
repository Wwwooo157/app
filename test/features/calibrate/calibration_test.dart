import 'package:bead_light_board/data/models/json_support.dart';
import 'package:bead_light_board/features/calibrate/domain/calibration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('默认值就是严格物理 1:1', () {
    test('默认：scale=1、原点、未锁定', () {
      final Calibration calibration = Calibration.defaults(pitchMm: 5);
      expect(calibration.pitchMm, 5);
      expect(calibration.scaleFactor, 1);
      expect(calibration.origin, Offset.zero);
      expect(calibration.locked, isFalse);
      expect(calibration.isStrictlyOneToOne, isTrue);
      expect(calibration.isAdjusted, isFalse);
    });

    test('平移或缩放之后都算"已调整"', () {
      final Calibration base = Calibration.defaults(pitchMm: 5);
      expect(base.copyWith(origin: const Offset(1, 0)).isAdjusted, isTrue);
      expect(
        base.copyWith(origin: const Offset(1, 0)).isStrictlyOneToOne,
        isTrue,
      );
      expect(base.copyWith(scaleFactor: 1.0001).isStrictlyOneToOne, isFalse);
    });

    test('缩放容差内的极小差异仍视为严格 1:1', () {
      final Calibration base = Calibration.defaults(pitchMm: 5);
      expect(
        base
            .copyWith(scaleFactor: 1 + Calibration.scaleEpsilon / 2)
            .isStrictlyOneToOne,
        isTrue,
      );
    });
  });

  group('JSON 往返', () {
    test('导出再导入内容一致', () {
      const Calibration original = Calibration(
        pitchMm: 5,
        scaleFactor: 1.0042,
        origin: Offset(-18.5, -115.25),
        locked: true,
      );
      final Calibration roundTrip = Calibration.fromJson(original.toJson());

      expect(roundTrip.pitchMm, closeTo(original.pitchMm, 1e-9));
      expect(roundTrip.scaleFactor, closeTo(original.scaleFactor, 1e-9));
      expect(roundTrip.origin.dx, closeTo(original.origin.dx, 1e-9));
      expect(roundTrip.origin.dy, closeTo(original.origin.dy, 1e-9));
      expect(roundTrip.locked, isTrue);
    });

    test('fromJsonText 可解析文本', () {
      final Calibration calibration = Calibration.fromJsonText('''
{
  "schemaVersion": 1,
  "pitchMm": 5,
  "scaleFactor": 1,
  "originDx": 0,
  "originDy": 0,
  "locked": false
}
''');
      expect(calibration.isStrictlyOneToOne, isTrue);
      expect(calibration.origin, Offset.zero);
    });
  });

  group('校验', () {
    void expectPath(String json, String path) {
      expect(
        () => Calibration.fromJsonText(json),
        throwsA(
          isA<ModelFormatException>().having(
            (ModelFormatException e) => e.path,
            'path',
            path,
          ),
        ),
      );
    }

    const String valid =
        '{"schemaVersion":1,"pitchMm":5,"scaleFactor":1,'
        '"originDx":0,"originDy":0,"locked":false}';

    test('schemaVersion 缺失/类型错/版本不符', () {
      expectPath(
        '{"pitchMm":5,"scaleFactor":1,"originDx":0,"originDy":0,"locked":false}',
        'schemaVersion',
      );
      expectPath(
        '{"schemaVersion":"1","pitchMm":5,"scaleFactor":1,'
            '"originDx":0,"originDy":0,"locked":false}',
        'schemaVersion',
      );
      expectPath(
        '{"schemaVersion":9,"pitchMm":5,"scaleFactor":1,'
            '"originDx":0,"originDy":0,"locked":false}',
        'schemaVersion',
      );
    });

    test('pitchMm 必须为正的有限数', () {
      expectPath(
        '{"schemaVersion":1,"pitchMm":0,"scaleFactor":1,'
            '"originDx":0,"originDy":0,"locked":false}',
        'pitchMm',
      );
      expectPath(
        '{"schemaVersion":1,"pitchMm":"5","scaleFactor":1,'
            '"originDx":0,"originDy":0,"locked":false}',
        'pitchMm',
      );
    });

    test('scaleFactor 超出 0.5~2.0 直接拒绝（更像数据坏了而不是微调）', () {
      for (final String bad in <String>['0.4', '2.5', '-1', '0']) {
        expectPath(
          '{"schemaVersion":1,"pitchMm":5,"scaleFactor":$bad,'
              '"originDx":0,"originDy":0,"locked":false}',
          'scaleFactor',
        );
      }
      // 边界值可用
      expect(
        Calibration.fromJsonText(
          '{"schemaVersion":1,"pitchMm":5,"scaleFactor":0.5,'
          '"originDx":0,"originDy":0,"locked":false}',
        ).scaleFactor,
        0.5,
      );
    });

    test('origin 必须是有限数字', () {
      expectPath(
        '{"schemaVersion":1,"pitchMm":5,"scaleFactor":1,'
            '"originDy":0,"locked":false}',
        'originDx',
      );
      expectPath(
        '{"schemaVersion":1,"pitchMm":5,"scaleFactor":1,'
            '"originDx":0,"originDy":"x","locked":false}',
        'originDy',
      );
    });

    test('locked 必须是布尔值', () {
      expectPath(
        '{"schemaVersion":1,"pitchMm":5,"scaleFactor":1,'
            '"originDx":0,"originDy":0,"locked":"yes"}',
        'locked',
      );
      expectPath(
        '{"schemaVersion":1,"pitchMm":5,"scaleFactor":1,'
            '"originDx":0,"originDy":0}',
        'locked',
      );
    });

    test('合法样例可解析', () {
      expect(Calibration.fromJsonText(valid).locked, isFalse);
    });
  });
}
