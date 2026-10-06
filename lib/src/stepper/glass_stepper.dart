import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show IconButton, Icons;
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';

/// iOS 26's stepper, like SwiftUI's `Stepper`: a capsule with minus and
/// plus halves.
///
/// ```dart
/// GlassStepper(
///   value: count,
///   min: 0,
///   max: 10,
///   onChanged: (v) => setState(() => count = v),
/// )
/// ```
///
/// A half is disabled at its bound. Measured from SwiftUI on iOS 26.4
/// (93 by 31.33 pt). On the Material path it is a pair of icon buttons.
class GlassStepper extends StatefulWidget {
  /// Creates a stepper.
  const GlassStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.decrementLabel = 'Decrement',
    this.incrementLabel = 'Increment',
    this.mode,
  }) : assert(min <= max, 'min must not exceed max');

  /// The current value.
  final double value;

  /// Called with the new value; null disables the stepper.
  final ValueChanged<double>? onChanged;

  /// The least value.
  final double min;

  /// The greatest value.
  final double max;

  /// How much each tap changes the value.
  final double step;

  /// What assistive tech reads for the minus half.
  final String decrementLabel;

  /// What assistive tech reads for the plus half.
  final String incrementLabel;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// The capsule's size (measured).
  static const Size size = Size(93, 31.33);

  /// The divider's height (measured).
  static const double dividerHeight = 24;

  /// The minus and plus glyphs' size (13 pt of ink measured).
  static const double glyphSize = 17;

  @override
  State<GlassStepper> createState() => _GlassStepperState();
}

class _GlassStepperState extends State<GlassStepper> {
  /// The half being pressed: -1 minus, 1 plus, 0 none.
  int _pressed = 0;

  bool get _canDown =>
      widget.onChanged != null && widget.value - widget.step >= widget.min;

  bool get _canUp =>
      widget.onChanged != null && widget.value + widget.step <= widget.max;

  void _change(int direction) {
    final next = (widget.value + direction * widget.step).clamp(
      widget.min,
      widget.max,
    );
    if (next == widget.value) return;
    HapticFeedback.selectionClick();
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                tooltip: widget.decrementLabel,
                onPressed: _canDown ? () => _change(-1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: widget.incrementLabel,
                onPressed: _canUp ? () => _change(1) : null,
              ),
            ],
          )
        : _glass(context),
  );

  Widget _half(BuildContext context, int direction) {
    final enabled = direction < 0 ? _canDown : _canUp;
    final colour = CupertinoDynamicColor.resolve(
      enabled ? CupertinoColors.label : CupertinoColors.tertiaryLabel,
      context,
    );
    return Expanded(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: direction < 0 ? widget.decrementLabel : widget.incrementLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled
              ? (_) => setState(() => _pressed = direction)
              : null,
          onTapCancel: () => setState(() => _pressed = 0),
          onTapUp: enabled
              ? (_) {
                  setState(() => _pressed = 0);
                  _change(direction);
                }
              : null,
          child: AnimatedOpacity(
            opacity: _pressed == direction ? 0.3 : 1,
            duration: const Duration(milliseconds: 100),
            child: Center(
              child: Icon(
                direction < 0 ? CupertinoIcons.minus : CupertinoIcons.plus,
                size: GlassStepper.glyphSize,
                color: colour,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glass(BuildContext context) => SizedBox.fromSize(
    size: GlassStepper.size,
    child: DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: CupertinoDynamicColor.resolve(GlassColors.stepperFill, context),
      ),
      child: Row(
        children: [
          _half(context, -1),
          Container(
            width: 1,
            height: GlassStepper.dividerHeight,
            color: CupertinoDynamicColor.resolve(
              GlassColors.stepperDivider,
              context,
            ),
          ),
          _half(context, 1),
        ],
      ),
    ),
  );
}
