import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show VerticalDragGestureRecognizer;
import 'package:flutter/physics.dart';

import '../core/glass.dart';
import '../core/glass_render_mode.dart';
import 'glass_sheet.dart';
import 'glass_sheet_detent.dart';
import 'measure_height.dart';
import 'sheet_metrics.dart';

/// A presented sheet: rests at one of its [detents], follows a vertical
/// drag between them, and is dismissed by a drag (or fling) below the
/// lowest. Without detents it is as tall as its content and only drags
/// down to dismiss.
class GlassSheetFrame extends StatefulWidget {
  /// Creates the frame.
  const GlassSheetFrame({
    super.key,
    required this.child,
    required this.detents,
    required this.initialDetent,
    required this.onDismiss,
    required this.showGrabber,
    required this.isDismissible,
    this.cornerRadius,
    this.grabberSize,
    this.glass,
    this.mode,
  });

  /// The sheet's content.
  final Widget child;

  /// The heights the sheet rests at, lowest first; empty sizes it to its
  /// content.
  final List<GlassSheetDetent> detents;

  /// The index into [detents] the sheet opens at.
  final int initialDetent;

  /// Called when a drag dismisses the sheet.
  final VoidCallback onDismiss;

  /// Whether the sheet has a grabber.
  final bool showGrabber;

  /// Whether a drag down may dismiss the sheet.
  final bool isDismissible;

  /// See [GlassSheet.cornerRadius].
  final double? cornerRadius;

  /// See [GlassSheet.grabberSize].
  final Size? grabberSize;

  /// The sheet's glass.
  final Glass? glass;

  /// The rendering path.
  final GlassRenderMode? mode;

  @override
  State<GlassSheetFrame> createState() => _GlassSheetFrameState();
}

class _GlassSheetFrameState extends State<GlassSheetFrame>
    with SingleTickerProviderStateMixin {
  /// The sheet's height above the screen's bottom, or (without detents)
  /// its drag offset below its resting place.
  late final AnimationController _height = AnimationController.unbounded(
    vsync: this,
  );

  bool _placed = false;
  List<double> _stops = const [];
  double _contentHeight = 0;

  bool get _sized => widget.detents.isEmpty;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void dispose() {
    _height.dispose();
    super.dispose();
  }

  void _spring(double target, double velocity) {
    if (_reduceMotion) {
      _height.value = target;
      return;
    }
    _height
        .animateWith(
          SpringSimulation(
            SheetMetrics.spring,
            _height.value,
            target,
            velocity,
          ),
        )
        .whenComplete(() {
          if (mounted) _height.value = target;
        });
  }

  void _drag(DragUpdateDetails d) {
    _height.stop();
    if (_sized) {
      // Down only, with resistance upwards.
      final next = _height.value + d.delta.dy;
      _height.value = next < 0 ? next * 0.3 : next;
      return;
    }
    var next = _height.value - d.delta.dy;
    final top = _stops.last;
    if (next > top) next = top + (next - top) * 0.3;
    _height.value = next;
  }

  void _end(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dy;
    if (_sized) {
      final dismiss =
          widget.isDismissible &&
          (v > SheetMetrics.flingVelocity ||
              _height.value > _contentHeight * SheetMetrics.dismissFraction);
      return dismiss ? widget.onDismiss() : _spring(0, -v);
    }
    final h = _height.value;
    final lowest = _stops.first;
    if (widget.isDismissible &&
        (h < lowest * (1 - SheetMetrics.dismissFraction) ||
            (v > SheetMetrics.flingVelocity && h <= lowest + 1))) {
      return widget.onDismiss();
    }
    double target;
    if (v.abs() > SheetMetrics.flingVelocity) {
      // A fling goes to the next detent in its direction.
      target = v < 0
          ? _stops.firstWhere((s) => s > h + 1, orElse: () => _stops.last)
          : _stops.lastWhere((s) => s < h - 1, orElse: () => _stops.first);
    } else {
      target = _stops.reduce((a, b) => (a - h).abs() < (b - h).abs() ? a : b);
    }
    _spring(target, -v);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final top = media.padding.top;
    final gestures = <Type, GestureRecognizerFactory>{
      VerticalDragGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
            VerticalDragGestureRecognizer.new,
            (r) => r
              ..onUpdate = _drag
              ..onEnd = _end,
          ),
    };
    if (_sized) {
      return AnimatedBuilder(
        animation: _height,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, _height.value), child: child),
        // Only the sheet takes the drag: taps around it reach the barrier.
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: size.height - top),
            child: RawGestureDetector(
              gestures: gestures,
              behavior: HitTestBehavior.opaque,
              child: MeasureHeight(
                onHeight: (h) => _contentHeight = h,
                child: GlassSheet(
                  showGrabber: widget.showGrabber,
                  cornerRadius: widget.cornerRadius,
                  grabberSize: widget.grabberSize,
                  glass: widget.glass,
                  mode: widget.mode,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      );
    }
    _stops = [for (final d in widget.detents) d.resolve(size, top)]..sort();
    if (!_placed) {
      _height.value = _stops[widget.initialDetent.clamp(0, _stops.length - 1)];
      _placed = true;
    }
    final medium = GlassSheetDetent.medium.resolve(size, top);
    final large = GlassSheetDetent.large.resolve(size, top);
    return AnimatedBuilder(
      animation: _height,
      builder: (context, _) {
        final h = _height.value.clamp(0.0, size.height);
        final expansion = large <= medium
            ? 1.0
            : ((h - medium) / (large - medium)).clamp(0.0, 1.0);
        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: h,
            width: size.width,
            child: RawGestureDetector(
              gestures: gestures,
              behavior: HitTestBehavior.opaque,
              child: GlassSheet(
                showGrabber: widget.showGrabber,
                cornerRadius: widget.cornerRadius,
                grabberSize: widget.grabberSize,
                expansion: expansion,
                glass: widget.glass,
                mode: widget.mode,
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}
