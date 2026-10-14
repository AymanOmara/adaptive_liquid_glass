import 'package:flutter/widgets.dart';

import '../core/glass_colors.dart';
import 'checkerboard_painter.dart';
import 'color_picker_metrics.dart';

/// A slider of UIColorPickerViewController's (iOS 26.4, measured): a
/// capsule track filled with the gradient the value sweeps through, and a
/// round thumb as tall as the track showing [thumbColor] in a white ring.
/// The opacity slider draws its gradient over a checkerboard. Like the
/// spectrum, it runs left to right in RTL too.
///
/// ```dart
/// ColorChannelSlider(
///   value: red,
///   colors: [Color(0xFF000000), Color(0xFFFF0000)],
///   thumbColor: colour,
///   onChanged: (v) => setState(() => red = v),
/// )
/// ```
class ColorChannelSlider extends StatelessWidget {
  /// Creates the slider.
  const ColorChannelSlider({
    super.key,
    required this.value,
    required this.colors,
    required this.thumbColor,
    required this.onChanged,
    this.checkerboard = false,
    this.semanticLabel,
    this.semanticValue,
  });

  /// The value, 0 to 1 (clamped).
  final double value;

  /// The track's gradient, start to end.
  final List<Color> colors;

  /// The colour inside the thumb's ring.
  final Color thumbColor;

  /// Called as the thumb is dragged or the track tapped.
  final ValueChanged<double> onChanged;

  /// Whether the track shows a checkerboard under its gradient.
  final bool checkerboard;

  /// What assistive tech reads for the slider.
  final String? semanticLabel;

  /// How assistive tech reads [value]; a percentage by default.
  final String Function(double value)? semanticValue;

  String _read(double v) => semanticValue?.call(v) ?? '${(v * 100).round()}%';

  void _pick(double dx, double width) {
    const d = ColorPickerMetrics.trackHeight;
    onChanged(((dx - d / 2) / (width - d)).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    const step = ColorPickerMetrics.channelStep;
    const d = ColorPickerMetrics.trackHeight;
    final radius = BorderRadius.circular(d / 2);
    return Semantics(
      slider: true,
      label: semanticLabel,
      value: _read(v),
      increasedValue: _read((v + step).clamp(0.0, 1.0)),
      decreasedValue: _read((v - step).clamp(0.0, 1.0)),
      onIncrease: () => onChanged((v + step).clamp(0.0, 1.0)),
      onDecrease: () => onChanged((v - step).clamp(0.0, 1.0)),
      child: SizedBox(
        height: d,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTapDown: (e) => _pick(e.localPosition.dx, width),
              onHorizontalDragUpdate: (e) => _pick(e.localPosition.dx, width),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: radius,
                      child: CustomPaint(
                        painter: checkerboard
                            ? const CheckerboardPainter()
                            : null,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: colors),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The thumb travels inside the track, flush with its
                  // ends at 0 and 1 (measured).
                  Positioned(
                    left: v * (width - d),
                    top: 0,
                    width: d,
                    height: d,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: thumbColor,
                          border: Border.all(
                            color: GlassColors.colorPickerThumbRing,
                            width: ColorPickerMetrics.trackThumbRing,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: GlassColors.thumbShadow,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
