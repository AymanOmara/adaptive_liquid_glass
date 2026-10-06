import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ButtonSegment, SegmentedButton;
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/ios_text.dart';
import 'control_metrics.dart';
import 'glass_segment.dart';
import 'glass_thumb.dart';

/// iOS 26's segmented control: a capsule track whose thumb turns into a
/// clear glass lens while pressed and slides between segments.
///
/// ```dart
/// GlassSegmentedControl<Period>(
///   segments: const [
///     GlassSegment(value: Period.day, label: Text('Day')),
///     GlassSegment(value: Period.week, label: Text('Week')),
///   ],
///   selected: period,
///   onChanged: (p) => setState(() => period = p),
/// )
/// ```
///
/// Tap a segment, or drag the thumb across and let go. Segments share the
/// width equally (80 each when unbounded). Follows the reading direction.
/// Null [onChanged] disables it. On the Material path it is a Material 3
/// [SegmentedButton].
class GlassSegmentedControl<T> extends StatefulWidget {
  /// Creates a segmented control.
  const GlassSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.mode,
  }) : assert(segments.length >= 2, 'Needs at least two segments.');

  /// The segments, in reading order.
  final List<GlassSegment<T>> segments;

  /// The selected segment's value.
  final T selected;

  /// Called with the value the user picked; null disables the control.
  final ValueChanged<T>? onChanged;

  /// The rendering path for the thumb's lens; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassSegmentedControl<T>> createState() =>
      _GlassSegmentedControlState<T>();
}

class _GlassSegmentedControlState<T> extends State<GlassSegmentedControl<T>>
    with TickerProviderStateMixin {
  /// The thumb's centre in visual slots (the leftmost segment is 0).
  late final AnimationController _x = AnimationController.unbounded(
    vsync: this,
  );

  /// 0 at rest, 1 held.
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  bool _placed = false;
  double _segmentWidth = 80;

  /// The slot under the finger, as last announced by a haptic.
  int _fingerSlot = 0;

  int get _count => widget.segments.length;

  bool get _enabled => widget.onChanged != null;

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  int get _selectedIndex {
    final i = widget.segments.indexWhere((s) => s.value == widget.selected);
    return i < 0 ? 0 : i;
  }

  int _slot(int index) => _rtl ? _count - 1 - index : index;

  void _spring(AnimationController c, SpringDescription s, double target) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      c.value = target;
    } else {
      c.animateWith(SpringSimulation(s, c.value, target, c.velocity));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_placed || _press.value == 0) {
      _x.value = _slot(_selectedIndex).toDouble();
    }
    _placed = true;
  }

  @override
  void didUpdateWidget(GlassSegmentedControl<T> old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected && _press.value == 0) {
      _spring(_x, ControlMetrics.slide, _slot(_selectedIndex).toDouble());
    }
  }

  @override
  void dispose() {
    _x.dispose();
    _press.dispose();
    super.dispose();
  }

  double _slotAt(double dx) =>
      ((dx / _segmentWidth) - 0.5).clamp(0.0, _count - 1.0);

  void _down(PointerDownEvent e) {
    final slot = _slotAt(e.localPosition.dx);
    _fingerSlot = slot.round();
    _spring(_press, ControlMetrics.press, 1);
    _spring(_x, ControlMetrics.slide, _fingerSlot.toDouble());
  }

  void _move(PointerMoveEvent e) {
    final slot = _slotAt(e.localPosition.dx);
    _x.stop();
    _x.value = slot;
    if (slot.round() != _fingerSlot) {
      _fingerSlot = slot.round();
      HapticFeedback.selectionClick();
    }
  }

  void _up() {
    _spring(_press, ControlMetrics.press, 0);
    _spring(_x, ControlMetrics.slide, _fingerSlot.toDouble());
    final index = _rtl ? _count - 1 - _fingerSlot : _fingerSlot;
    final value = widget.segments[index].value;
    if (value != widget.selected) widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, mode) => mode == EffectiveGlassMode.material
        ? SegmentedButton<T>(
            segments: [
              for (final s in widget.segments)
                ButtonSegment(
                  value: s.value,
                  label: s.label,
                  tooltip: s.semanticLabel,
                ),
            ],
            selected: {widget.selected},
            showSelectedIcon: false,
            onSelectionChanged: widget.onChanged == null
                ? null
                : (s) => widget.onChanged!(s.first),
          )
        : _glass(context),
  );

  Widget _glass(BuildContext context) {
    final track = CupertinoDynamicColor.resolve(
      GlassColors.segmentTrack,
      context,
    );
    final thumb = CupertinoDynamicColor.resolve(
      GlassColors.segmentThumb,
      context,
    );
    final label = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    return Listener(
      onPointerDown: _enabled ? _down : null,
      onPointerMove: _enabled ? _move : null,
      onPointerUp: _enabled ? (_) => _up() : null,
      onPointerCancel: _enabled
          ? (_) => _spring(_press, ControlMetrics.press, 0)
          : null,
      child: Opacity(
        opacity: _enabled ? 1 : 0.5,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : _count * 80.0;
            _segmentWidth = width / _count;
            return SizedBox(
              width: width,
              height: ControlMetrics.segmentedHeight,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: track,
                ),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_x, _press]),
                  builder: (context, _) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left:
                            _x.value * _segmentWidth +
                            ControlMetrics.thumbInset,
                        width: _segmentWidth - ControlMetrics.thumbInset * 2,
                        top: ControlMetrics.thumbInset,
                        bottom: ControlMetrics.thumbInset,
                        child: GlassThumb(
                          pressed: _press.value,
                          color: thumb,
                          mode: widget.mode,
                        ),
                      ),
                      Positioned.fill(child: _labels(label)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _labels(Color color) => Row(
    children: [
      for (var i = 0; i < _count; i++)
        Expanded(
          child: Semantics(
            button: true,
            inMutuallyExclusiveGroup: true,
            selected: i == _selectedIndex,
            enabled: _enabled,
            label: widget.segments[i].semanticLabel,
            onTap: _enabled
                ? () => widget.onChanged!(widget.segments[i].value)
                : null,
            child: Center(
              child: DefaultTextStyle(
                style: IOSText.style(
                  ControlMetrics.segmentedFontSize,
                  // As SwiftUI: the selected segment semibold.
                  weight: i == _selectedIndex
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: IconTheme.merge(
                  data: IconThemeData(color: color, size: 18),
                  child: widget.segments[i].label,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
