import 'dart:io';

import 'package:bead_light_board/features/calibrate/data/calibration_storage.dart';
import 'package:bead_light_board/features/calibrate/domain/calibration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Calibration fallback = Calibration.defaults(pitchMm: 5);

  group('CalibrationRepository（内存存储）', () {
    test('没有保存过时返回 fallback', () async {
      final CalibrationRepository repository = CalibrationRepository(
        storage: InMemoryCalibrationStorage(),
      );
      final Calibration loaded = await repository.load(fallback: fallback);
      expect(loaded.isStrictlyOneToOne, isTrue);
      expect(loaded.origin, Offset.zero);
    });

    test('保存再读取内容一致，且是格式化过的 JSON（方便人看/改）', () async {
      final InMemoryCalibrationStorage storage = InMemoryCalibrationStorage();
      final CalibrationRepository repository = CalibrationRepository(
        storage: storage,
      );

      const Calibration value = Calibration(
        pitchMm: 5,
        scaleFactor: 1.0042,
        origin: Offset(-18.5, -115.25),
        locked: true,
      );
      expect(await repository.save(value), isTrue);
      expect(storage.writeCount, 1);

      final Calibration loaded = await repository.load(fallback: fallback);
      expect(loaded.scaleFactor, closeTo(1.0042, 1e-9));
      expect(loaded.origin.dx, closeTo(-18.5, 1e-9));
      expect(loaded.origin.dy, closeTo(-115.25, 1e-9));
      expect(loaded.locked, isTrue);

      final String? raw = await storage.read();
      expect(raw, isNotNull);
      expect(raw!, contains('"scaleFactor": 1.0042'));
      expect(raw, contains('\n  "locked": true'));
    });

    test('坏数据不致命：回退到 fallback 并上报错误', () async {
      final CalibrationRepository repository = CalibrationRepository(
        storage: InMemoryCalibrationStorage('{"schemaVersion":1,"pitchMm":0}'),
      );

      Object? reported;
      final Calibration loaded = await repository.load(
        fallback: fallback,
        onError: (Object error) => reported = error,
      );

      expect(loaded.isStrictlyOneToOne, isTrue);
      expect(reported, isNotNull);
    });

    test('文件为空/纯空白时视为未保存', () async {
      final CalibrationRepository repository = CalibrationRepository(
        storage: InMemoryCalibrationStorage('   \n'),
      );
      final Calibration loaded = await repository.load(fallback: fallback);
      expect(loaded.origin, Offset.zero);
    });
  });

  group('FileCalibrationStorage（真实文件）', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('dsh_calib_test');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('写入后能读回；文件不存在时返回 null', () async {
      final FileCalibrationStorage storage = FileCalibrationStorage(
        directoryProvider: () async => tempDir,
      );

      expect(await storage.read(), isNull);

      const String content = '{"hello":"world"}';
      await storage.write(content);
      expect(await storage.read(), content);

      // 确实落了盘
      final File file = File(
        '${tempDir.path}${Platform.pathSeparator}calibration.json',
      );
      expect(file.existsSync(), isTrue);
    });

    test('整个仓库走真实文件也能往返', () async {
      final CalibrationRepository repository = CalibrationRepository(
        storage: FileCalibrationStorage(directoryProvider: () async => tempDir),
      );
      const Calibration value = Calibration(
        pitchMm: 5,
        scaleFactor: 1,
        origin: Offset(3.5, -7.25),
        locked: false,
      );
      expect(await repository.save(value), isTrue);

      final Calibration loaded = await repository.load(fallback: fallback);
      expect(loaded.origin.dx, closeTo(3.5, 1e-9));
      expect(loaded.origin.dy, closeTo(-7.25, 1e-9));
      expect(loaded.isStrictlyOneToOne, isTrue);
    });
  });
}
