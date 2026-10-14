import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter/widgets.dart';

import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import 'refresh_metrics.dart';

/// iOS 26's pull to refresh indicator: the spinner's spokes revealed one
/// by one and fading in with the pull (as `UIRefreshControl` does), and
/// turning once refresh starts. Like SwiftUI's, it has no disk behind it
/// and does not scale. Shown by [GlassRefresh] and [SliverGlassRefresh];
/// rarely built directly.
///
/// ```dart
/// GlassRefreshIndicator(progress: 0.5, refreshing: false)
/// ```
///
/// With Reduce Motion the spinner does not turn. On the Material path
/// it is a Material 3 [CircularProgressIndicator] instead.
class GlassRefreshIndicator extends StatelessWidget {
  /// Creates the indicator.
  const GlassRefreshIndicator({
    super.key,
    required this.progress,
    required this.refreshing,
    this.color,
    this.semanticLabel,
    this.mode,
  });

  /// Pull progress, 0 to 1 (clamped); drives the spokes and the fade-in.
  final double progress;

  /// Whether onRefresh is pending: the spinner spins.
  final bool refreshing;

  /// The spinner's colour (the ring's on the Material path). Defaults to
  /// the system's.
  final Color? color;

  /// Announced while refreshing. Defaults to 'Refreshing' (English; there
  /// is no Cupertino l10n string for it).
  final String? semanticLabel;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      liveRegion: refreshing,
      label: refreshing ? semanticLabel ?? 'Refreshing' : null,
      // SwiftUI's spokes darken with the pull (measured: about the pull's
      // fraction of the threshold in opacity).
      child: Opacity(
        opacity: refreshing ? 1 : value,
        child: GlassModeBuilder(
          mode: mode,
          builder: (context, effective) =>
              effective == EffectiveGlassMode.material
              ? _material(value)
              : _spinner(value, reduceMotion),
        ),
      ),
    );
  }

  Widget _material(double value) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: RefreshMetrics.diskSize,
      child: Center(
        child: SizedBox.square(
          dimension: RefreshMetrics.ringSize,
          child: CircularProgressIndicator(
            value: refreshing ? null : value,
            color: color,
            strokeWidth: 2.5,
          ),
        ),
      ),
    ),
  );

  Widget _spinner(double value, bool reduceMotion) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: RefreshMetrics.spinnerSize,
      child: refreshing
          ? CupertinoActivityIndicator(
              color: color,
              radius: RefreshMetrics.spinnerSize / 2,
              animating: !reduceMotion,
            )
          : CupertinoActivityIndicator.partiallyRevealed(
              color: color,
              radius: RefreshMetrics.spinnerSize / 2,
              progress: value,
            ),
    ),
  );
}
