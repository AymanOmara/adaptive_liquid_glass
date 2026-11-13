/// Measured from SwiftUI's `.listStyle(.plain)` on iOS 26.4 (iPhone 17
/// Pro, 3x screenshots of `PlainListReference` in
/// example/ios/Runner/ListFormScenes.swift, `-listform plain` and
/// `plaindark`) unless a value says estimated. Rows share
/// `ListMetrics`: a 54-pt row, the title 16 pt in (56 pt after a
/// leading), the icon centred 28 pt in.
abstract final class PlainListMetrics {
  /// The space above a section header's text box: the header's 64.33-pt
  /// extent less its [headerHeight] (UIKit's `sectionHeaderTopPadding`).
  static const double headerTopPadding = 21;

  /// The header's text box; the text is centred in it, so its caps sit
  /// 21.67 pt above the first row (the next section's header text centre
  /// is 42.67 pt below the previous row).
  static const double headerHeight = 43.33;

  /// The separator's start inset under a row without a leading; it starts
  /// under the title (56 pt) after one.
  static const double separatorStart = 16;

  /// The separator's end inset: it stops 16 pt before the list's end, as
  /// in the inset-grouped style.
  static const double separatorEnd = 16;

  /// The Material path's header height (Material's list subheader,
  /// estimated).
  static const double materialHeaderHeight = 48;
}
