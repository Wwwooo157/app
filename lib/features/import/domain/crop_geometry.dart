import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:bead_light_board/features/import/domain/image_to_pattern.dart';

/// 自绘裁剪的几何计算（零依赖，纯函数，可完整单测）。
///
/// 坐标约定：
/// - **取景框坐标**：原点在取景框左上角，尺寸 [frameSize]。
/// - **图片显示坐标**：图片按 "cover" 铺满取景框后的基准尺寸是
///   [baseDisplaySize]，再乘 [scale]、偏移 [offset]。
/// - 输出的 [normalizedCropRegion] 是相对**原图**的 0..1 区域。
final class CropGeometry {
  const CropGeometry({
    required this.frameSize,
    required this.imageWidth,
    required this.imageHeight,
    this.scale = 1,
    this.offset = Offset.zero,
  });

  /// 取景框尺寸（一般是一个矩形，比例 = cols/rows）。
  final Size frameSize;

  /// 原图像素尺寸。
  final int imageWidth;
  final int imageHeight;

  /// 额外缩放（1 = 恰好 cover）。
  final double scale;

  /// 图片相对"cover 居中"位置的位移（取景框坐标）。
  final Offset offset;

  /// 允许的缩放范围。
  static const double minScale = 1;
  static const double maxScale = 8;

  /// "cover" 基准尺寸：恰好盖满取景框、保持原图纵横比。
  Size get baseDisplaySize {
    if (imageWidth <= 0 || imageHeight <= 0 || frameSize.isEmpty) {
      return Size.zero;
    }
    final double imageAspect = imageWidth / imageHeight;
    final double frameAspect = frameSize.width / frameSize.height;
    if (imageAspect > frameAspect) {
      // 图更宽：以高度为准
      return Size(frameSize.height * imageAspect, frameSize.height);
    }
    return Size(frameSize.width, frameSize.width / imageAspect);
  }

  /// 当前实际显示尺寸。
  Size get displaySize {
    final Size base = baseDisplaySize;
    return Size(base.width * scale, base.height * scale);
  }

  /// 让图片始终盖满取景框：夹住缩放与位移。
  ///
  /// 位移是相对"cover 居中"的偏移，所以合法区间**关于 0 对称**：
  /// 图片边缘最多刚好贴到取景框对边。
  CropGeometry clamped() {
    final double safeScale = scale.clamp(minScale, maxScale);
    final Size base = baseDisplaySize;
    final Size shown = Size(base.width * safeScale, base.height * safeScale);
    final double limitX = math.max(0, (shown.width - frameSize.width) / 2);
    final double limitY = math.max(0, (shown.height - frameSize.height) / 2);
    return CropGeometry(
      frameSize: frameSize,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      scale: safeScale,
      offset: Offset(
        offset.dx.clamp(-limitX, limitX),
        offset.dy.clamp(-limitY, limitY),
      ),
    );
  }

  /// 图片左上角在取景框坐标里的位置。
  Offset get topLeft {
    final Size shown = displaySize;
    return Offset(
      (frameSize.width - shown.width) / 2 + offset.dx,
      (frameSize.height - shown.height) / 2 + offset.dy,
    );
  }

  /// 归一化后的裁剪区域（相对原图）。
  ///
  /// 取景框 [0, frameSize] 映射回原图坐标，再除以原图尺寸。
  CropRegion get normalizedCropRegion {
    final Size shown = displaySize;
    if (shown.isEmpty) {
      return CropRegion.full;
    }
    final Offset origin = topLeft;
    final double left = (0 - origin.dx) / shown.width;
    final double top = (0 - origin.dy) / shown.height;
    final double width = frameSize.width / shown.width;
    final double height = frameSize.height / shown.height;
    return CropRegion(
      left: left.clamp(0, 1),
      top: top.clamp(0, 1),
      width: width.clamp(0, 1),
      height: height.clamp(0, 1),
    );
  }

  /// 取景框对应的原图像素区域（用于界面提示"这一块会被压成 N 格"）。
  Rect get sourcePixelRect {
    final CropRegion region = normalizedCropRegion;
    return Rect.fromLTWH(
      region.left * imageWidth,
      region.top * imageHeight,
      region.width * imageWidth,
      region.height * imageHeight,
    );
  }

  /// 把一次缩放手势应用进来（保持 [focalPoint] 处的图像内容不动）。
  CropGeometry zoomed(double factor, Offset focalPoint) {
    final double nextScale = (scale * factor).clamp(minScale, maxScale);
    final double applied = nextScale / scale;

    // 焦点相对图片中心的位置，会随缩放一起被"推开"
    final Offset origin = topLeft;
    final Offset focusInImage = focalPoint - origin;
    final Offset nextOrigin = focalPoint - focusInImage * applied;

    final Size base = baseDisplaySize;
    final Size shown = Size(base.width * nextScale, base.height * nextScale);
    final Offset centered = Offset(
      (frameSize.width - shown.width) / 2,
      (frameSize.height - shown.height) / 2,
    );

    return CropGeometry(
      frameSize: frameSize,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      scale: nextScale,
      offset: nextOrigin - centered,
    ).clamped();
  }

  /// 平移。
  CropGeometry panned(Offset delta) => CropGeometry(
    frameSize: frameSize,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    scale: scale,
    offset: offset + delta,
  ).clamped();

  @override
  String toString() =>
      'CropGeometry(scale=${scale.toStringAsFixed(2)}, offset=$offset, '
      'crop=$normalizedCropRegion)';
}
