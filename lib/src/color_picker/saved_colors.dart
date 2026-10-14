import 'package:flutter/widgets.dart';

/// The colour picker sheet's saved colours when the app keeps none of its
/// own: one list in memory, shared by every `GlassColorPicker` (as UIKit
/// shares its saved colours between pickers) until the app quits.
abstract final class SavedColors {
  /// UIColorPickerViewController's saved colours on a fresh iOS 26.4
  /// simulator (measured): black, blue, green, yellow, red.
  static const List<Color> defaults = [
    Color(0xFF000000),
    Color(0xFF0161FD),
    Color(0xFF32C759),
    Color(0xFFFFCC02),
    Color(0xFFFF3A30),
  ];

  /// The shared list.
  static final ValueNotifier<List<Color>> shared = ValueNotifier(defaults);

  /// Restores [defaults], for tests.
  @visibleForTesting
  static void debugReset() => shared.value = defaults;
}
