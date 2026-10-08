import 'package:flutter/cupertino.dart';

import 'glass_button_metrics.dart';

/// Exact metrics for glass buttons below, overriding their control size.
/// Internal: bars use it for their item metrics.
class GlassButtonMetricsScope extends InheritedWidget {
  /// Creates the scope.
  const GlassButtonMetricsScope({
    super.key,
    required this.metrics,
    required super.child,
  });

  /// The metrics buttons below use.
  final GlassButtonMetrics metrics;

  /// The nearest scope's metrics, if any.
  static GlassButtonMetrics? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<GlassButtonMetricsScope>()
      ?.metrics;

  @override
  bool updateShouldNotify(GlassButtonMetricsScope old) =>
      old.metrics != metrics;
}
