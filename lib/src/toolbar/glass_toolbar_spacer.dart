import 'package:flutter/widgets.dart';

/// Splits a [GlassToolbar]'s items into separate glass capsules, like
/// SwiftUI's `ToolbarSpacer(.flexible)`.
///
/// It takes the free width between the groups on each side of it. In
/// `GlassNavigationBar.actions` it splits the trailing items into separate
/// capsules a fixed 12 pt apart, like `ToolbarSpacer(.fixed)` in a
/// SwiftUI navigation bar.
class GlassToolbarSpacer extends StatelessWidget {
  /// Creates a spacer.
  const GlassToolbarSpacer({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
