import 'package:flutter/cupertino.dart'
    show Color, CupertinoColors, CupertinoDynamicColor;

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

  /// `Glass.smoke`'s tint: black at 35%, darkening regular glass into a
  /// smoked pane without hiding what is behind it.
  static const Color smokeTint = Color(0x59000000);

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

  /// A dialog button's capsule on the glass: black at 12% (measured: the
  /// card's 211 becomes 186).
  static const Color dialogButtonFill = Color(0x1F000000);

  /// The shadow under an alert or confirmation dialog: black at 17%
  /// (measured on white: 234 at the card's edge, fading over ~120 pt).
  static const Color dialogShadow = Color(0x2B000000);

  /// The stepper's capsule (measured).
  static const CupertinoDynamicColor stepperFill =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFEEEEEF),
        darkColor: Color(0xFF121213),
      );

  /// The stepper's divider (measured).
  static const CupertinoDynamicColor stepperDivider =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFB9B9BC),
        darkColor: Color(0xFF535356),
      );

  // Menu

  /// The row under a gliding finger in a glass menu (estimated, not
  /// measured: iOS's highlight is a translucent label-colour fill).
  static const CupertinoDynamicColor menuHighlight =
      CupertinoDynamicColor.withBrightness(
        color: Color(0x1F000000),
        darkColor: Color(0x29FFFFFF),
      );

  // Focus ring

  /// The keyboard focus ring around focused glass controls: the system
  /// accent (iOS's default blue).
  static const CupertinoDynamicColor focusRing = CupertinoColors.activeBlue;

  // List

  /// A list row while pressed (estimated: iOS's systemGray4).
  static const CupertinoDynamicColor listRowPressed =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFD1D1D6),
        darkColor: Color(0xFF3A3A3C),
      );

  /// A list row's leading icon: iOS 26's default accent (measured light;
  /// dark as the slider's measured accent).
  static const CupertinoDynamicColor listIcon =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF0088FF),
        darkColor: Color(0xFF0091FF),
      );

  /// A list row's value text (measured light: black at 50% on the white
  /// cell; dark estimated).
  static const CupertinoDynamicColor listValue =
      CupertinoDynamicColor.withBrightness(
        color: Color(0x80000000),
        darkColor: Color(0x80FFFFFF),
      );

  /// The hairline between list rows (measured light; dark estimated).
  static const CupertinoDynamicColor listSeparator =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFE8E8E8),
        darkColor: Color(0xFF38383A),
      );

  /// A list section's opaque cell when the glass is off (iOS's
  /// secondarySystemGroupedBackground).
  static const CupertinoDynamicColor listSectionBackground =
      CupertinoColors.secondarySystemGroupedBackground;

  /// CupertinoTheme's default primary colour. A list row's icon uses
  /// [listIcon] while the theme keeps this default.
  static const CupertinoDynamicColor listDefaultAccent =
      CupertinoColors.activeBlue;

  // Tab bar (measured from SwiftUI TabView, iOS 26.4, over white / black)

  /// The selected tab's icon and label (reads 0,126,245 on the white bar
  /// and 27,172,255 on the black one).
  static const CupertinoDynamicColor tabBarSelected =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF007EF5),
        darkColor: Color(0xFF1BACFF),
      );

  /// Unselected tabs (black at 90% / white at 95%: 25 on the light bar,
  /// 243 on the dark one).
  static const CupertinoDynamicColor tabBarLabel =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xE6000000),
        darkColor: Color(0xF2FFFFFF),
      );

  /// The pill behind the selected tab at rest (black at 7% / white at
  /// 14.5%: 235 on the light bar, 53 on the dark one).
  static const CupertinoDynamicColor tabBarPill =
      CupertinoDynamicColor.withBrightness(
        color: Color(0x12000000),
        darkColor: Color(0x25FFFFFF),
      );

  /// The tab bar's shadow in shader mode, at full strength (BarShadow
  /// scales it by TabBarMetrics.shadowOpacity).
  static const Color tabBarShadow = Color(0xFF000000);

  // System colours (iOS 26; public as GlassSystemColors)

  /// iOS 26's red: destructive actions, badges (measured light; dark from
  /// Apple's iOS 26 palette).
  static const CupertinoDynamicColor systemRed =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFFF383C),
        darkColor: Color(0xFFFF4245),
      );

  /// iOS 26's blue: the default accent (measured light and dark).
  static const CupertinoDynamicColor systemBlue =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF0088FF),
        darkColor: Color(0xFF0091FF),
      );

  /// iOS 26's orange (measured light; dark from Apple's palette).
  static const CupertinoDynamicColor systemOrange =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFFF8D28),
        darkColor: Color(0xFFFF9230),
      );

  /// iOS 26's green: a toggle that is on (measured light; dark from
  /// Apple's palette).
  static const CupertinoDynamicColor systemGreen =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF34C759),
        darkColor: Color(0xFF30D158),
      );

  // Text (iOS's semantic label colours, shared by components)

  /// Primary text: titles, values, glyphs.
  static const CupertinoDynamicColor label = CupertinoColors.label;

  /// Secondary text: subtitles, footers, placeholders' icons.
  static const CupertinoDynamicColor secondaryLabel =
      CupertinoColors.secondaryLabel;

  /// Tertiary text: disabled content, placeholders.
  static const CupertinoDynamicColor tertiaryLabel =
      CupertinoColors.tertiaryLabel;

  // Sheet

  /// A sheet's opaque surface when the glass is off (iOS's
  /// systemBackground).
  static const CupertinoDynamicColor sheetBackground =
      CupertinoColors.systemBackground;

  // Full-screen cover

  /// A full-screen cover's default page colour (iOS's systemBackground).
  static const CupertinoDynamicColor fullScreenCoverBackground =
      CupertinoColors.systemBackground;

  // Text field

  /// A text field's error message (iOS's systemRed).
  static const CupertinoDynamicColor textFieldError = CupertinoColors.systemRed;

  // Swipe actions

  /// The platter revealed behind a swiped row (SwiftUI: #E5E5EA in light
  /// mode, iOS's systemGrey5).
  static const CupertinoDynamicColor swipePlatter = CupertinoColors.systemGrey5;

  /// A swipe action's fill when it sets no colour (iOS's systemGrey).
  static const CupertinoDynamicColor swipeActionDefault =
      CupertinoColors.systemGrey;

  // Progress

  /// A progress indicator's unfilled track (iOS's tertiarySystemFill).
  static const CupertinoDynamicColor progressTrack =
      CupertinoColors.tertiarySystemFill;

  // Gauge

  /// A gauge's unfilled track (iOS's tertiarySystemFill).
  static const CupertinoDynamicColor gaugeTrack =
      CupertinoColors.tertiarySystemFill;

  // Toast

  /// A toast's action button text (iOS's systemBlue).
  static const CupertinoDynamicColor toastAction = CupertinoColors.systemBlue;
}
