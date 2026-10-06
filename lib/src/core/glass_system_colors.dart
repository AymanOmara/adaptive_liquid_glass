import 'package:flutter/cupertino.dart' show Color, CupertinoDynamicColor;

/// iOS 26's system colours, as SwiftUI draws them.
///
/// Flutter's `CupertinoColors` still has the iOS 18 values (red #FF3B30,
/// blue #007AFF, orange #FF9500). The light values here are measured from
/// SwiftUI on iOS 26.4 (`tool/reference/controls.json`); the dark values
/// are Apple's iOS 26 palette (the measured dark blue agrees).
///
/// ```dart
/// GlassSwipeAction(
///   icon: CupertinoIcons.trash,
///   label: 'Delete',
///   color: GlassSystemColors.red,
///   onPressed: delete,
/// )
/// ```
abstract final class GlassSystemColors {
  /// iOS 26's red: destructive actions, badges.
  static const CupertinoDynamicColor red = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFF383C),
    darkColor: Color(0xFFFF4245),
  );

  /// iOS 26's blue: the default accent.
  static const CupertinoDynamicColor blue =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF0088FF),
        darkColor: Color(0xFF0091FF),
      );

  /// iOS 26's orange.
  static const CupertinoDynamicColor orange =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFFF8D28),
        darkColor: Color(0xFFFF9230),
      );

  /// iOS 26's green: a toggle that is on.
  static const CupertinoDynamicColor green =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF34C759),
        darkColor: Color(0xFF30D158),
      );
}
