import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show RangeSlider, RangeValues;
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

/// A two-thumb slider choosing a range: [GlassSlider]'s track with a glass
/// lens thumb at each end, filled between them.
///
/// ```dart
/// GlassRangeSlider(
///   values: price,
///   min: 0,
///   max: 500,
///   onChanged: (v) => setState(() => price = v),
/// )
/// ```
///
/// SwiftUI and UIKit have no range slider; its geometry, colours, press
/// growth and haptics follow SwiftUI's single `Slider`. A touch takes the
/// nearest thumb; where the thumbs overlap, the drag's direction picks
/// one. The thumbs never cross. With [divisions] they snap, with a
/// selection haptic at each step. [axis] [Axis.vertical] puts [min] at the
/// bottom (give it a bounded height). Each thumb is its own slider for
/// assistive tech. Null [onChanged] disables it. On the Material path it is
/// a Material 3 [RangeSlider].
class GlassRangeSlider extends StatefulWidget {
  /// Creates a range slider.
  const GlassRangeSlider({
    super.key,
    required this.values,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor,
    this.semanticFormatter,
    this.mode,
    this.axis = Axis.horizontal,
  }) : assert(min < max, 'min must be less than max'),
       assert(divisions == null || divisions > 0, 'divisions must be > 0');

  /// The current range, `start <= end`, both from [min] to [max].
  final RangeValues values;

  /// Called as the user drags either thumb; null disables the slider.
  final ValueChanged<RangeValues>? onChanged;

  /// The least value.
  final double min;

  /// The greatest value.
  final double max;

  /// The number of steps between [min] and [max]; null is continuous.
  final int? divisions;

  /// Called when a drag starts, with the values then.
  final ValueChanged<RangeValues>? onChangeStart;

  /// Called when a drag ends, with the final values.
  final ValueChanged<RangeValues>? onChangeEnd;

  /// The filled part of the track, between the thumbs. Defaults to iOS
  /// 26's accent blue, as SwiftUI's slider draws it, or Material 3's
  /// colour on the Material path.
  final Color? activeColor;

  /// A thumb's value as assistive tech reads it; defaults to a percentage.
  final String Function(double value)? semanticFormatter;

  /// The rendering path for the thumbs' lenses; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// The track's direction: horizontal, or vertical with [min] at the
  /// bottom.
  final Axis axis;

  @override
  State<GlassRangeSlider> createState() => _GlassRangeSliderState();
}

class _GlassRangeSliderState extends State<GlassRangeSlider>
    with TickerProviderStateMixin {
  /// Each thumb's press: 0 at rest, 1 held.
  late final List<AnimationController> _press = [
    AnimationController.unbounded(vsync: this),
    AnimationController.unbounded(vsync: this),
  ];

  double _length = 0;

  /// The thumb being dragged: 0 start, 1 end, null not yet decided.
  int? _active;

  /// Where an undecided touch went down.
  Offset? _down;

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

  List<double> get _fractions => [
    _scale.fractionOf(widget.values.start),
    _scale.fractionOf(widget.values.end),
  ];

  void _springPress(int thumb, double target) {
    final press = _press[thumb];
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      press.value = target;
    } else {
      press.animateWith(
        SpringSimulation(
          ControlMetrics.press,
          press.value,
          target,
          press.velocity,
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final press in _press) {
      press.dispose();
    }
    super.dispose();
  }

  /// The thumb a touch at [local] takes, or null when it lands on
  /// overlapping thumbs (the drag's direction then decides).
  int? _pick(Offset local) {
    final geometry = _geometry;
    final f = _fractions;
    final at = geometry.fractionAt(local) * geometry.travel;
    final lo = f[0] * geometry.travel;
    final hi = f[1] * geometry.travel;
    const reach = ControlMetrics.sliderThumbWidth / 2;
    if (hi - lo < ControlMetrics.sliderThumbWidth &&
        at > lo - reach &&
        at < hi + reach) {
      return null;
    }
    return (at - lo).abs() <= (at - hi).abs() ? 0 : 1;
  }

  void _onDown(Offset local) {
    _active = _pick(local);
    _down = local;
    if (_active == null) {
      _springPress(0, 1);
      _springPress(1, 1);
    } else {
      _springPress(_active!, 1);
    }
    widget.onChangeStart?.call(widget.values);
  }

  /// Settles an undecided touch: toward [max] takes the end thumb.
  void _decide(int thumb) {
    _active = thumb;
    _springPress(1 - thumb, 0);
  }

  void _onDrag(Offset local) {
    if (_active == null) {
      final geometry = _geometry;
      final moved = geometry.fractionAt(local) - geometry.fractionAt(_down!);
      if (moved == 0) return;
      _decide(moved > 0 ? 1 : 0);
    }
    _set(_active!, _geometry.fractionAt(local));
  }

  void _onTap(Offset local) {
    if (_active == null) {
      final f = _fractions;
      _decide(_geometry.fractionAt(local) > (f[0] + f[1]) / 2 ? 1 : 0);
    }
    _set(_active!, _geometry.fractionAt(local));
  }

  /// Moves [thumb] to [fraction], stopped at the other thumb.
  void _set(int thumb, double fraction) {
    final values = _clamped(thumb, _scale.valueAt(fraction));
    if (values == widget.values) return;
    if (widget.divisions != null) HapticFeedback.selectionClick();
    widget.onChanged?.call(values);
  }

  RangeValues _clamped(int thumb, double value) {
    final v = widget.values;
    return thumb == 0
        ? RangeValues(value > v.end ? v.end : value, v.end)
        : RangeValues(v.start, value < v.start ? v.start : value);
  }

  void _release() {
    _springPress(0, 0);
    _springPress(1, 0);
    _active = null;
    _down = null;
    widget.onChangeEnd?.call(widget.values);
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, mode) =>
        mode == EffectiveGlassMode.material ? _material() : _glass(context),
  );

  Widget _material() {
    final slider = RangeSlider(
      values: widget.values,
      min: widget.min,
      max: widget.max,
      divisions: widget.divisions,
      onChanged: widget.onChanged,
      onChangeStart: widget.onChangeStart,
      onChangeEnd: widget.onChangeEnd,
      activeColor: widget.activeColor,
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

  /// Thumb [i]'s own slider node for assistive tech.
  Widget _semantics(int i, Widget thumb) {
    final scale = _scale;
    final f = _fractions[i];
    final value = i == 0 ? widget.values.start : widget.values.end;
    final up = _clamped(i, scale.valueAt(f + scale.step));
    final down = _clamped(i, scale.valueAt(f - scale.step));
    double of(RangeValues v) => i == 0 ? v.start : v.end;
    return Semantics(
      container: true,
      slider: true,
      enabled: _enabled,
      value: _label(value),
      increasedValue: _label(of(up)),
      decreasedValue: _label(of(down)),
      onIncrease: _enabled ? () => widget.onChanged!(up) : null,
      onDecrease: _enabled ? () => widget.onChanged!(down) : null,
      child: thumb,
    );
  }

  Widget _glass(BuildContext context) {
    final active = CupertinoDynamicColor.resolve(
      widget.activeColor ?? GlassColors.sliderFill,
      context,
    );
    final inactive = CupertinoDynamicColor.resolve(
      GlassColors.sliderRest,
      context,
    );
    return Listener(
      onPointerDown: _enabled ? (d) => _onDown(d.localPosition) : null,
      onPointerUp: _enabled ? (_) => _release() : null,
      onPointerCancel: _enabled ? (_) => _release() : null,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTapUp: _enabled ? (d) => _onTap(d.localPosition) : null,
        onHorizontalDragUpdate: _enabled && !_vertical
            ? (d) => _onDrag(d.localPosition)
            : null,
        onVerticalDragUpdate: _enabled && _vertical
            ? (d) => _onDrag(d.localPosition)
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
                  animation: Listenable.merge(_press),
                  builder: (context, _) {
                    final f = _fractions;
                    return SliderTrack(
                      geometry: _geometry,
                      fillFrom: f[0],
                      fillTo: f[1],
                      thumbs: f,
                      pressed: [_press[0].value, _press[1].value],
                      active: active,
                      inactive: inactive,
                      mode: widget.mode,
                      thumbBuilder: _semantics,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
