import 'glass_button.dart' show GlassControlSize;

/// Layout of a glass button at one control size, measured from SwiftUI's
/// `.buttonStyle(.glass)` on iOS 26.4 (`tool/reference/controls.json`).
/// iOS 26 has three distinct glass sizes: mini is small, extraLarge is
/// large.
class GlassButtonMetrics {
  /// Creates metrics.
  const GlassButtonMetrics({
    required this.height,
    required this.padding,
    required this.fontSize,
    required this.iconSize,
    required this.iconGap,
    required this.iconOnlyHeight,
    this.iconOnlyExtraWidth = 12,
    required this.cornerRadius,
  });

  /// Height of a button with a label.
  final double height;

  /// Horizontal space between the glass edge and the label.
  final double padding;

  /// Label font size.
  final double fontSize;

  /// Icon size.
  final double iconSize;

  /// Space between an icon and a label.
  final double iconGap;

  /// Height of an icon-only button.
  final double iconOnlyHeight;

  /// How much wider than tall an icon-only capsule is.
  final double iconOnlyExtraWidth;

  /// Corner radius for `GlassButtonShape.roundedRect`.
  final double cornerRadius;
}

const _small = GlassButtonMetrics(
  height: 30,
  padding: 11,
  fontSize: 15,
  iconSize: 15,
  iconGap: 5,
  iconOnlyHeight: 24.33,
  cornerRadius: 8,
);

const _regular = GlassButtonMetrics(
  height: 36.33,
  padding: 13.33,
  fontSize: 17,
  iconSize: 17,
  iconGap: 6,
  iconOnlyHeight: 30,
  cornerRadius: 10,
);

const _large = GlassButtonMetrics(
  height: 52.33,
  padding: 21.33,
  fontSize: 17,
  iconSize: 17,
  iconGap: 6,
  iconOnlyHeight: 46,
  cornerRadius: 14,
);

/// Metrics for [size].
GlassButtonMetrics glassButtonMetrics(GlassControlSize size) => switch (size) {
  GlassControlSize.mini || GlassControlSize.small => _small,
  GlassControlSize.regular => _regular,
  GlassControlSize.large || GlassControlSize.extraLarge => _large,
};
