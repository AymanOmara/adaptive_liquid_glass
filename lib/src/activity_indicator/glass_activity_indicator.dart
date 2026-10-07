import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircularProgressIndicator;

import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../progress/progress_metrics.dart';

/// iOS's activity spinner, like SwiftUI's `ProgressView()` with no value.
///
/// ```dart
/// const GlassActivityIndicator()
/// GlassActivityIndicator(radius: 14, color: GlassSystemColors.blue)
/// ```
///
/// The same spinner `GlassProgressIndicator.circular()` shows while
/// indeterminate, on its own and sized by [radius]. With Reduce Motion, or
/// [animating] false, it holds still. On the Material path it is a
/// Material 3 [CircularProgressIndicator] of the same size.
class GlassActivityIndicator extends StatelessWidget {
  /// Creates an activity indicator.
  const GlassActivityIndicator({
    super.key,
    this.radius = ProgressMetrics.circularSize / 2,
    this.color,
    this.animating = true,
    this.mode,
    this.semanticLabel = 'Loading',
  }) : assert(radius > 0, 'radius must be positive');

  /// Half the spinner's diameter.
  final double radius;

  /// The spinner's colour. Defaults to iOS's spinner grey, or Material 3's
  /// primary.
  final Color? color;

  /// Whether the spinner turns; false shows it still.
  final bool animating;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// What assistive tech reads.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? SizedBox.square(
            dimension: radius * 2,
            child: CircularProgressIndicator(
              value: animating ? null : 0,
              color: color,
              strokeWidth: ProgressMetrics.ringStroke,
              semanticsLabel: semanticLabel,
            ),
          )
        : Semantics(
            label: semanticLabel,
            child: CupertinoActivityIndicator(
              radius: radius,
              color: color,
              animating:
                  animating &&
                  !(MediaQuery.maybeDisableAnimationsOf(context) ?? false),
            ),
          ),
  );
}
