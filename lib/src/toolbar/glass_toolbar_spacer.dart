import 'package:flutter/widgets.dart';

/// Splits a [GlassToolbar]'s items into separate glass capsules, like
/// SwiftUI's `ToolbarSpacer(.flexible)`.
///
/// It takes the free width between the groups on each side of it.
class GlassToolbarSpacer extends StatelessWidget {
  /// Creates a spacer.
  const GlassToolbarSpacer({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
