import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// 选中的图片。
final class PickedImage {
  const PickedImage({required this.bytes, required this.name});

  final Uint8List bytes;

  /// 原始文件名（仅用于界面显示）。
  final String name;
}

/// 选图服务。
///
/// 抽象成接口是为了在测试里注入假实现 —— widget test 不该触碰平台通道
/// （image_picker 在测试环境没有宿主，调用会挂住）。
abstract interface class ImagePickerService {
  /// 让使用者选一张图；取消时返回 null。
  Future<PickedImage?> pickImage();
}

/// 基于 image_picker 的真实实现。
final class PlatformImagePickerService implements ImagePickerService {
  PlatformImagePickerService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// 选图时就把长边限制在这里。
  ///
  /// 52×52 的图纸，每格 10 个像素也只需要 520px；2048 已经远远够用，
  /// 却能避免把 5000 万像素的原图整张解码进来（省内存、省时间）。
  static const double maxSourceSide = 2048;

  @override
  Future<PickedImage?> pickImage() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxSourceSide,
      maxHeight: maxSourceSide,
    );
    if (file == null) {
      return null;
    }
    return PickedImage(bytes: await file.readAsBytes(), name: file.name);
  }
}
