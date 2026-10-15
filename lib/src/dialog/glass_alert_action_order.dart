/// How [showGlassAlert] orders its actions.
enum GlassAlertActionOrder {
  /// In the order given, on both paths.
  given,

  /// Where each platform puts a [GlassButtonRole.cancel] action, the
  /// others kept in their order: iOS leads with it when two buttons sit
  /// side by side and ends with it when they stack; Material puts it
  /// first, the dismissive action before the confirming ones.
  platform,
}
