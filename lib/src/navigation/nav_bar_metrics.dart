import '../button/button_metrics.dart';

/// iOS 26.4 navigation bar, measured from SwiftUI's `NavigationStack` on
/// iPhone 17 Pro (`tool/reference/controls.json`).
abstract final class NavBarMetrics {
  /// The bar below the status bar; its items are centred in it.
  static const double barHeight = 46.33;

  /// Space between the screen edge and the leading/trailing items.
  static const double edgeInset = 16;

  /// Bar buttons: 44 pt tall; icon-only items are 51.5 pt wide cells that
  /// merge into one capsule.
  static const GlassButtonMetrics item = GlassButtonMetrics(
    height: 44,
    padding: 14,
    fontSize: 17,
    iconSize: 20,
    iconGap: 6,
    iconOnlyHeight: 44,
    iconOnlyExtraWidth: 7.5,
    cornerRadius: 12,
  );

  /// Inline title.
  static const double titleFontSize = 17;

  /// Large title (bold).
  static const double largeTitleFontSize = 34;

  /// The large title's baseline below the bar at rest.
  static const double largeTitleBaselineBelowBar = 44;

  /// Height of the large-title area below the bar.
  static const double largeTitleHeight = 52;

  /// The large title's leading inset.
  static const double largeTitleInset = 16;

  /// Scroll offset at which the inline title appears (it fades in over
  /// [inlineFade], as on iOS, rather than with the scroll).
  static const double inlineThreshold = 51;

  /// The inline title's fade.
  static const Duration inlineFade = Duration(milliseconds: 200);
}
