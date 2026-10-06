import 'package:flutter/cupertino.dart' show Color, CupertinoDynamicColor;

/// The package's fixed colours. Fitted glass colours live in
/// `GlassConstants`; system colours that adapt to the theme come from
/// `CupertinoColors`.
abstract final class GlassColors {
  /// Opaque white: highlights, prominent labels, the lens fill.
  static const Color white = Color(0xFFFFFFFF);

  /// Opaque black, used as a full mask.
  static const Color black = Color(0xFF000000);

  /// Fully transparent.
  static const Color transparent = Color(0x00000000);

  /// Nearly transparent black: keeps a layer the size of its box without
  /// showing.
  static const Color invisible = Color(0x01000000);

  /// Label on glass over a light background: black at 85%, as iOS's
  /// vibrant primary label.
  static const Color labelOnLight = Color(0xD9000000);

  /// Label on glass over a dark background.
  static const Color labelOnDark = white;

  /// The Reduce Transparency fill in dark mode (iOS's
  /// secondarySystemGroupedBackground, dark).
  static const Color opaqueDark = Color(0xFF1C1C1E);

  /// The Reduce Transparency fill in light mode (iOS's
  /// systemGroupedBackground, light).
  static const Color opaqueLight = Color(0xFFF2F2F7);

  /// The dark tab bar's fill while a lens is held (Kept over black): more
  /// see-through and brightened like the lens backdrop. Away from the lens
  /// the bar reads about 34 instead of 25 (BarGlow lights it near the lens),
  /// and the page behind it gains contrast.
  static const Color tabBarPressedFill = Color(0xFF5C5C5C);

  /// The dark tab bar's fill while the lens is dragged: evenly lit, about
  /// 45 over black (Kept).
  static const Color tabBarDraggedFill = Color(0xFF7A7A7A);

  /// A control thumb's shadow at rest (black at 12%).
  static const Color thumbShadow = Color(0x1F000000);

  /// A control thumb at rest.
  static const Color thumb = white;

  // Measured from SwiftUI, iOS 26.4 (tool/reference/controls.json).

  /// The toggle's track while off.
  static const CupertinoDynamicColor toggleOff =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFC5C5C7),
        darkColor: Color(0xFF464649),
      );

  /// The slider's filled track: iOS 26's default accent.
  static const CupertinoDynamicColor sliderFill =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF0088FF),
        darkColor: Color(0xFF0091FF),
      );

  /// The slider's unfilled track.
  static const CupertinoDynamicColor sliderRest =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFE6E6E6),
        darkColor: Color(0xFF191919),
      );

  /// The segmented control's track.
  static const CupertinoDynamicColor segmentTrack =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFEEEEEF),
        darkColor: Color(0xFF1C1C1F),
      );

  /// The segmented control's thumb at rest.
  static const CupertinoDynamicColor segmentThumb =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFFFFFFF),
        darkColor: Color(0xFF5A5A5F),
      );

  /// The dimming behind a sheet: black at 20% (measured: a mid-grey page
  /// goes from 128 to 102).
  static const Color sheetBarrier = Color(0x33000000);

  // iOS 26's system palette. Flutter's `CupertinoColors` still has the
  // iOS 18 values (red #FF3B30, blue #007AFF, orange #FF9500). Light values
  // measured from SwiftUI on iOS 26.4; dark values from Apple's iOS 26
  // palette (the measured dark blue agrees).

  /// iOS 26's red: destructive actions, badges.
  static const CupertinoDynamicColor systemRed =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFFF383C),
        darkColor: Color(0xFFFF4245),
      );

  /// iOS 26's blue: the default accent.
  static const CupertinoDynamicColor systemBlue = sliderFill;

  /// iOS 26's orange.
  static const CupertinoDynamicColor systemOrange =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFFF8D28),
        darkColor: Color(0xFFFF9230),
      );

  /// iOS 26's green: a toggle that is on.
  static const CupertinoDynamicColor systemGreen =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF34C759),
        darkColor: Color(0xFF30D158),
      );
}
