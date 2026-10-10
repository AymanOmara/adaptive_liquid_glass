/// How a `GlassTabBar` sits on the Material path (Android by default).
///
/// ```dart
/// GlassTabBar(
///   materialStyle: GlassMaterialTabBarStyle.edgeToEdge,
///   ...
/// )
/// ```
enum GlassMaterialTabBarStyle {
  /// Material 3's navigation bar in the glass bar's floating capsule.
  floating,

  /// Material 3's own navigation bar: full width at the bottom edge, with
  /// the bottom safe area inside it. `GlassScaffold` drops its gap under
  /// the bar.
  edgeToEdge,
}
