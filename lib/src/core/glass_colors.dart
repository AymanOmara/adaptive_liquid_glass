import 'dart:ui' show Color;

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

  /// The segmented control's thumb at rest in dark mode (iOS's
  /// systemGray, dark).
  static const Color segmentThumbDark = Color(0xFF636366);

  /// The dimming behind a sheet (black at 12%): light, as iOS 26 keeps
  /// the page visible behind a partial sheet.
  static const Color sheetBarrier = Color(0x1F000000);
}
