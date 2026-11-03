import 'package:flutter/painting.dart';

import 'glass_button_style.dart';

/// Held-state colours for non-glass buttons, measured on iOS 26.4.
/// Fill and label are composited independently; a whole-button opacity
/// cannot reproduce SwiftUI's highlighted material, especially in dark mode.
abstract final class SystemButtonPress {
  /// Label alpha, applied over the already highlighted fill.
  static double labelOpacity(GlassButtonStyle style, {required bool dark}) =>
      switch (style) {
        GlassButtonStyle.borderless => dark ? 0.4 : 0.2,
        GlassButtonStyle.bordered when dark => 1,
        _ => 0.75,
      };

  /// Dark bordered labels brighten toward white without losing their alpha.
  static double labelWhiteMix(GlassButtonStyle style, {required bool dark}) =>
      dark && style == GlassButtonStyle.bordered ? 0.1 : 0;

  /// The highlighted fill; null retains a background-free style.
  static Color? fill(
    Color? idle,
    GlassButtonStyle style, {
    required bool dark,
    required bool tinted,
  }) {
    if (idle == null) return null;
    if (style == GlassButtonStyle.borderedProminent) {
      return dark
          ? Color.lerp(idle, const Color(0xFFFFFFFF), 0.2)
          : idle.withValues(alpha: idle.a * 0.75);
    }
    return idle.withValues(
      alpha: tinted ? (dark ? 0.35 : 0.12) : (dark ? 0.41 : 0.12),
    );
  }
}
