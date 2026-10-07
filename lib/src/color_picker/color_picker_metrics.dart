/// `GlassColorPicker`'s metrics. Nothing here is measured from SwiftUI's
/// `ColorPicker` yet: every value is estimated from iOS 26's colour picker
/// sheet as it appears on screen.
abstract final class ColorPickerMetrics {
  /// The row's swatch diameter (estimated).
  static const double rowSwatch = 28;

  /// The row's swatch ring thickness (estimated).
  static const double rowRing = 1.5;

  /// The sheet content's inset from the sheet's edges (estimated).
  static const double padding = 20;

  /// The gap between the sheet's sections (estimated).
  static const double sectionGap = 20;

  /// The gap between a section's title and its content (estimated).
  static const double titleGap = 8;

  /// A section title's text size (semibold; estimated).
  static const double titleSize = 15;

  /// The preset grid's column count (estimated: iOS 26 shows 12).
  static const int gridColumns = 12;

  /// The preset grid's row count (estimated: iOS 26 shows 10; a grey row
  /// and five hue rows keep the sheet short).
  static const int gridRows = 6;

  /// The gap between grid swatches (estimated).
  static const double gridGap = 2;

  /// The grid's corner radius (estimated).
  static const double gridRadius = 8;

  /// The selected grid swatch's ring thickness (estimated).
  static const double gridSelectionRing = 2;

  /// The spectrum square's height (estimated).
  static const double spectrumHeight = 180;

  /// The spectrum and hue bar's corner radius (estimated).
  static const double spectrumRadius = 10;

  /// The hue bar's height (estimated).
  static const double hueBarHeight = 24;

  /// The gap between the spectrum square and the hue bar (estimated).
  static const double hueBarGap = 12;

  /// The spectrum and hue bar thumb's diameter (estimated).
  static const double thumb = 24;

  /// The thumb's ring thickness (estimated).
  static const double thumbRing = 3;

  /// The hue step a screen reader's increase or decrease moves by, in
  /// degrees (estimated).
  static const double hueStep = 10;

  /// The width of the label before a slider or the hex field (estimated).
  static const double labelWidth = 72;

  /// The gap between a label and its control (estimated).
  static const double labelGap = 12;

  /// A row label's text size (estimated).
  static const double labelSize = 17;

  /// The hex field's width (estimated).
  static const double hexWidth = 150;

  /// The checkerboard's cell size under a translucent swatch (estimated).
  static const double checker = 6;

  /// The selection ring's animation (estimated).
  static const Duration selectionDuration = Duration(milliseconds: 150);
}
