import 'package:flutter/cupertino.dart';

/// UIKit's scroll indicator, as `GlassScrollIndicators` draws it on the
/// glass paths: a 3-pt rounded bar inset 3 pt from the trailing edge and
/// from both ends, dark in light mode and light in dark mode, fading out
/// shortly after the content stops.
abstract final class ScrollIndicatorMetrics {
  /// The bar's width.
  static const double thickness = 3;

  /// The bar's corner radius (a full capsule).
  static const Radius radius = Radius.circular(thickness / 2);

  /// The gap between the bar and the scrollable's trailing edge.
  static const double crossAxisMargin = 3;

  /// The gap between the bar and the scrollable's top and bottom.
  static const double mainAxisMargin = 3;

  /// The bar's shortest length.
  static const double minLength = 36;

  /// How long the bar stays at full opacity after the content stops.
  ///
  /// Measured on iOS 26.4: `hold_seconds_bounds` in
  /// docs/superpowers/notes/measurements/ios-26.4/scrollindicators*/
  /// summary.json spans 1.0167–1.05 s, and ~1.033 s lies in every capture.
  static const Duration timeToFade = Duration(milliseconds: 1033);

  /// How long the bar takes to fade out.
  static const Duration fadeDuration = Duration(milliseconds: 250);

  /// The bar's color: UIKit's default indicator style.
  static const CupertinoDynamicColor color =
      CupertinoDynamicColor.withBrightness(
        color: Color(0x59000000),
        darkColor: Color(0x80FFFFFF),
      );
}
