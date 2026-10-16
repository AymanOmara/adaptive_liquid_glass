import 'package:flutter/cupertino.dart';

import '../button/glass_button.dart';
import '../button/glass_button_metrics_scope.dart';
import '../button/glass_button_shape.dart';
import '../core/glass_render_mode.dart';
import '../toolbar/toolbar_metrics.dart';
import 'search_metrics.dart';

/// The button that ends an active `GlassSearchable` field.
///
/// ```dart
/// SearchCancelButton(onPressed: controller.cancel, label: 'Cancel')
/// ```
///
/// iOS 26's: a 48-pt glass circle with an xmark beside the field
/// (measured from SwiftUI's active `.searchable`, iOS 26.4). [label] is
/// what assistive tech reads.
class SearchCancelButton extends StatelessWidget {
  /// Creates the cancel button.
  const SearchCancelButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.mode,
    this.size = SearchMetrics.cancelSize,
  });

  /// Ends the search.
  final VoidCallback onPressed;

  /// The button's accessible name.
  final String label;

  /// Rendering mode; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// The button's diameter.
  final double size;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: GlassButtonMetricsScope(
        metrics: ToolbarMetrics.single,
        child: GlassButton.icon(
          onPressed: onPressed,
          icon: CupertinoIcons.xmark,
          shape: GlassButtonShape.circle,
          mode: mode,
          semanticLabel: label,
        ),
      ),
    ),
  );
}
