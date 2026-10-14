import 'dart:async';
import 'dart:io';

import 'package:bead_light_board/data/models/json_support.dart';
import 'package:bead_light_board/features/calibrate/domain/calibration.dart';
import 'package:path_provider/path_provider.dart';

/// 校准参数的读写接口。
///
/// 抽成接口是为了让单测用内存实现，完全不碰 path_provider 的平台通道
/// （widget test 里没有实现时该通道会永远不回应，见 docs/dev-notes.md）。
abstract interface class CalibrationStorage {
  /// 读原始文本；没有保存过时返回 null。
  Future<String?> read();

  /// 写入原始文本。
  Future<void> write(String content);
}

/// 存到应用私有目录下的一个 JSON 文件。
final class FileCalibrationStorage implements CalibrationStorage {
  FileCalibrationStorage({
    this.fileName = 'calibration.json',
    Future<Directory> Function()? directoryProvider,
  }) : _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory;

  /// 文件名（放在应用文档目录下）。
  final String fileName;

  /// 目录来源。默认走 path_provider；测试注入临时目录以脱离平台通道。
  final Future<Directory> Function() _directoryProvider;

  @override
  Future<String?> read() async {
    final File file = await _file();
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  @override
  Future<void> write(String content) async {
    final File file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(content, flush: true);
  }

  Future<File> _file() async {
    final Directory directory = await _directoryProvider();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }
}

/// 内存实现，仅供测试。
final class InMemoryCalibrationStorage implements CalibrationStorage {
  InMemoryCalibrationStorage([this._content]);

  String? _content;

  /// 已写入的次数（测试用来断言"确实保存了"）。
  int writeCount = 0;

  @override
  Future<String?> read() async => _content;

  @override
  Future<void> write(String content) async {
    _content = content;
    writeCount++;
  }
}

/// 校准仓库：负责序列化与容错。
final class CalibrationRepository {
  CalibrationRepository({CalibrationStorage? storage})
    : _storage = storage ?? FileCalibrationStorage();

  final CalibrationStorage _storage;

  /// 读取校准参数。
  ///
  /// **坏数据不致命**：文件缺失/损坏/字段非法时回退到 [fallback] 并通过
  /// [onError] 上报，绝不让 App 因为一个配置文件打不开。
  Future<Calibration> load({
    required Calibration fallback,
    void Function(Object error)? onError,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final String? text;
    try {
      // 超时兜底：平台通道没有实现时（例如桌面/测试环境下的 path_provider）
      // 可能永远不回应，不能让界面无限停在"未加载"状态。
      text = await _storage.read().timeout(timeout);
    } on TimeoutException {
      onError?.call(TimeoutException('读取校准参数超时（${timeout.inSeconds}s）'));
      return fallback;
    }
    if (text == null || text.trim().isEmpty) {
      return fallback;
    }
    try {
      return Calibration.fromJsonText(text);
    } catch (error) {
      onError?.call(error);
      return fallback;
    }
  }

  /// 保存校准参数。写失败时通过 [onError] 上报，不抛给界面。
  Future<bool> save(
    Calibration calibration, {
    void Function(Object error)? onError,
  }) async {
    try {
      await _storage.write(_encode(calibration));
      return true;
    } catch (error) {
      onError?.call(error);
      return false;
    }
  }

  String _encode(Calibration calibration) {
    final Map<String, Object?> json = calibration.toJson();
    return '${_pretty(json)}\n';
  }

  /// 手写一个稳定的缩进输出，便于使用者直接打开文件看/改。
  String _pretty(Map<String, Object?> json) {
    final StringBuffer buffer = StringBuffer('{\n');
    final List<String> keys = json.keys.toList();
    for (int i = 0; i < keys.length; i++) {
      final String key = keys[i];
      final Object? value = json[key];
      buffer.write('  "$key": ');
      if (value is String) {
        buffer.write('"$value"');
      } else {
        buffer.write('$value');
      }
      buffer.write(i == keys.length - 1 ? '\n' : ',\n');
    }
    buffer.write('}');
    return buffer.toString();
  }

  /// 便于测试构造：从 JSON 文本直接解析（等价于 load 的解析部分）。
  static Calibration parse(String text) => Calibration.fromJsonText(text);

  /// 便于测试与调试：把错误转成一行可读文本。
  static String describeError(Object error) =>
      error is ModelFormatException ? error.toString() : error.toString();
}
