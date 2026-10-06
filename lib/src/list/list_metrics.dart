/// iOS 26's inset-grouped list (Settings style). The values are ESTIMATED
/// from iOS 26 (UIKit/HIG defaults), not measured.
abstract final class ListMetrics {
  /// The platter's corner radius.
  static const double cornerRadius = 26;

  /// The platter's inset from the screen's sides.
  static const double margin = 16;

  /// The row content's horizontal inset.
  static const double horizontalPadding = 16;

  /// A row's least height.
  static const double minRowHeight = 44;

  /// The row content's vertical inset.
  static const double verticalPadding = 11;

  /// The leading slot's size (Settings' icon size).
  static const double leadingSize = 29;

  /// The gap between the leading and the text.
  static const double leadingGap = 15;

  /// The separator's inset after a row with a leading.
  static const double textStart = horizontalPadding + leadingSize + leadingGap;

  /// The gap between the value, the trailing and the chevron.
  static const double trailingGap = 6;

  /// The gap between the title and the subtitle.
  static const double subtitleGap = 2;

  /// The title's text size.
  static const double titleSize = 17;

  /// The subtitle's text size.
  static const double subtitleSize = 15;

  /// The value's text size.
  static const double valueSize = 17;

  /// The chevron's glyph size.
  static const double chevronSize = 17;

  /// The hairline separator's thickness.
  static const double separatorThickness = 0.5;

  /// The header's text size.
  static const double headerSize = 13;

  /// The footer's text size.
  static const double footerSize = 13;

  /// The header's gap to the platter, and the platter's to the footer.
  static const double headerGap = 7;

  /// The Material path's gap around the header and footer.
  static const double materialGap = 8;

  /// The Material path's content inset.
  static const double materialInset = 16;

  /// The Material path's separator indent after a leading.
  static const double materialLeadingInset = 72;
}
