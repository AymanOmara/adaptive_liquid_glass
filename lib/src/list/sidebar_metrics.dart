/// The sidebar list's geometry, measured from SwiftUI's
/// `List { Section(isExpanded:) … }.listStyle(.sidebar)` on iPhone 17 Pro
/// / iOS 26.4 (`-listform sidebar` in example/ios/Runner/ListFormScenes.swift)
/// and inside a `NavigationSplitView` sidebar on iPad Pro 11-inch
/// (`-listform sidebarsplit`).
///
/// At compact width the rows sit on inset-grouped platters (see
/// `ListMetrics`); only the headers differ.
abstract final class SidebarMetrics {
  // --- compact (iPhone) -----------------------------------------------

  /// A section header's box: the header text and its chevron centre in
  /// it. The first platter's top sits [headerHeight] + [headerGap] below
  /// the safe top (42.33, as a form's first captioned platter).
  static const double headerHeight = 41.33;

  /// See [headerHeight]: the header's centre sits 21.67 above its platter.
  static const double headerGap = 1;

  /// A platter's bottom to the next section's header box.
  static const double sectionGap = 17.67;

  /// The header's size; it is semibold, in the secondary label colour.
  static const double headerSize = 17;

  /// The header text's start inset from the platter's start.
  static const double headerStart = 16;

  // --- regular (iPad sidebar column) ----------------------------------
  // Measured from the `sidebarsplit` capture to about 1.5 pt.

  /// The first section header's top inside the sidebar column.
  static const double regularTop = 1;

  /// A regular header's box height.
  static const double regularHeaderHeight = 44;

  /// A regular header's text start and chevron end from the column's
  /// sides.
  static const double regularHeaderInset = 24;

  /// The gap below a regular section's last row.
  static const double regularSectionGap = 12;

  /// A regular header's size; it is semibold, in the secondary label
  /// colour, as at compact width.
  static const double regularHeaderSize = 17;

  /// A regular row's height (54 pt row pitch in the capture).
  static const double regularRowHeight = 54;
}
