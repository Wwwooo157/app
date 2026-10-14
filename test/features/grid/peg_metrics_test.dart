import 'package:bead_light_board/features/grid/domain/peg_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

/// 本机实测值（OPPO Pad OPD2101，`adb shell dumpsys display` 读出）。
/// 这些数字是 1:1 对齐的基准，改动需同步 docs/dev-notes.md。
const double kTabletXdpi = 276.462;
const double kTabletYdpi = 275.525;
const double kTabletDevicePixelRatio = 2.25; // density 360 / 160
const double kTabletScreenWidthMm = 235.2;
const double kTabletScreenHeightMm = 147.5;

void main() {
  group('PegMetrics.fromDeviceDpi', () {
    test('用真实平板参数算出每格像素跨度', () {
      final PegMetrics metrics = PegMetrics.fromDeviceDpi(
        pitchMm: 5,
        xdpi: kTabletXdpi,
        ydpi: kTabletYdpi,
        devicePixelRatio: kTabletDevicePixelRatio,
      );

      // 5mm / 25.4 * 276.462 / 2.25 ≈ 24.19 逻辑像素
      expect(metrics.pxPerPegX, closeTo(24.187, 0.01));
      expect(metrics.pxPerPegY, closeTo(24.105, 0.01));
      expect(metrics.pxPerPeg, closeTo(24.146, 0.01));
      expect(metrics.pitchMm, 5);
    });

    test('x/y 分开保存，吃掉面板的各向异性', () {
      final PegMetrics metrics = PegMetrics.fromDeviceDpi(
        pitchMm: 5,
        xdpi: kTabletXdpi,
        ydpi: kTabletYdpi,
        devicePixelRatio: kTabletDevicePixelRatio,
      );
      expect(metrics.pxPerPegX, isNot(equals(metrics.pxPerPegY)));
      // 差异应当很小（<0.5%），只是修正用
      expect(
        (metrics.pxPerPegX - metrics.pxPerPegY).abs() / metrics.pxPerPegX,
        lessThan(0.005),
      );
    });

    test('非法参数直接拒绝，不产出可疑数据', () {
      expect(
        () => PegMetrics.fromDeviceDpi(
          pitchMm: 0,
          xdpi: kTabletXdpi,
          ydpi: kTabletYdpi,
          devicePixelRatio: 2.25,
        ),
        throwsArgumentError,
      );
      expect(
        () => PegMetrics.fromDeviceDpi(
          pitchMm: 5,
          xdpi: 0,
          ydpi: kTabletYdpi,
          devicePixelRatio: 2.25,
        ),
        throwsArgumentError,
      );
      expect(
        () => PegMetrics.fromDeviceDpi(
          pitchMm: 5,
          xdpi: kTabletXdpi,
          ydpi: kTabletYdpi,
          devicePixelRatio: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('毫米与像素换算', () {
    final PegMetrics metrics = PegMetrics.fromDeviceDpi(
      pitchMm: 5,
      xdpi: kTabletXdpi,
      ydpi: kTabletYdpi,
      devicePixelRatio: kTabletDevicePixelRatio,
    );

    test('10 个钉位 ≈ 50 毫米（真机用尺子量的验收依据）', () {
      final double px = metrics.pxPerPegX * 10;
      expect(metrics.pxToMmX(px), closeTo(50, 0.01));
    });

    test('毫米与像素互为逆运算', () {
      expect(metrics.pxToMmX(metrics.mmToPxX(37.5)), closeTo(37.5, 1e-9));
      expect(metrics.pxToMmY(metrics.mmToPxY(37.5)), closeTo(37.5, 1e-9));
    });

    test('整屏毫米数换算回物理尺寸', () {
      // 2560 物理像素 / 2.25 = 1137.78 逻辑像素
      expect(metrics.pxToMmX(2560 / 2.25), closeTo(kTabletScreenWidthMm, 0.2));
      expect(metrics.pxToMmY(1600 / 2.25), closeTo(kTabletScreenHeightMm, 0.2));
    });
  });

  group('maxPegsAcross', () {
    test('本机屏幕能放下多少钉位（1:1 窗口上限）', () {
      expect(
        PegMetrics.maxPegsAcross(availableMm: kTabletScreenWidthMm, pitchMm: 5),
        47,
      );
      expect(
        PegMetrics.maxPegsAcross(
          availableMm: kTabletScreenHeightMm,
          pitchMm: 5,
        ),
        29,
      );
    });

    test('放不下时返回 0 而不是负数', () {
      expect(PegMetrics.maxPegsAcross(availableMm: 3, pitchMm: 5), 0);
    });

    test('7mm 大步距的可选场景', () {
      expect(PegMetrics.maxPegsAcross(availableMm: 100, pitchMm: 7), 14);
    });
  });

  group('变换', () {
    final PegMetrics base = PegMetrics.fromDeviceDpi(
      pitchMm: 5,
      xdpi: kTabletXdpi,
      ydpi: kTabletYdpi,
      devicePixelRatio: kTabletDevicePixelRatio,
    );

    test('withPitch 只改间距，不改物理 DPI', () {
      final PegMetrics coarser = base.withPitch(2.6);
      expect(coarser.pxPerMmX, base.pxPerMmX);
      expect(coarser.pxPerPegX, closeTo(base.pxPerPegX * 2.6 / 5, 1e-9));
    });

    test('scaled 用于总览模式（缩放后不再 1:1）', () {
      final PegMetrics half = base.scaled(0.5);
      expect(half.pxPerPegX, closeTo(base.pxPerPegX / 2, 1e-9));
    });

    test('scaled 拒绝非法倍率', () {
      expect(() => base.scaled(0), throwsArgumentError);
      expect(() => base.scaled(double.nan), throwsArgumentError);
      expect(() => base.scaled(-1), throwsArgumentError);
    });
  });
}
