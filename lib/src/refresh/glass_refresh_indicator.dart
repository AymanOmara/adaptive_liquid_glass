import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter/widgets.dart';

import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../liquid_glass.dart';
import 'refresh_metrics.dart';

/// iOS 26's pull to refresh indicator: a glass disk that scales in with
/// the pull, the spinner's spokes revealed one by one as it nears the
/// threshold (as `UIRefreshControl` does), and the spinner turning once
/// refresh starts. Shown by [GlassRefresh] and
/// [SliverGlassRefresh]; rarely built directly.
///
/// ```dart
/// GlassRefreshIndicator(progress: 0.5, refreshing: false)
/// ```
///
/// With Reduce Motion the disk does not scale in. On the Material path
/// the disk is a Material 3 [CircularProgressIndicator] instead.
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

  /// Pull progress, 0 to 1 (clamped); drives the spokes and the scale-in.
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
      child: Transform.scale(
        scale: reduceMotion || refreshing
            ? 1
            : lerpDouble(RefreshMetrics.minScale, 1, value),
        child: Opacity(
          opacity: progress <= 0 && !refreshing ? 0 : 1,
          child: GlassModeBuilder(
            mode: mode,
            builder: (context, effective) =>
                effective == EffectiveGlassMode.material
                ? _material()
                : _glass(reduceMotion),
          ),
        ),
      ),
    );
  }

  Widget _material() => ExcludeSemantics(
    child: SizedBox.square(
      dimension: RefreshMetrics.diskSize,
      child: Center(
        child: SizedBox.square(
          dimension: RefreshMetrics.spinnerSize,
          child: CircularProgressIndicator(
            value: refreshing ? null : progress.clamp(0.0, 1.0),
            color: color,
            strokeWidth: 2.5,
          ),
        ),
      ),
    ),
  );

  Widget _glass(bool reduceMotion) => LiquidGlass(
    shape: const GlassShape.circle(),
    mode: mode,
    child: SizedBox.square(
      dimension: RefreshMetrics.diskSize,
      child: Center(
        child: ExcludeSemantics(
          child: refreshing
              ? CupertinoActivityIndicator(
                  color: color,
                  radius: RefreshMetrics.spinnerSize / 2,
                  animating: !reduceMotion,
                )
              : CupertinoActivityIndicator.partiallyRevealed(
                  color: color,
                  radius: RefreshMetrics.spinnerSize / 2,
                  progress: progress.clamp(0.0, 1.0),
                ),
        ),
      ),
    ),
  );
}
