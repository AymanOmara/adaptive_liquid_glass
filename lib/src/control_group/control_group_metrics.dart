import '../button/glass_button_metrics.dart';

/// iOS 26's `ControlGroup` geometry. The item size is the toolbar's grouped
/// item (measured, `ToolbarMetrics.grouped`); the divider values are
/// ESTIMATED from the stepper's measured divider, not measured.
abstract final class ControlGroupMetrics {
  /// The capsule's height.
  static const double height = 44;

  /// A divider's thickness.
  static const double dividerWidth = 1;

  /// A divider's height.
  static const double dividerHeight = 24;

  /// Metrics for each button in the group: icon-only, half the 107.67-pt
  /// two-item capsule wide.
  static const GlassButtonMetrics item = GlassButtonMetrics(
    height: height,
    padding: 14,
    fontSize: 17,
    iconSize: 24,
    iconGap: 6,
    iconOnlyHeight: height,
    iconOnlyExtraWidth: 107.67 / 2 - height,
    cornerRadius: 12,
  );
}
