/// A column of a [GlassSplitView] (SwiftUI `NavigationSplitViewColumn`).
enum GlassSplitViewColumn {
  /// The leading sidebar.
  sidebar,

  /// The middle column of a three-column view.
  content,

  /// The detail, the last column.
  detail,
}

/// Which columns a regular-width [GlassSplitView] shows (SwiftUI
/// `NavigationSplitViewVisibility`).
enum GlassSplitViewVisibility {
  /// Every column the width allows; the default.
  automatic,

  /// Every column.
  all,

  /// The detail and the column before it: content with detail in a
  /// three-column view; the sidebar stays in a two-column one.
  doubleColumn,

  /// The detail only.
  detailOnly,
}
