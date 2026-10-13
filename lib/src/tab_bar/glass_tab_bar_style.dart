/// How a [GlassTabBar] lays out on a wide screen (SwiftUI `tabViewStyle`).
enum GlassTabBarStyle {
  /// A floating bar at the bottom on every width.
  automatic,

  /// On a regular width (an iPad), a floating bar of text tabs at the top
  /// with a button that opens a sidebar of the tabs, as iOS 26's
  /// `.sidebarAdaptable`; on a compact width, the bottom bar.
  sidebarAdaptable,
}
