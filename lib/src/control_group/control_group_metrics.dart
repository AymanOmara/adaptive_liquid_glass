import 'package:flutter/cupertino.dart';

import '../button/glass_button_metrics.dart';

/// iOS 26's `ControlGroup` geometry. The item size is the toolbar's grouped
/// item (measured, `ToolbarMetrics.grouped`); the divider values are
/// ESTIMATED from the stepper's measured divider, not measured.
///
/// Outside a bar SwiftUI draws the group as a smaller grey capsule, not
/// glass (`standalone*`, measured from `-controls gapcontrolgroup` on
/// iOS 26.4, iPhone 17 Pro, light: 32 pt tall, 73.33 pt for two chevrons,
/// 96 pt for bold/italic/underline).
abstract final class ControlGroupMetrics {
  /// The capsule's height.
  static const double height = 44;

  /// A divider's thickness.
  static const double dividerWidth = 1;

  /// A divider's height.
  static const double dividerHeight = 24;

  /// Metrics for each button in the group: icon-only, half the 107.67-pt
  /// two-item capsule wide.
  static const GlassButtonMetrics item = GlassButtonMetrics(
    height: height,
    padding: 14,
    fontSize: 17,
    iconSize: 24,
    iconGap: 6,
    iconOnlyHeight: height,
    iconOnlyExtraWidth: 107.67 / 2 - height,
    cornerRadius: 12,
  );

  /// The standalone capsule's height (measured: 96 px at 3x).
  static const double standaloneHeight = 32;

  /// A standalone member's width. SwiftUI sizes each member to its glyph
  /// plus ~22.4 pt (two chevrons: 36.67 pt each; B/I/U: 32 pt each); a
  /// Flutter icon has no ink width, so this is the mean of the two.
  static const double standaloneItemWidth = 34.33;

  /// A standalone divider's height (ESTIMATED: the measured scene has no
  /// dividers).
  static const double standaloneDividerHeight = 16;

  /// Metrics for each button in a standalone group. Icon size 20 draws the
  /// CupertinoIcons chevron 14.3 pt and bold 9.7 pt wide, the SF Symbols'
  /// measured ink widths.
  static const GlassButtonMetrics standaloneItem = GlassButtonMetrics(
    height: standaloneHeight,
    padding: 11,
    fontSize: 15,
    iconSize: 20,
    iconGap: 5,
    iconOnlyHeight: standaloneHeight,
    iconOnlyExtraWidth: standaloneItemWidth - standaloneHeight,
    cornerRadius: 8,
  );

  /// The standalone capsule's fill: iOS's `systemFill` (measured light:
  /// the backdrop under ~22% of a 122–126 grey; Apple's value is
  /// 120,120,128 at 20%). Dark is Apple's palette, not measured.
  static const CupertinoDynamicColor standaloneFill =
      CupertinoDynamicColor.withBrightness(
        color: Color(0x33787880),
        darkColor: Color(0x5C787880),
      );

  /// The standalone members' glyph colour (measured: 255,255,255 in
  /// light over the scene's gradient).
  static const Color standaloneForeground = Color(0xFFFFFFFF);
}
