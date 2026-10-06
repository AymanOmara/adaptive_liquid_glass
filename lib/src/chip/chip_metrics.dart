/// iOS has no native chip, so the capsule is sized like iOS 26's small
/// glass buttons. The values are ESTIMATED from iOS 26 (UIKit/HIG
/// defaults), not measured.
abstract final class ChipMetrics {
  /// The chip's height.
  static const double height = 32;

  /// The label's inset from the start, and from the end without a delete
  /// button.
  static const double horizontalPadding = 12;

  /// The end padding when a delete button is shown; the delete glyph's own
  /// padding makes up the rest.
  static const double deletePadding = 6;

  /// The label's text size.
  static const double labelSize = 15;

  /// The leading icon's size.
  static const double iconSize = 16;

  /// The gap between the icon and the label.
  static const double iconGap = 6;

  /// The delete glyph's size.
  static const double deleteSize = 16;

  /// Padding around the delete glyph, widening its touch target.
  static const double deleteHitPadding = 4;
}
