import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Slider;
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import 'control_metrics.dart';
import 'slider_geometry.dart';
import 'slider_scale.dart';
import 'slider_track.dart';

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
///
/// [axis] [Axis.vertical] stands it up, minimum at the bottom, as SwiftUI's
/// `Slider` turned with `.rotationEffect(.degrees(-90))` (Control Center's
/// volume): give it a bounded height. Assistive tech's increase moves the
/// thumb up.
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
    Color? tint,
    @Deprecated('Use tint. Will be removed in 1.0.') Color? activeColor,
    this.semanticFormatter,
    this.mode,
    this.axis = Axis.horizontal,
  }) : assert(
         tint == null || activeColor == null,
         'Pass tint only; activeColor is its old name.',
       ),
       tint = tint ?? activeColor,
       assert(min < max, 'min must be less than max'),
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
  final Color? tint;

  /// The old name of [tint].
  @Deprecated('Use tint. Will be removed in 1.0.')
  Color? get activeColor => tint;

  /// The value as assistive tech reads it; defaults to a percentage.
  final String Function(double value)? semanticFormatter;

  /// The rendering path for the thumb's lens; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// The track's direction: horizontal, or vertical with [min] at the
  /// bottom.
  final Axis axis;

  @override
  State<GlassSlider> createState() => _GlassSliderState();
}

class _GlassSliderState extends State<GlassSlider>
    with SingleTickerProviderStateMixin {
  /// 0 at rest, 1 held.
  late final AnimationController _press;

  double _length = 0;

  bool get _enabled => widget.onChanged != null;

  bool get _vertical => widget.axis == Axis.vertical;

  SliderScale get _scale => SliderScale(
    min: widget.min,
    max: widget.max,
    divisions: widget.divisions,
  );

  SliderGeometry get _geometry => SliderGeometry(
    axis: widget.axis,
    length: _length,
    rtl: Directionality.of(context) == TextDirection.rtl,
  );

  double get _fraction => _scale.fractionOf(widget.value);

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

  // Created here, not lazily: one first read in dispose would create
  // its ticker on a deactivated element.
  @override
  void initState() {
    super.initState();
    _press = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _set(Offset local) {
    final value = _scale.valueAt(_geometry.fractionAt(local));
    if (value == widget.value) return;
    if (widget.divisions != null) HapticFeedback.selectionClick();
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, mode) =>
        mode == EffectiveGlassMode.material ? _material() : _glass(context),
  );

  Widget _material() {
    final slider = Slider(
      value: widget.value,
      min: widget.min,
      max: widget.max,
      divisions: widget.divisions,
      onChanged: widget.onChanged,
      onChangeStart: widget.onChangeStart,
      onChangeEnd: widget.onChangeEnd,
      activeColor: widget.tint,
      semanticFormatterCallback: widget.semanticFormatter,
    );
    return _vertical
        ? RotatedBox(
            quarterTurns: 3,
            child: Directionality(
              textDirection: TextDirection.ltr,
              // Its preferred thickness: a Material slider fills a bounded
              // height, which the turn makes the vertical slot's width.
              child: IntrinsicHeight(child: slider),
            ),
          )
        : slider;
  }

  String _label(double value) =>
      widget.semanticFormatter?.call(value) ?? _scale.percent(value);

  Widget _glass(BuildContext context) {
    final active = CupertinoDynamicColor.resolve(
      widget.tint ?? GlassColors.sliderFill,
      context,
    );
    final inactive = CupertinoDynamicColor.resolve(
      GlassColors.sliderRest,
      context,
    );
    final scale = _scale;
    final up = scale.valueAt(_fraction + scale.step);
    final down = scale.valueAt(_fraction - scale.step);
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
          onTapUp: _enabled ? (d) => _set(d.localPosition) : null,
          onHorizontalDragUpdate: _enabled && !_vertical
              ? (d) => _set(d.localPosition)
              : null,
          onVerticalDragUpdate: _enabled && _vertical
              ? (d) => _set(d.localPosition)
              : null,
          child: Opacity(
            opacity: _enabled ? 1 : 0.5,
            child: SizedBox(
              width: _vertical ? ControlMetrics.sliderHeight : null,
              height: _vertical ? null : ControlMetrics.sliderHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _length = _vertical
                      ? constraints.maxHeight
                      : constraints.maxWidth;
                  return AnimatedBuilder(
                    animation: _press,
                    builder: (context, _) => SliderTrack(
                      geometry: _geometry,
                      fillFrom: null,
                      fillTo: _fraction,
                      thumbs: [_fraction],
                      pressed: [_press.value],
                      active: active,
                      inactive: inactive,
                      mode: widget.mode,
                    ),
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
}
