import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, VelocityTracker;
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/glass_colors.dart';
import 'glass_swipe_action.dart';
import 'swipe_action_button.dart';
import 'swipe_metrics.dart';

part 'swipe_approach.dart';

/// iOS 26's list swipe actions: swipe a row aside to reveal tinted
/// capsules at its [leading] or [trailing] edge, laid out as SwiftUI's
/// `.swipeActions` (`SwipeMetrics`): icon and label inside the capsule in
/// a short row, the label under an icon-only capsule in a tall one.
///
/// ```dart
/// GlassSwipeActions(
///   key: ValueKey(item.id),
///   trailing: [
///     GlassSwipeAction(
///       icon: CupertinoIcons.trash,
///       label: 'Delete',
///       color: GlassSystemColors.red,
///       onPressed: () => delete(item),
///     ),
///   ],
///   child: ItemRow(item),
/// )
/// ```
///
/// The row follows the finger and springs open or shut when let go; the
/// actions grow in place as the row uncovers them, and the row turns into
/// a rounded platter. With [allowsFullSwipe], swiping past most of the
/// row runs the edge-most action (the first in the list), with a haptic as
/// the swipe passes that point; a [GlassSwipeAction.destructive] one
/// slides the row away and collapses it first, as SwiftUI does. A tap on the open row, a scroll, or
/// opening another row closes it. The first action sits at the row's
/// edge; edges follow the reading direction. Assistive tech gets the
/// actions as custom actions on the row. Give each row a key so an open
/// row stays with its item.
class GlassSwipeActions extends StatefulWidget {
  /// Creates a swipeable row.
  const GlassSwipeActions({
    super.key,
    required this.child,
    this.leading = const [],
    this.trailing = const [],
    this.allowsFullSwipe = true,
    this.fullSwipeThreshold = SwipeMetrics.fullSwipe,
  }) : assert(
         fullSwipeThreshold > 0 && fullSwipeThreshold <= 1,
         'fullSwipeThreshold is a fraction of the row width.',
       );

  /// The row.
  final Widget child;

  /// Actions revealed by swiping towards the trailing edge, at the
  /// leading edge; the first is outermost.
  final List<GlassSwipeAction> leading;

  /// Actions revealed by swiping towards the leading edge, at the
  /// trailing edge; the first is outermost.
  final List<GlassSwipeAction> trailing;

  /// Whether a long swipe runs the first action of that side.
  final bool allowsFullSwipe;

  /// The fraction of the row's width past which a swipe is a full swipe
  /// (see [allowsFullSwipe]).
  final double fullSwipeThreshold;

  /// Closes whichever row is open (when the list's filter changes, say).
  static void closeAll() => _GlassSwipeActionsState._active.value = null;

  @override
  State<GlassSwipeActions> createState() => _GlassSwipeActionsState();
}

class _GlassSwipeActionsState extends State<GlassSwipeActions>
    with TickerProviderStateMixin {
  /// The row that is open or being swiped; opening another closes it.
  static final ValueNotifier<Object?> _active = ValueNotifier(null);

  /// The row's offset towards the trailing edge (negative reveals the
  /// trailing actions), in logical pixels.
  late final AnimationController _offset;

  /// The platter behind the swiped row: 0 none, 1 full. Time-driven.
  late final AnimationController _platter;

  /// The row's height factor: a destructive full swipe collapses it.
  late final AnimationController _collapse;

  /// Each action's size (0 to 1, outermost first), trailing the size the
  /// offset sets by [SwipeMetrics.growLag].
  final List<double> _grown = [];
  late final Ticker _growTicker;
  Duration _growLast = Duration.zero;
  final ValueNotifier<int> _growFrame = ValueNotifier(0);

  /// Each action's bounce about full size since its size reached it
  /// (null when not bouncing), and when it started.
  final List<SpringSimulation?> _bounces = [];
  final List<Duration> _bounceStart = [];

  /// Each action's growth speed on its last frame, before it stops at
  /// its size.
  final List<double> _rates = [];

  /// Each action's ramp (see [_ramps]) last frame, and its smoothed speed.
  final List<double> _rampLast = [];
  final List<double> _rampSpeeds = [];

  /// Each shown action's size with its bounce, outermost first.
  List<double> get _sizes => [
    for (var k = 0; k < _grown.length; k++) _grown[k] + _bounceAt(k),
  ];

  /// Full size, within the growth's snap.
  static const double _full = 0.998;

  double _bounceAt(int k) {
    final b = k < _bounces.length ? _bounces[k] : null;
    if (b == null) return 0;
    return b.x((_growLast - _bounceStart[k]).inMicroseconds / 1e6);
  }

  /// The actions as the row closes: 1 shown, 0 shrunk and faded.
  late final AnimationController _closing;

  /// The row is springing open: the actions grow to full on their own.
  bool _opening = false;

  /// A destructive full swipe has taken the row: it is hidden.
  bool _gone = false;

  /// The drag's own offset, before the rubber band.
  double _drag = 0;
  double _width = 0;

  /// A full swipe has taken the row.
  bool _taken = false;

  /// Finger travel still to drop before the row moves, past the touch
  /// slop the recognizer already took.
  double _slack = 0;

  /// The drag that took the row no longer moves it.
  bool _dragDone = false;

  /// The finger's speed, to tell a full swipe from a slow pull.
  VelocityTracker _tracker = VelocityTracker.withKind(PointerDeviceKind.touch);
  ScrollPosition? _scroll;

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// The row's height, read when a drag starts (size is not readable
  /// during build).
  double _rowHeight = 0;

  /// Whether the row is tall enough for SwiftUI's stacked actions.
  bool get _stacked => _rowHeight >= SwipeMetrics.stackedRowHeight;

  /// Whether the stacked actions are circles centred with their labels.
  bool get _circles => _rowHeight >= SwipeMetrics.circleRowHeight;

  /// Each action's width on one side: SwiftUI gives them all the width of
  /// the widest.
  double _actionWidth(List<GlassSwipeAction> actions) {
    if (_circles) return SwipeMetrics.stackedCircle;
    if (_stacked) return SwipeMetrics.stackedWidth;
    // Measured in the style the label is drawn in (it inherits the font).
    final style = DefaultTextStyle.of(context).style.merge(SwipeMetrics.label);
    var widest = 0.0;
    for (final action in actions) {
      final painter = TextPainter(
        text: TextSpan(text: action.label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return SwipeMetrics.compactIconWidth +
        SwipeMetrics.compactIconGap +
        widest +
        (SwipeMetrics.compactPadding - SwipeMetrics.compactLabelBearing) * 2;
  }

  /// How far the row moves to open [actions]: the actions, and a gap
  /// before, between and after them.
  double _extent(List<GlassSwipeAction> actions) =>
      actions.length * _actionWidth(actions) +
      (actions.length + 1) * SwipeMetrics.gap;

  List<GlassSwipeAction> get _shown =>
      _offset.value < 0 ? widget.trailing : widget.leading;

  /// Whether the row is past the full-swipe point. SwiftUI takes the row
  /// only when it gets there fast ([SwipeMetrics.fullSwipeVelocity]); a
  /// slow pull past it just stretches the action, and opens on release.
  bool get _pastFullSwipe =>
      widget.allowsFullSwipe &&
      _width > 0 &&
      _offset.value.abs() > _width * widget.fullSwipeThreshold;

  @override
  void initState() {
    super.initState();
    _offset = AnimationController.unbounded(vsync: this)
      ..addListener(_onOffset);
    _platter = AnimationController.unbounded(vsync: this);
    _collapse = AnimationController(vsync: this, value: 1);
    _growTicker = createTicker(_stepGrow);
    _closing = AnimationController(
      vsync: this,
      value: 1,
      duration: SwipeMetrics.closeFade,
    );
    _active.addListener(_onActive);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scroll?.isScrollingNotifier.removeListener(_onScroll);
    _scroll = Scrollable.maybeOf(context)?.position;
    _scroll?.isScrollingNotifier.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll?.isScrollingNotifier.removeListener(_onScroll);
    _active.removeListener(_onActive);
    if (_active.value == this) _active.value = null;
    _offset.dispose();
    _platter.dispose();
    _collapse.dispose();
    _growTicker.dispose();
    _closing.dispose();
    _growFrame.dispose();
    super.dispose();
  }

  void _onActive() {
    if (_active.value != this && _offset.value != 0) _settle(0);
  }

  void _onScroll() {
    if (_scroll?.isScrollingNotifier.value ?? false) _settle(0);
  }

  void _onOffset() {
    final targets = _growTargets();
    if (_reduceMotion || _grown.length != targets.length) {
      _grown
        ..clear()
        ..addAll(targets);
    } else if (!_growTicker.isActive) {
      _growLast = Duration.zero;
      _growTicker.start();
    }
  }

  /// Eases each action's size towards the size the offset sets.
  void _stepGrow(Duration elapsed) {
    final dt = (elapsed - _growLast).inMicroseconds / 1e6;
    _growLast = elapsed;
    final targets = _growTargets();
    if (_grown.length != targets.length) {
      _grown
        ..clear()
        ..addAll(targets);
    }
    // A short lag, and no faster than SwiftUI's growth rate: a fast drag
    // outruns it, a slow one does not.
    final keep = math.exp(-dt / SwipeMetrics.growLag);
    final step = SwipeMetrics.growRate * dt;
    if (_bounces.length != targets.length) {
      _bounces
        ..clear()
        ..addAll(List.filled(targets.length, null));
      _bounceStart
        ..clear()
        ..addAll(List.filled(targets.length, Duration.zero));
      _rates
        ..clear()
        ..addAll(List.filled(targets.length, 0));
      _rampSpeeds
        ..clear()
        ..addAll(List.filled(targets.length, 0));
      _rampLast.clear();
    }
    final ramps = _opening || _width == 0 ? null : _ramps();
    if (ramps != null && ramps.length == targets.length) {
      if (_rampLast.length == ramps.length && dt > 0) {
        final blend = 1 - math.exp(-dt / SwipeMetrics.rampSpeedTime);
        for (var k = 0; k < ramps.length; k++) {
          final speed = (ramps[k] - _rampLast[k]) / dt;
          _rampSpeeds[k] += (speed - _rampSpeeds[k]) * blend;
        }
      }
      _rampLast
        ..clear()
        ..addAll(ramps);
    } else {
      _rampLast.clear();
    }
    var settled = true;
    for (var k = 0; k < targets.length; k++) {
      final was = _grown[k];
      final eased = targets[k] + (was - targets[k]) * keep;
      var move = (eased - was).clamp(-step, step);
      // Growing, it runs on into its size rather than easing in, as
      // SwiftUI's does; its speed then is the bounce's start.
      if (targets[k] > was) {
        // Springing open it runs on at a set speed; dragged, at a share
        // of the drag's speed along its ramp.
        final floor = _opening
            ? SwipeMetrics.openGrowFloor
            : SwipeMetrics.dragGrowFloor *
                  _rampSpeeds[k].clamp(0.0, SwipeMetrics.rampSpeedMax);
        move = math.max(move, floor * dt);
        if (dt > 0) _rates[k] = move / dt;
        move = math.min(move, targets[k] - was);
      }
      final next = was + move;
      _grown[k] = (next - targets[k]).abs() < 0.002 ? targets[k] : next;
      if (_grown[k] != targets[k]) settled = false;
      // Reaching full size it bounces, as SwiftUI's, carrying on with
      // some of its speed.
      if (was < _full && _grown[k] >= _full && dt > 0) {
        _bounces[k] = SpringSimulation(
          SwipeMetrics.bounce,
          0,
          0,
          SwipeMetrics.bounceCarry * _rates[k],
        );
        _bounceStart[k] = elapsed;
      } else if (_grown[k] < _full) {
        _bounces[k] = null;
      }
      final b = _bounces[k];
      if (b != null) {
        if (b.isDone((elapsed - _bounceStart[k]).inMicroseconds / 1e6)) {
          _bounces[k] = null;
        } else {
          settled = false;
        }
      }
    }
    _growFrame.value++;
    if (settled) _growTicker.stop();
  }

  /// The size (0 to 1) the offset sets for each shown action, outermost
  /// first: each grows in place as its slot is uncovered.
  List<double> _growTargets() {
    if (_offset.value == 0 || _width == 0) return const [];
    // Once the row is springing open, every action grows to full.
    if (_opening) return List.filled(_shown.length, 1);
    return [for (final t in _ramps()) t.clamp(0.0, 1.0)];
  }

  /// Where the offset is along each shown action's growth ramp: 0 at its
  /// start, 1 at its slot uncovered, and beyond either end.
  List<double> _ramps() {
    final actions = _shown;
    const gap = SwipeMetrics.gap;
    final w = _actionWidth(actions);
    final reveal = _offset.value.abs();
    return [
      for (var k = 0; k < actions.length; k++)
        () {
          final slotFull = (k + 1) * (w + gap) + gap;
          final start = math.min(
            k * (w + gap) + gap + SwipeMetrics.revealLead,
            slotFull - 1,
          );
          return (reveal - start) / (slotFull - start);
        }(),
    ];
  }

  /// Each shown action's opacity (outermost first): from
  /// [SwipeMetrics.revealOpacity] as it starts to grow to 1 as its slot
  /// is uncovered, following the offset without the size's lag (the best
  /// fit of SwiftUI's frames).
  List<double> _opacities() => [
    for (final grown in _growTargets())
      SwipeMetrics.revealOpacity + (1 - SwipeMetrics.revealOpacity) * grown,
  ];

  /// The actions' sizes and opacities as the row began to close: they
  /// shrink and fade from there on their own clock, not with the row.
  List<double>? _closeSizes;
  List<double>? _closeOpacities;

  /// Fades the platter towards [target] on its own clock.
  void _fadePlatter(double target) {
    if (_reduceMotion) {
      _platter.value = target;
    } else if (_platter.value != target) {
      _platter.animateWith(_Approach(_platter.value, target));
    }
  }

  void _settle(double target, {double velocity = 0}) {
    _taken = false;
    _drag = target;
    _opening = target != 0;
    if (target == 0) {
      if (_active.value == this) _active.value = null;
      _fadePlatter(0);
      // The actions shrink and fade from the tap, under the closing row.
      if (_reduceMotion || _offset.value.abs() < 0.5) {
        _closing.value = 0;
      } else {
        _closeSizes = _sizes;
        _closeOpacities = _opacities();
        _closing.value = 1;
        _closing.animateTo(0);
      }
    } else {
      _closeSizes = _closeOpacities = null;
      _closing.value = 1;
    }
    if (_reduceMotion) {
      _offset.value = target;
    } else {
      _offset
          .animateWith(
            SpringSimulation(
              SwipeMetrics.spring,
              _offset.value,
              target,
              velocity,
            ),
          )
          // A spring stops within its tolerance, not on the target.
          .whenComplete(() {
            if (mounted) _offset.value = target;
          });
    }
  }

  /// [raw] with the rubber band past the actions, and nothing towards a
  /// side without actions.
  double _band(double raw) {
    final actions = raw < 0 ? widget.trailing : widget.leading;
    if (actions.isEmpty) return 0;
    final extent = _extent(actions);
    final reach = raw.abs();
    final free = widget.allowsFullSwipe ? _width : extent;
    final banded = reach <= free
        ? reach
        : free + (reach - free) * SwipeMetrics.resistance;
    return raw.sign * banded;
  }

  void _start(DragStartDetails _) {
    _rowHeight = context.size?.height ?? 0;
    _offset.stop();
    _drag = _offset.value;
    _opening = false;
    _dragDone = false;
    // From rest, SwiftUI drops a little more of the finger's travel.
    _slack = _offset.value == 0 ? SwipeMetrics.dragSlack : 0;
    _tracker = VelocityTracker.withKind(PointerDeviceKind.touch);
    _active.value = this;
    _fadePlatter(1);
    _closeSizes = _closeOpacities = null;
    _closing
      ..stop()
      ..value = 1;
  }

  void _update(DragUpdateDetails d) {
    if (_dragDone || _gone) return;
    var delta = _rtl ? -d.delta.dx : d.delta.dx;
    if (_slack > 0) {
      final taken = math.min(_slack, delta.abs());
      _slack -= taken;
      delta -= delta.sign * taken;
    }
    _drag += delta;
    _offset.value = _band(_drag);
    final time = d.sourceTimeStamp;
    if (time == null) return;
    _tracker.addPosition(time, Offset(_drag, 0));
    final velocity = _tracker.getVelocityEstimate()?.pixelsPerSecond.dx ?? 0;
    // Fast past the full-swipe point: the action takes the row mid-drag.
    _takeIfFast(velocity);
  }

  /// Takes the row with a full swipe when it is past the full-swipe point
  /// and moving outward fast enough.
  bool _takeIfFast(double velocity) {
    final offset = _offset.value;
    if (!_pastFullSwipe ||
        velocity.sign != offset.sign ||
        velocity.abs() < SwipeMetrics.fullSwipeVelocity) {
      return false;
    }
    _taken = _dragDone = true;
    HapticFeedback.mediumImpact();
    _run(_shown.first, full: true);
    return true;
  }

  void _end(DragEndDetails d) {
    if (_dragDone || _gone) return;
    final velocity = (_rtl ? -1 : 1) * d.velocity.pixelsPerSecond.dx;
    final offset = _offset.value;
    if (offset == 0) return _settle(0);
    final actions = _shown;
    if (_takeIfFast(velocity)) return;
    final extent = _extent(actions);
    final opening = velocity.abs() > SwipeMetrics.flingVelocity
        ? velocity.sign == offset.sign
        : offset.abs() > extent * SwipeMetrics.openFraction;
    _settle(opening ? offset.sign * extent : 0, velocity: velocity);
  }

  Future<void> _run(GlassSwipeAction action, {bool full = false}) async {
    final confirm = action.confirm;
    if (confirm != null) {
      // The row holds where it is while the app asks.
      _offset.stop();
      final confirmed = await confirm();
      if (!mounted) return;
      if (!confirmed) return _settle(0);
    }
    if (!full) {
      _settle(0);
      action.onPressed();
      return;
    }
    final target = _offset.value.sign * _width;
    if (!action.destructive) {
      // The row slides out of the way, then the action runs.
      if (_reduceMotion) {
        _offset.value = target;
      } else {
        await _offset
            .animateWith(
              SpringSimulation(SwipeMetrics.spring, _offset.value, target, 0),
            )
            .orCancel
            .catchError((_) {});
      }
      if (!mounted) return;
      action.onPressed();
      if (mounted) _settle(0);
      return;
    }
    // A destructive action takes the row with it, as SwiftUI's: the row
    // is gone at once, the action filling its place and following on
    // out, and the row collapses; then the app removes the item.
    setState(() => _gone = true);
    if (_reduceMotion) {
      _offset.value = target;
      _collapse.value = 0;
    } else {
      // The row jumps most of the way out, then glides on to the edge,
      // the action following it, while the row collapses.
      _offset.value = target * SwipeMetrics.exitJump;
      _offset.animateWith(
        SpringSimulation(
          SwipeMetrics.exitSpring,
          _offset.value,
          target,
          target.sign * SwipeMetrics.exitVelocity,
        ),
      );
      await _collapse
          .animateWith(SpringSimulation(SwipeMetrics.collapse, 1, 0, 0))
          .orCancel
          .catchError((_) {});
    }
    if (!mounted) return;
    action.onPressed();
    // Still here a frame later: the app kept the item, so the row
    // returns.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _offset.stop();
      _gone = _taken = false;
      _collapse.value = 1;
      _closing.value = 1;
      _platter.value = 0;
      _drag = 0;
      _offset.value = 0;
      if (_active.value == this) _active.value = null;
    });
  }

  @override
  Widget build(BuildContext context) => Semantics(
    customSemanticsActions: {
      for (final a in [...widget.leading, ...widget.trailing])
        CustomSemanticsAction(label: a.label): () => _run(a),
    },
    // Collapses from the bottom, the row's top staying put.
    child: AnimatedBuilder(
      animation: _collapse,
      builder: (context, child) => _collapse.value == 1
          ? child!
          : ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: _collapse.value,
                child: child,
              ),
            ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _start,
            onHorizontalDragUpdate: _update,
            onHorizontalDragEnd: _end,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _offset,
                _platter,
                _growFrame,
                _closing,
              ]),
              builder: (context, child) => _layout(child!),
              child: widget.child,
            ),
          );
        },
      ),
    ),
  );

  Widget _layout(Widget child) {
    final offset = _offset.value;
    final open = offset.abs() > 0.5;
    final fade = _platter.value.clamp(0.0, 1.0);
    // SwiftUI: #E5E5EA in light mode, the system's grey 5. It fades by its
    // own opacity (lerping from transparent black would grey it).
    final platter = CupertinoDynamicColor.resolve(
      GlassColors.swipePlatter,
      context,
    );
    final row = DecoratedBox(
      decoration: ShapeDecoration(
        color: platter.withValues(alpha: platter.a * fade),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(SwipeMetrics.rowRadius * fade),
        ),
      ),
      child: child,
    );
    return Stack(
      children: [
        if (open) ..._actions(offset),
        // Gone, the row keeps its size (the collapse needs it) unseen.
        Opacity(
          opacity: _gone ? 0 : 1,
          child: Transform.translate(
            offset: Offset(_rtl ? -offset : offset, 0),
            // While open, a tap on the row closes it instead of reaching it.
            child: open
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _settle(0),
                    child: AbsorbPointer(child: row),
                  )
                : row,
          ),
        ),
      ],
    );
  }

  /// The actions in the space the row has uncovered, as SwiftUI places
  /// them: each grows in place at its resting spot as its slot is
  /// uncovered; past rest the inner ones keep to the row (fading) and the
  /// outermost stretches; past the full-swipe point it takes it all.
  List<Widget> _actions(double offset) {
    final actions = _shown;
    final n = actions.length;
    const gap = SwipeMetrics.gap;
    final w = _actionWidth(actions);
    final reveal = offset.abs();
    final rest = _extent(actions);
    final full = _taken;
    // Actions at the right screen edge (the row to their left).
    final atRight = (offset < 0) != _rtl;
    final rowHeight = _rowHeight;
    final double h;
    final double top;
    var labelGap = SwipeMetrics.stackedLabelGap;
    if (_circles) {
      h = SwipeMetrics.stackedCircle;
      labelGap = SwipeMetrics.circleLabelGap;
      top = (rowHeight - (h + labelGap + SwipeMetrics.stackedLabelHeight)) / 2;
    } else if (_stacked) {
      h = SwipeMetrics.stackedHeight;
      top = SwipeMetrics.stackedInset;
    } else {
      h = rowHeight - SwipeMetrics.compactInset * 2;
      top = SwipeMetrics.compactInset;
    }
    final groupHeight = _stacked
        ? h + labelGap + SwipeMetrics.stackedLabelHeight
        : h;
    final buttons = <Widget>[];
    // From the screen edge in: the first action is outermost.
    // The opacity follows the offset; only the size lags. Closing, both
    // run down from where they were.
    final sizes = _closeSizes ?? _sizes;
    final opacities = _closeOpacities ?? _opacities();
    for (var k = 0; k < n; k++) {
      // Past the full-swipe point the outermost takes over at once.
      final grown = full && k == 0 ? 1.0 : (k < sizes.length ? sizes[k] : 0.0);
      if (grown == 0) continue;
      // Closing, the inner actions go in the first part of the outer's
      // time.
      final closing = k == 0
          ? _closing.value
          : ((_closing.value - 1 + SwipeMetrics.innerCloseFraction) /
                    SwipeMetrics.innerCloseFraction)
                .clamp(0.0, 1.0);
      if (closing == 0) continue;
      // Closing, they shrink to nothing while fading to about 0.4.
      var opacity =
          (full && k == 0 ? 1.0 : (k < opacities.length ? opacities[k] : 1.0)) *
          (SwipeMetrics.closeOpacity +
              (1 - SwipeMetrics.closeOpacity) * closing);
      // Distance of the action's edge-side from the screen edge.
      var near = gap + k * (w + gap);
      var width = w;
      if (reveal > rest) {
        // The inner ones keep to the row, fading; the outermost stretches
        // to meet them (past the full-swipe point too).
        if (k == 0) {
          width = w + reveal - rest;
        } else {
          final past = reveal - rest;
          near += past;
          opacity *=
              SwipeMetrics.innerFade +
              (1 - SwipeMetrics.innerFade) *
                  math.exp(-past / SwipeMetrics.innerFadeDistance) -
              SwipeMetrics.innerFadeTail * ((past - 20) / 60).clamp(0.0, 1.0);
        }
      }
      final action = actions[k];
      buttons.add(
        Positioned(
          left: atRight ? _width - near - width : near,
          top: top,
          width: width,
          height: groupHeight,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: grown * closing,
              child: SwipeActionButton(
                action: action,
                stacked: _stacked,
                width: width,
                naturalWidth: w,
                height: h,
                rowOnLeft: atRight,
                labelGap: labelGap,
                taken: full && k == 0,
                onPressed: () => _run(action),
              ),
            ),
          ),
        ),
      );
    }
    return buttons;
  }
}
