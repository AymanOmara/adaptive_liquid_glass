import '../button/glass_button_metrics.dart';

/// iOS 26's bottom toolbar, measured from SwiftUI on iPhone 17 Pro / iOS
/// 26.4 (`tool/reference/controls.json`, "components" → "toolbar"; tested
/// against it).
abstract final class ToolbarMetrics {
  /// The capsules' height.
  static const double height = 48;

  /// The capsules' inset from the screen's sides.
  static const double edgeInset = 28;

  /// The capsules' bottom edge above the screen's (with a home indicator).
  static const double bottom = 28;

  /// A lone item: a 48-pt circle.
  static const GlassButtonMetrics single = GlassButtonMetrics(
    height: height,
    padding: 14,
    fontSize: 17,
    // CupertinoIcons glyphs are padded: 26 gives SF's 21-pt toolbar ink.
    iconSize: 26,
    iconGap: 6,
    iconOnlyHeight: height,
    iconOnlyExtraWidth: 0,
    cornerRadius: 12,
  );

  /// An item in a group: two items make a 107.67-pt capsule.
  static const GlassButtonMetrics grouped = GlassButtonMetrics(
    height: height,
    padding: 14,
    fontSize: 17,
    iconSize: 26,
    iconGap: 6,
    iconOnlyHeight: height,
    iconOnlyExtraWidth: 107.67 / 2 - height,
    cornerRadius: 12,
  );
}
