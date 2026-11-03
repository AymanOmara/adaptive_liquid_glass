import 'package:flutter/animation.dart';

import 'glass_button_metrics.dart';
import 'glass_button_style.dart';
import 'glass_control_size.dart';

/// Layout, press and fill values for the styles without glass.
/// GeometryReader measurements in system_button_geometry.json distinguish
/// actual layout padding from the ink-edge padding of the glass reference.
/// Fill and press measurements are in system_buttons.json and
/// system_button_press.json (all SwiftUI, iOS 26.4).
abstract final class SystemButtonMetrics {
  /// Default metrics for a non-glass style at [size]. Explicit metrics scopes
  /// still override these. SwiftUI's plain style ignores control size.
  static GlassButtonMetrics forSize(
    GlassControlSize size, {
    required GlassButtonStyle style,
  }) {
    final base = glassButtonMetrics(
      style == GlassButtonStyle.plain ? GlassControlSize.regular : size,
    );
    final bordered =
        style == GlassButtonStyle.bordered ||
        style == GlassButtonStyle.borderedProminent;
    final padding = !bordered
        ? 0.0
        : switch (size) {
            GlassControlSize.mini || GlassControlSize.small => 10.0,
            GlassControlSize.regular => 12.0,
            GlassControlSize.large || GlassControlSize.extraLarge => 20.0,
          };
    return GlassButtonMetrics(
      height: base.height,
      padding: padding,
      fontSize: base.fontSize,
      iconSize: base.iconSize,
      iconGap: base.iconGap,
      iconOnlyHeight: base.iconOnlyHeight,
      iconOnlyExtraWidth: base.iconOnlyExtraWidth,
      cornerRadius: base.cornerRadius,
    );
  }

  /// SwiftUI reaches its held appearance in one display frame.
  static const Duration pressIn = Duration.zero;

  /// Release duration fitted to lossless 60 Hz SwiftUI recordings.
  static const Duration pressOut = Duration(milliseconds: 420);

  /// Release fit: plain-label RMS error 0.6/255 on the reference take.
  static const Curve releaseCurve = Cubic(0.328, 0.425, 0.324, 0.937);

  /// Alpha of an explicitly tinted `.bordered` fill in light mode.
  static const double tintedFillOpacityLight = 0.18;

  /// Alpha of an explicitly tinted `.bordered` fill in dark mode.
  static const double tintedFillOpacityDark = 0.25;
}
