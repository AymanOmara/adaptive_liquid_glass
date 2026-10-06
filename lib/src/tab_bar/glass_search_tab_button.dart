import 'package:flutter/cupertino.dart';

import '../core/glass.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../liquid_glass.dart';

/// The search tab beside iOS 26's tab bar (SwiftUI's
/// `Tab(role: .search)`): a 62-pt glass circle with a magnifying glass.
class GlassSearchTabButton extends StatelessWidget {
  /// Creates the button.
  const GlassSearchTabButton({
    super.key,
    required this.onPressed,
    required this.semanticLabel,
    this.glass,
    this.mode,
  });

  /// Called when it is tapped.
  final VoidCallback onPressed;

  /// What assistive tech reads.
  final String semanticLabel;

  /// The glass; the bar's.
  final Glass? glass;

  /// The rendering path; the bar's.
  final GlassRenderMode? mode;

  /// The circle's diameter (measured: the tab bar's height).
  static const double size = 62;

  /// The gap between the bar and the circle (measured).
  static const double gap = 10;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    // One node: the label merges into the glass's button node, which
    // carries the tap action.
    child: Semantics(
      label: semanticLabel,
      child: SizedBox.square(
        dimension: size,
        child: LiquidGlass(
          glass: glass,
          mode: mode,
          shape: const GlassShape.circle(),
          onPressed: onPressed,
          child: const Center(child: Icon(CupertinoIcons.search, size: 26)),
        ),
      ),
    ),
  );
}
