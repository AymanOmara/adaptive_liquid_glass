import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Slider;
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import 'control_metrics.dart';
import 'glass_thumb.dart';

/// iOS 26's slider: a thin track whose capsule thumb turns into a clear
/// glass lens while dragged.
///
/// ```dart
/// GlassSlider(value: volume, onChanged: (v) => setState(() => volume = v))
/// ```
///
/// Drag anywhere on it, or tap to jump. With [divisions] it snaps, with a
/// selection haptic at each step. Fills from the reading direction's start.
/// Null [onChanged] disables it. On the Material path it is a Material 3
/// [Slider].
class GlassSlider extends StatefulWidget {
  /// Creates a slider.
  const GlassSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor,
    this.semanticFormatter,
    this.mode,
  }) : assert(min < max, 'min must be less than max'),
       assert(divisions == null || divisions > 0, 'divisions must be > 0');

  /// The current value, from [min] to [max].
  final double value;

  /// Called as the user drags; null disables the slider.
  final ValueChanged<double>? onChanged;

  /// The least value.
  final double min;

  /// The greatest value.
  final double max;

  /// The number of steps between [min] and [max]; null is continuous.
  final int? divisions;

  /// Called when a drag starts, with the value then.
  final ValueChanged<double>? onChangeStart;

  /// Called when a drag ends, with the final value.
  final ValueChanged<double>? onChangeEnd;

  /// The filled part of the track. Defaults to iOS 26's accent blue, as
  /// SwiftUI draws it, or Material 3's colour on the Material path.
  final Color? activeColor;

  /// The value as assistive tech reads it; defaults to a percentage.
  final String Function(double value)? semanticFormatter;

  /// The rendering path for the thumb's lens; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassSlider> createState() => _GlassSliderState();
}

class _GlassSliderState extends State<GlassSlider>
    with SingleTickerProviderStateMixin {
  /// 0 at rest, 1 held.
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  double _width = 0;

  bool get _enabled => widget.onChanged != null;

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  double get _fraction =>
      ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0, 1);

  double get _step => widget.divisions == null ? 0.1 : 1 / widget.divisions!;

  void _springPress(double target) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _press.value = target;
    } else {
      _press.animateWith(
        SpringSimulation(
          ControlMetrics.press,
          _press.value,
          target,
          _press.velocity,
        ),
      );
    }
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  double _snap(double fraction) {
    final divisions = widget.divisions;
    if (divisions == null) return fraction;
    return (fraction * divisions).round() / divisions;
  }

  double _valueAt(double fraction) =>
      widget.min + _snap(fraction.clamp(0.0, 1.0)) * (widget.max - widget.min);

  void _set(double fraction) {
    final value = _valueAt(fraction);
    if (value == widget.value) return;
    if (widget.divisions != null) HapticFeedback.selectionClick();
    widget.onChanged?.call(value);
  }

  /// The fraction for a touch [dx] from the left edge.
  double _fractionAt(double dx) {
    final travel = _width - ControlMetrics.sliderThumbWidth;
    final f = travel <= 0
        ? 0.0
        : (dx - ControlMetrics.sliderThumbWidth / 2) / travel;
    return _rtl ? 1 - f : f;
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, mode) => mode == EffectiveGlassMode.material
        ? Slider(
            value: widget.value,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            onChanged: widget.onChanged,
            onChangeStart: widget.onChangeStart,
            onChangeEnd: widget.onChangeEnd,
            activeColor: widget.activeColor,
            semanticFormatterCallback: widget.semanticFormatter,
          )
        : _glass(context),
  );

  String _label(double value) =>
      widget.semanticFormatter?.call(value) ??
      '${((value - widget.min) / (widget.max - widget.min) * 100).round()}%';

  Widget _glass(BuildContext context) {
    final active = CupertinoDynamicColor.resolve(
      widget.activeColor ?? GlassColors.sliderFill,
      context,
    );
    final inactive = CupertinoDynamicColor.resolve(
      GlassColors.sliderRest,
      context,
    );
    final up = _valueAt(_fraction + _step);
    final down = _valueAt(_fraction - _step);
    return Semantics(
      slider: true,
      enabled: _enabled,
      value: _label(widget.value),
      increasedValue: _label(up),
      decreasedValue: _label(down),
      onIncrease: _enabled ? () => widget.onChanged!(up) : null,
      onDecrease: _enabled ? () => widget.onChanged!(down) : null,
      child: Listener(
        onPointerDown: _enabled
            ? (_) {
                _springPress(1);
                widget.onChangeStart?.call(widget.value);
              }
            : null,
        onPointerUp: _enabled ? (_) => _release() : null,
        onPointerCancel: _enabled ? (_) => _release() : null,
        child: GestureDetector(
          excludeFromSemantics: true,
          onTapUp: _enabled
              ? (d) => _set(_fractionAt(d.localPosition.dx))
              : null,
          onHorizontalDragUpdate: _enabled
              ? (d) => _set(_fractionAt(d.localPosition.dx))
              : null,
          child: Opacity(
            opacity: _enabled ? 1 : 0.5,
            child: SizedBox(
              height: ControlMetrics.sliderHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _width = constraints.maxWidth;
                  return AnimatedBuilder(
                    animation: _press,
                    builder: (context, _) => _paint(active, inactive),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _release() {
    _springPress(0);
    widget.onChangeEnd?.call(widget.value);
  }

  Widget _paint(Color active, Color inactive) {
    const thumbW = ControlMetrics.sliderThumbWidth;
    final centre = thumbW / 2 + _fraction * (_width - thumbW);
    const track = ControlMetrics.sliderTrack;
    const top = (ControlMetrics.sliderHeight - track) / 2;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PositionedDirectional(
          start: 0,
          end: 0,
          top: top,
          height: track,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: inactive,
            ),
          ),
        ),
        PositionedDirectional(
          start: 0,
          width: centre,
          top: top,
          height: track,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: active,
            ),
          ),
        ),
        PositionedDirectional(
          start: centre - thumbW / 2,
          width: thumbW,
          top:
              (ControlMetrics.sliderHeight - ControlMetrics.sliderThumbHeight) /
              2,
          height: ControlMetrics.sliderThumbHeight,
          child: GlassThumb(
            pressed: _press.value,
            color: GlassColors.thumb,
            mode: widget.mode,
            shadow: true,
          ),
        ),
      ],
    );
  }
}
