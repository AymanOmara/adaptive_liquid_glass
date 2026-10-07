import 'package:flutter/cupertino.dart' show CupertinoDynamicColor;

import 'glass_colors.dart';

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
  static const CupertinoDynamicColor red = GlassColors.systemRed;

  /// iOS 26's blue: the default accent.
  static const CupertinoDynamicColor blue = GlassColors.systemBlue;

  /// iOS 26's orange.
  static const CupertinoDynamicColor orange = GlassColors.systemOrange;

  /// iOS 26's green: a toggle that is on.
  static const CupertinoDynamicColor green = GlassColors.systemGreen;
}
