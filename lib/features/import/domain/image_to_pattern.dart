import 'dart:typed_data';

import 'package:bead_light_board/data/models/bead_pattern.dart';
import 'package:bead_light_board/features/quantize/domain/color_matcher.dart';
import 'package:image/image.dart' as img;

/// 导入失败：带一句能给使用者看的原因。
final class ImportException implements Exception {
  const ImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 透明像素的默认合成底色。
///
/// 用暖白（而不是纯白）：与项目"避免纯白纯黑"的基调一致，
/// 也更接近真实拼豆里"白豆"的观感。
const int kDefaultCompositeBackground = 0xFFE4E2DE;

/// 归一化裁剪区域（0..1，左上角为原点）。
///
/// 刻意不用 `dart:ui` 的 Rect：这样整条流水线不依赖 Flutter，
/// 可以原样丢进 isolate，也便于单测。
final class CropRegion {
  const CropRegion({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// 整图。
  static const CropRegion full = CropRegion(
    left: 0,
    top: 0,
    width: 1,
    height: 1,
  );

  final double left;
  final double top;
  final double width;
  final double height;

  /// 是否在合法范围内（允许浮点误差）。
  bool get isValid =>
      width > 0 &&
      height > 0 &&
      left >= -1e-6 &&
      top >= -1e-6 &&
      left + width <= 1 + 1e-6 &&
      top + height <= 1 + 1e-6;

  /// 换算成像素矩形（已夹到图像范围内，且保证至少 1 像素）。
  ({int x, int y, int width, int height}) toPixelRect(
    int imageWidth,
    int imageHeight,
  ) {
    final int x = (left * imageWidth).round().clamp(0, imageWidth - 1);
    final int y = (top * imageHeight).round().clamp(0, imageHeight - 1);
    final int w = (width * imageWidth).round().clamp(1, imageWidth - x);
    final int h = (height * imageHeight).round().clamp(1, imageHeight - y);
    return (x: x, y: y, width: w, height: h);
  }

  @override
  String toString() =>
      'CropRegion(${left.toStringAsFixed(3)}, ${top.toStringAsFixed(3)}, '
      '${width.toStringAsFixed(3)} x ${height.toStringAsFixed(3)})';
}

/// 一次导入的输入。
final class ImportRequest {
  const ImportRequest({
    required this.sourceBytes,
    required this.paletteArgb,
    required this.paletteId,
    required this.rows,
    required this.cols,
    this.cropRegion,
    this.compositeBackgroundArgb = kDefaultCompositeBackground,
    this.sourceImageName,
  });

  /// 原始图片字节（PNG/JPEG/BMP/WebP 等由 image 包支持）。
  final Uint8List sourceBytes;

  /// 色卡颜色（ARGB，索引即色号索引）。
  final List<int> paletteArgb;

  /// 色卡 id（写进 BeadPattern）。
  final String paletteId;

  final int rows;
  final int cols;

  /// 裁剪区域；null = 整图。
  final CropRegion? cropRegion;

  /// 透明像素合成到的底色。
  final int compositeBackgroundArgb;

  /// 来源图片名（原样带到结果里，保存项目时用作默认名称）。
  final String? sourceImageName;
}

/// 一次导入的结果。
final class ImportOutcome {
  const ImportOutcome({
    required this.pattern,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.cropPixelWidth,
    required this.cropPixelHeight,
    this.sourceImageName,
  });

  final BeadPattern pattern;

  /// 原图像素尺寸。
  final int sourceWidth;
  final int sourceHeight;

  /// 裁剪后的像素尺寸。
  final int cropPixelWidth;
  final int cropPixelHeight;

  /// 来源图片名（透传自 [ImportRequest]）。
  final String? sourceImageName;

  /// 平均每格覆盖多少原图像素（用于界面提示分辨率是否够）。
  double get pixelsPerCell =>
      (cropPixelWidth * cropPixelHeight) / (pattern.rows * pattern.cols);

  /// 分辨率是否偏低（每格不足 2×2 像素，细节会被抹平）。
  bool get isLowResolution => pixelsPerCell < 4;
}

/// 只读图片文件头，拿到像素尺寸（**不解码整张图**，很快）。
///
/// 裁剪界面需要宽高来算布局，但没必要为此把整张图解进内存。
/// 返回 null 表示认不出这个格式。
({int width, int height})? readImageSize(Uint8List bytes) {
  final img.Decoder? decoder = img.findDecoderForData(bytes);
  if (decoder == null) {
    return null;
  }
  final img.DecodeInfo? info = decoder.startDecode(bytes);
  if (info == null) {
    return null;
  }
  return (width: info.width, height: info.height);
}

/// 把图片转成拼豆图纸：解码 → 裁剪 → 面积平均降采样 → 量化到色卡。
///
/// 同步函数，刻意不依赖 Flutter，可原样丢进 isolate 执行
/// （见 [importImageToPatternInIsolate]）。
ImportOutcome importImageToPattern(ImportRequest request) {
  if (request.rows <= 0 || request.cols <= 0) {
    throw ArgumentError(
      'rows/cols 必须大于 0，实际为 ${request.rows} x ${request.cols}',
    );
  }

  final PaletteMatcher matcher = PaletteMatcher.fromArgb(request.paletteArgb);
  if (matcher.isEmpty) {
    throw const ImportException('色卡是空的：请先在 assets/palettes/ 里填入真实色号，量化才有意义。');
  }

  final CropRegion region = request.cropRegion ?? CropRegion.full;
  if (!region.isValid) {
    throw ImportException('裁剪区域无效：$region');
  }

  final img.Image? decoded = img.decodeImage(request.sourceBytes);
  if (decoded == null) {
    throw const ImportException('无法解码这张图片（格式不支持或文件已损坏）。');
  }

  final img.Image source = _cropIfNeeded(decoded, region);
  final Uint8List rgba = source.getBytes(order: img.ChannelOrder.rgba);
  final int sourceWidth = source.width;
  final int sourceHeight = source.height;

  final BeadPattern pattern = BeadPattern.filled(
    rows: request.rows,
    cols: request.cols,
    paletteId: request.paletteId,
  );

  final int bgR = (request.compositeBackgroundArgb >> 16) & 0xFF;
  final int bgG = (request.compositeBackgroundArgb >> 8) & 0xFF;
  final int bgB = request.compositeBackgroundArgb & 0xFF;

  for (int row = 0; row < request.rows; row++) {
    final int y0 = (row * sourceHeight / request.rows).floor();
    final int y1 = _cellEnd(row, sourceHeight, request.rows);
    for (int col = 0; col < request.cols; col++) {
      final int x0 = (col * sourceWidth / request.cols).floor();
      final int x1 = _cellEnd(col, sourceWidth, request.cols);

      int sumR = 0;
      int sumG = 0;
      int sumB = 0;
      int count = 0;

      for (int y = y0; y < y1; y++) {
        int offset = (y * sourceWidth + x0) * 4;
        for (int x = x0; x < x1; x++) {
          final int alpha = rgba[offset + 3];
          if (alpha == 255) {
            sumR += rgba[offset];
            sumG += rgba[offset + 1];
            sumB += rgba[offset + 2];
          } else if (alpha == 0) {
            sumR += bgR;
            sumG += bgG;
            sumB += bgB;
          } else {
            // 半透明：按 alpha 合成到指定底色上。
            final int inverse = 255 - alpha;
            sumR += (rgba[offset] * alpha + bgR * inverse) ~/ 255;
            sumG += (rgba[offset + 1] * alpha + bgG * inverse) ~/ 255;
            sumB += (rgba[offset + 2] * alpha + bgB * inverse) ~/ 255;
          }
          count++;
          offset += 4;
        }
      }

      // count 至少为 1：上面保证了每格至少覆盖 1 个像素。
      final int colorIndex = matcher.matchRgb(
        sumR ~/ count,
        sumG ~/ count,
        sumB ~/ count,
      );
      pattern.setColorIndexAt(row, col, colorIndex);
    }
  }

  return ImportOutcome(
    pattern: pattern,
    sourceWidth: decoded.width,
    sourceHeight: decoded.height,
    cropPixelWidth: sourceWidth,
    cropPixelHeight: sourceHeight,
    sourceImageName: request.sourceImageName,
  );
}

/// 第 [index] 个格子在 [total] 格、[pixels] 像素下的结束边界（不含）。
///
/// 用"向上取整"保证每格至少覆盖 1 个像素，且最后一行/列一定能取到图像末尾。
int _cellEnd(int index, int pixels, int total) {
  final int end = ((index + 1) * pixels / total).ceil();
  return end.clamp(1, pixels);
}

img.Image _cropIfNeeded(img.Image source, CropRegion region) {
  if (region.left == 0 &&
      region.top == 0 &&
      region.width == 1 &&
      region.height == 1) {
    return source;
  }
  final ({int x, int y, int width, int height}) rect = region.toPixelRect(
    source.width,
    source.height,
  );
  return img.copyCrop(
    source,
    x: rect.x,
    y: rect.y,
    width: rect.width,
    height: rect.height,
  );
}
