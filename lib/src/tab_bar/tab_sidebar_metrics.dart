/// The sidebar-adaptable tab bar's geometry, measured from SwiftUI's
/// `TabView` with `.tabViewStyle(.sidebarAdaptable)` on iPad Pro 11-inch /
/// iOS 26.4 (`-controls tabbarsidebar`).
abstract final class TabSidebarMetrics {
  /// From this width on, the bar moves to the top (a regular size class).
  static const double regularWidth = 700;

  /// The top bar's distance from the screen's top.
  static const double topBarTop = 10;

  /// The top bar's height.
  static const double topBarHeight = 46;

  /// The selected tab's pill inset inside the top bar.
  static const double topBarInset = 4;

  /// The slot of the sidebar button after the top bar's start inset.
  static const double toggleSlot = 56;

  /// A text tab's padding on each side of its label.
  static const double tabPadding = 15.2;

  /// The tabs' label size.
  static const double labelSize = 17;

  /// The sidebar button's glyph size.
  static const double toggleSize = 22;

  /// The sidebar's width and its inset from the screen's edges.
  static const double sidebarWidth = 270;

  /// See [sidebarWidth].
  static const double sidebarInset = 10;

  /// The sidebar's corner radius.
  static const double sidebarRadius = 26;

  /// The sidebar button's centre from the sidebar's top and end.
  static const double sidebarToggleTop = 22;

  /// See [sidebarToggleTop].
  static const double sidebarToggleEnd = 36;

  /// The first row's top inside the sidebar.
  static const double rowsTop = 63;

  /// A row's height (rows touch).
  static const double rowHeight = 48;

  /// The selected row's inset from the sidebar's sides.
  static const double rowInset = 16;

  /// A row's icon centre and label start from the sidebar's start.
  static const double rowIconCentre = 43;

  /// See [rowIconCentre].
  static const double rowLabelStart = 70;

  /// A row's icon size.
  static const double rowIconSize = 22;

  /// The page's dimming under the open sidebar (white 255 → 204).
  static const double dim = 0.2;

  /// The selected row's fill, black at this opacity (239 → 210).
  static const double rowFill = 0.12;

  /// The top bar's selected pill, black at this opacity (255 → 235).
  static const double pillFill = 0.08;

  /// The sidebar's open and close duration.
  static const Duration duration = Duration(milliseconds: 350);
}
