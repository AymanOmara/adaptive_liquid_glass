/// `GlassColorPicker`'s metrics. The row swatch is measured from SwiftUI's
/// `ColorPicker` (iOS 26.4, "components" → "color_row"). The sheet is
/// measured from UIColorPickerViewController, which that row opens
/// (`-controls colorrow`, its swatch tapped; Grid, Spectrum and Sliders
/// pages; "components" → "color_sheet"). Sheet positions are from the
/// sheet's top edge; text slots are derived from the measured ink with SF
/// Pro's metrics. Marked estimated where UIKit gave nothing to measure.
abstract final class ColorPickerMetrics {
  /// The row's swatch diameter (measured).
  static const double rowSwatch = 28;

  /// The row's swatch hue ring thickness (measured).
  static const double rowRing = 3.33;

  /// The gap between the row swatch's ring and its colour (measured).
  static const double rowRingGap = 1.67;

  /// The sheet's height, floating 8 pt in from the screen's sides and
  /// bottom, without a grabber (measured: 265-865 on an 874-pt screen).
  static const double sheetHeight = 600;

  /// The sheet content's inset from the sheet's sides (measured: the
  /// segmented control, grid, rows and separator all sit 15.33 in).
  static const double padding = 15.33;

  /// The header's height; the title and the close button are centred in
  /// it (measured: title ink centred 26 pt below the sheet's top).
  static const double headerHeight = 52;

  /// The title's text size (semibold; measured: 12.7-pt ink, "Colour").
  static const double titleSize = 17;

  /// The close button's xmark glyph (measured: 16 x 16 pt ink, plain,
  /// no circle behind it).
  static const double closeGlyph = 16;

  /// The close glyph's centre inset from the sheet's end (measured: 26).
  static const double closeInset = 26;

  /// The close button's touch target.
  static const double closeTarget = 44;

  /// The segmented control's top (measured: 53).
  static const double segmentTop = 53;

  /// The page (grid, spectrum or sliders) top (measured: 98.33, the grid's
  /// and the spectrum's top edge).
  static const double pageTop = 98.33;

  /// The page's height (measured: the grid and the spectrum, 296).
  static const double pageHeight = 296;

  /// The gap between the page's bottom and the opacity caption's text
  /// slot (measured: the opacity field's top 39 pt under the page; the
  /// caption's ink then lands within 0.5 pt of UIKit's).
  static const double opacityGap = 18.33;

  /// A caption's (OPACITY, RED...) text size (semibold, upper case;
  /// measured: 9-pt cap height).
  static const double captionSize = 13;

  /// A caption's slot above its slider: from the top of its text to the
  /// slider's top (measured: cap height top 18.67 above the track).
  static const double captionSlot = 21.67;

  /// A channel or opacity slider's track height, also its thumb's
  /// diameter (measured: 32.67).
  static const double trackHeight = 32.67;

  /// The thumb's white ring (measured: 2.67).
  static const double trackThumbRing = 2.67;

  /// The gap between a slider and its value field (measured: 15).
  static const double fieldGap = 15;

  /// A value field's width (measured: 73, "100%" and "255").
  static const double fieldWidth = 73;

  /// The hex field's width (measured: 96).
  static const double hexFieldWidth = 96;

  /// A value field's height (measured: 34.67).
  static const double fieldHeight = 34.67;

  /// A value field's corner radius (measured, about 8).
  static const double fieldRadius = 8;

  /// A value field's text size (measured: 12-pt cap height, "100%").
  static const double fieldTextSize = 17;

  /// The pitch of the Sliders page's red, green and blue rows (measured:
  /// tracks 73.5 apart).
  static const double channelPitch = 73.5;

  /// The first channel caption's slot below the page's top (measured:
  /// cap height 4.33 below it).
  static const double channelTop = 1.13;

  /// The hex row's field top below the page's top (measured: 234).
  static const double hexTop = 234;

  /// The gap between the separator and the opacity field's bottom
  /// (measured: separator 21 pt below it).
  static const double separatorGap = 21;

  /// The gap between the separator and the colour swatch (measured: 21).
  static const double swatchGap = 21;

  /// The gap under the current colour's swatch (measured: 14.67 to the
  /// sheet's bottom edge).
  static const double bottomPadding = 14.67;

  /// The opacity block's height (caption, slider row and the gap above
  /// them): the sheet is this much shorter without opacity.
  static const double opacityBlock =
      opacityGap + captionSlot - (fieldHeight - trackHeight) / 2 + fieldHeight;

  /// The current colour's swatch (measured: 75 x 75).
  static const double swatch = 75;

  /// The swatch's corner radius (measured, about 10).
  static const double swatchRadius = 10;

  /// The preset grid's column count (measured).
  static const int gridColumns = 12;

  /// The preset grid's row count (measured: a grey row and nine hue rows).
  static const int gridRows = 10;

  /// The gap between grid swatches (measured: none, the swatches touch;
  /// 29.8 x 29.6 pt each on iPhone 17 Pro).
  static const double gridGap = 0;

  /// The grid's outer corner radius (measured, continuous corners).
  static const double gridRadius = 8;

  /// The selected grid swatch's ring thickness (estimated).
  static const double gridSelectionRing = 2;

  /// The spectrum and hue bar's corner radius (estimated, as the grid's).
  static const double spectrumRadius = 8;

  /// The hue bar's height (estimated: UIKit's spectrum is one hue by
  /// brightness map without a bar; this one keeps a saturation-value
  /// square and a hue bar within the measured page).
  static const double hueBarHeight = 24;

  /// The gap between the spectrum square and the hue bar (estimated).
  static const double hueBarGap = 12;

  /// The spectrum square's height: the page less the hue bar.
  static const double spectrumHeight = pageHeight - hueBarGap - hueBarHeight;

  /// The spectrum and hue bar thumb's diameter (estimated).
  static const double thumb = 24;

  /// The thumb's ring thickness (measured: 2.67, as the sliders').
  static const double thumbRing = trackThumbRing;

  /// The hue step a screen reader's increase or decrease moves by, in
  /// degrees (estimated).
  static const double hueStep = 10;

  /// The step a screen reader's increase or decrease moves a channel or
  /// the opacity by, as a fraction (estimated).
  static const double channelStep = 0.05;

  /// The checkerboard's cell size under a translucent colour (measured:
  /// three cells across the opacity track).
  static const double checker = trackHeight / 3;

  /// The checkerboard's cell size under a translucent row swatch
  /// (estimated).
  static const double rowChecker = 6;

  /// The selection ring's animation: none. UIColorPickerViewController's
  /// grid (iOS 26.4) swaps the ring between two display frames (measured,
  /// two takes, no in-between frame).
  static const Duration selectionDuration = Duration.zero;
}
