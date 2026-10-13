/// Press and fill values for the button styles without glass
/// (`.bordered`, `.borderedProminent`, `.borderless`, `.plain`). Their
/// geometry comes from `GlassButtonMetrics`: iOS 26 gives bordered and
/// glass buttons the same heights and padding per control size. The values
/// here, and that shared geometry, are ESTIMATED from SwiftUI on iOS 26,
/// not measured.
abstract final class SystemButtonMetrics {
  /// Opacity of the whole button while pressed (as `CupertinoButton`).
  static const double pressedOpacity = 0.4;

  /// Fade into the pressed opacity.
  static const Duration pressIn = Duration(milliseconds: 120);

  /// Fade back out of it on release.
  static const Duration pressOut = Duration(milliseconds: 180);

  /// Alpha of a tinted or destructive `.bordered` fill in light mode.
  static const double tintedFillOpacityLight = 0.15;

  /// Alpha of a tinted or destructive `.bordered` fill in dark mode.
  static const double tintedFillOpacityDark = 0.2;
}
