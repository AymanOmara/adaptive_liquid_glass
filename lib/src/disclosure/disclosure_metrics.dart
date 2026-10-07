/// iOS 26's disclosure group. Positions are measured from SwiftUI's
/// `DisclosureGroup` in an inset-grouped `List` (iOS 26.4, iPhone 17 Pro
/// at 3x; `tool/reference/side_by_side.sh disclosure`); the glyph's
/// stroke and the spring are estimated.
abstract final class DisclosureMetrics {
  /// The chevron glyph's width, collapsed (measured: 7).
  static const double chevronWidth = 7;

  /// The chevron glyph's height, collapsed (measured: 12).
  static const double chevronHeight = 12;

  /// The chevron's stroke width (estimated).
  static const double chevronStroke = 2.2;

  /// The collapsed chevron's end edge to the platter's end (measured:
  /// 16.67).
  static const double chevronEnd = 16.67;

  /// The rotation's pivot, from the glyph's start edge (measured: the
  /// expanded glyph centres 1.17 pt nearer the start than the collapsed
  /// one).
  static const double chevronPivotStart = 2.33;

  /// How far the chevron turns when expanded, in turns: a quarter turn
  /// from pointing toward the end to pointing down.
  static const double expandedTurns = 0.25;

  /// How far the children's rows sit toward the end of the label row's
  /// (measured: titles at 52 against the group's 32).
  static const double childIndent = 20;

  /// The expand/collapse spring's response, in seconds (estimated).
  static const double springResponse = 0.35;

  /// The expand/collapse spring's damping fraction (estimated).
  static const double springDamping = 1.0;
}
