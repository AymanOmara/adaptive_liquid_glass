import 'package:flutter/painting.dart' show FontWeight;

/// Measured from SwiftUI iOS 26.4 (iPhone 17 Pro, 3x screenshots of
/// `ListReference` in example/ios/Runner/ControlScenes.swift) unless a
/// value says estimated.
abstract final class ListMetrics {
  /// The platter's corner radius.
  static const double cornerRadius = 26;

  /// The platter's inset from the screen's sides.
  static const double margin = 16;

  /// A row's start inset without a leading, and the end inset of a row
  /// ending in text.
  static const double horizontalPadding = 16;

  /// A row's least height.
  static const double minRowHeight = 54;

  /// The row content's vertical inset (estimated).
  static const double verticalPadding = 11;

  /// The leading slot's width; the slot keeps the row's height.
  static const double leadingWidth = 28;

  /// The leading slot's start inset, so an icon's centre is 28 from the
  /// platter's edge.
  static const double leadingStart = 14;

  /// The gap between the leading slot and the text.
  static const double leadingGap = 14;

  /// Where the title starts when a row has a leading.
  static const double textStart = leadingStart + leadingWidth + leadingGap;

  /// The leading icon's size (measured against SF Symbols at body size;
  /// CupertinoIcons glyphs differ slightly).
  static const double iconSize = 26;

  /// The gap between the value, the trailing and the chevron (estimated).
  static const double trailingGap = 6;

  /// The gap between the title and the subtitle (estimated).
  static const double subtitleGap = 2;

  /// The title's text size.
  static const double titleSize = 17;

  /// The subtitle's text size (estimated).
  static const double subtitleSize = 15;

  /// The value's text size.
  static const double valueSize = 17;

  /// The chevron glyph's width.
  static const double chevronWidth = 7;

  /// The chevron glyph's height.
  static const double chevronHeight = 12;

  /// The chevron's stroke width.
  static const double chevronStroke = 2.2;

  /// The chevron's end edge to the platter's end.
  static const double chevronEnd = 18.33;

  /// The trailing control's end inset; SwiftUI's Toggle ends this far
  /// before the platter's end.
  static const double controlEnd = 14;

  /// The hairline separator's thickness (3 device pixels at 3x).
  static const double separatorThickness = 1;

  /// The separator's end inset; it stops this far before the platter's
  /// end.
  static const double separatorEnd = 16;

  /// The header's text size.
  static const double headerSize = 17;

  /// The header's font weight; inset-grouped headers are semibold,
  /// sentence case.
  static const FontWeight headerWeight = FontWeight.w600;

  /// The footer's text size.
  static const double footerSize = 13;

  /// The header's gap to the platter.
  static const double headerGap = 11.83;

  /// The platter's gap to the footer.
  static const double footerGap = 10.33;

  /// The Material path's gap around the header and footer (estimated).
  static const double materialGap = 8;

  /// The Material path's content inset (estimated).
  static const double materialInset = 16;

  /// The Material path's separator indent after a leading (estimated).
  static const double materialLeadingInset = 72;
}
