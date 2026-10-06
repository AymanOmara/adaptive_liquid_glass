import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show CircularProgressIndicator, LinearProgressIndicator;

import '../core/effective_glass_mode.dart';
import '../core/glass.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_system_colors.dart';
import '../liquid_glass.dart';
import 'glass_progress_style.dart';
import 'progress_metrics.dart';
import 'progress_ring_painter.dart';

/// iOS 26's progress indicator, like SwiftUI's `ProgressView`: a linear
/// bar on a glass track, or a circular one (a ring when the value is
/// known, iOS's activity spinner when it is not).
///
/// ```dart
/// GlassProgressIndicator(value: downloaded)   // 0..1
/// const GlassProgressIndicator.circular()     // a spinner
/// ```
///
/// A null [value] is indeterminate. The fill defaults to system blue,
/// and eases to a new value; with Reduce Motion it jumps instead and the
/// indeterminate segment does not move. On the Material path it is a
/// Material 3 [LinearProgressIndicator] or [CircularProgressIndicator].
class GlassProgressIndicator extends StatefulWidget {
  /// Creates a progress indicator.
  const GlassProgressIndicator({
    super.key,
    this.value,
    this.style = GlassProgressStyle.linear,
    this.color,
    this.glass,
    this.semanticLabel,
    this.mode,
  });

  /// Creates a circular indicator.
  const GlassProgressIndicator.circular({
    super.key,
    this.value,
    this.color,
    this.semanticLabel,
    this.mode,
  }) : style = GlassProgressStyle.circular,
       glass = null;

  /// The progress, 0 to 1; null is indeterminate.
  final double? value;

  /// A linear bar, or a circular ring (a spinner while indeterminate).
  final GlassProgressStyle style;

  /// The fill. Defaults to system blue, or Material 3's primary.
  final Color? color;

  /// The linear track's glass. Defaults to the theme's default glass.
  final Glass? glass;

  /// What assistive tech reads, e.g. 'Downloading'.
  final String? semanticLabel;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassProgressIndicator> createState() => _GlassProgressIndicatorState();
}

class _GlassProgressIndicatorState extends State<GlassProgressIndicator>
    with SingleTickerProviderStateMixin {
  /// The indeterminate segment's slide from start to end.
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: ProgressMetrics.indeterminatePeriod,
  );

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  String? get _semanticValue => widget.value == null
      ? null
      : '${(widget.value!.clamp(0.0, 1.0) * 100).round()}%';

  Color _colour(BuildContext context) => CupertinoDynamicColor.resolve(
    widget.color ?? GlassSystemColors.blue,
    context,
  );

  /// The controller runs only while indeterminate with motion allowed;
  /// synced when the value or Reduce Motion changes.
  void _syncTicker() {
    if (widget.value == null && !_reduceMotion) {
      if (!_slide.isAnimating) _slide.repeat();
    } else if (_slide.isAnimating || _slide.value != 0) {
      _slide
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(GlassProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassModeBuilder(
      mode: widget.mode,
      builder: (context, effective) => effective == EffectiveGlassMode.material
          ? _material()
          : Semantics(
              label: widget.semanticLabel,
              value: _semanticValue,
              child: widget.style == GlassProgressStyle.linear
                  ? _linear(context)
                  : _circular(context),
            ),
    );
  }

  Widget _material() => widget.style == GlassProgressStyle.linear
      ? LinearProgressIndicator(
          value: widget.value,
          color: widget.color,
          semanticsLabel: widget.semanticLabel,
          semanticsValue: _semanticValue,
        )
      : CircularProgressIndicator(
          value: widget.value,
          color: widget.color,
          semanticsLabel: widget.semanticLabel,
          semanticsValue: _semanticValue,
        );

  Widget _linear(BuildContext context) => SizedBox(
    height: ProgressMetrics.linearHeight,
    width: double.infinity,
    child: LiquidGlass(
      glass: widget.glass,
      mode: widget.mode,
      adaptiveForeground: false,
      padding: const EdgeInsetsDirectional.all(ProgressMetrics.fillInset),
      child: widget.value == null
          ? _segmentFill(_colour(context))
          : _barFill(_colour(context)),
    ),
  );

  Widget _fillCapsule(Color colour) => DecoratedBox(
    decoration: ShapeDecoration(shape: const StadiumBorder(), color: colour),
  );

  Widget _barFill(Color colour) => TweenAnimationBuilder<double>(
    tween: Tween(end: widget.value!.clamp(0.0, 1.0)),
    duration: _reduceMotion ? Duration.zero : ProgressMetrics.valueAnimation,
    builder: (_, v, _) => FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: v,
      child: _fillCapsule(colour),
    ),
  );

  Widget _segmentFill(Color colour) => ClipPath(
    clipper: const ShapeBorderClipper(shape: StadiumBorder()),
    child: AnimatedBuilder(
      animation: _slide,
      builder: (_, _) => Align(
        alignment: AlignmentDirectional(-1 + 2 * _slide.value, 0),
        child: FractionallySizedBox(
          widthFactor: ProgressMetrics.indeterminateFraction,
          child: _fillCapsule(colour),
        ),
      ),
    ),
  );

  Widget _circular(BuildContext context) {
    final colour = _colour(context);
    if (widget.value == null) {
      return CupertinoActivityIndicator(
        radius: ProgressMetrics.circularSize / 2,
        animating: !_reduceMotion,
      );
    }
    return SizedBox.square(
      dimension: ProgressMetrics.circularSize,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.value!.clamp(0.0, 1.0)),
        duration: _reduceMotion
            ? Duration.zero
            : ProgressMetrics.valueAnimation,
        builder: (_, v, _) => CustomPaint(
          painter: ProgressRingPainter(
            value: v,
            color: colour,
            track: CupertinoDynamicColor.resolve(
              CupertinoColors.tertiarySystemFill,
              context,
            ),
            stroke: ProgressMetrics.ringStroke,
            rtl: Directionality.of(context) == TextDirection.rtl,
          ),
        ),
      ),
    );
  }
}
