import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/glass_colors.dart';
import '../core/glass_render_mode.dart';
import 'glass_swipe_action.dart';
import 'swipe_action_button.dart';
import 'swipe_metrics.dart';

/// iOS 26's list swipe actions: swipe a row aside to reveal tinted glass
/// capsules at its [leading] or [trailing] edge.
///
/// ```dart
/// GlassSwipeActions(
///   key: ValueKey(item.id),
///   trailing: [
///     GlassSwipeAction(
///       icon: CupertinoIcons.trash,
///       label: 'Delete',
///       color: CupertinoColors.systemRed,
///       onPressed: () => delete(item),
///     ),
///   ],
///   child: ItemRow(item),
/// )
/// ```
///
/// The row follows the finger, resists past its actions, and springs open
/// or shut when let go. With [allowsFullSwipe], swiping past most of the
/// row runs the edge-most action (the first in the list), with a haptic as
/// the swipe passes that point. A tap on the open row, a scroll, or
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
    this.mode,
  });

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

  /// The rendering path for the action capsules; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassSwipeActions> createState() => _GlassSwipeActionsState();
}

class _GlassSwipeActionsState extends State<GlassSwipeActions>
    with SingleTickerProviderStateMixin {
  /// The row that is open or being swiped; opening another closes it.
  static final ValueNotifier<Object?> _active = ValueNotifier(null);

  /// The row's offset towards the trailing edge (negative reveals the
  /// trailing actions), in logical pixels.
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  )..addListener(_onOffset);

  /// The drag's own offset, before the rubber band.
  double _drag = 0;
  double _width = 0;
  bool _pastFullSwipe = false;
  ScrollPosition? _scroll;

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  double _extent(List<GlassSwipeAction> actions) =>
      actions.length * SwipeMetrics.actionExtent + SwipeMetrics.gap;

  List<GlassSwipeAction> get _shown =>
      _offset.value < 0 ? widget.trailing : widget.leading;

  bool get _fullSwipe =>
      widget.allowsFullSwipe &&
      _width > 0 &&
      _offset.value.abs() > _width * SwipeMetrics.fullSwipe;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _onActive() {
    if (_active.value != this && _offset.value != 0) _settle(0);
  }

  void _onScroll() {
    if (_scroll?.isScrollingNotifier.value ?? false) _settle(0);
  }

  void _onOffset() {
    final past = _fullSwipe;
    if (past != _pastFullSwipe) {
      _pastFullSwipe = past;
      if (past) HapticFeedback.mediumImpact();
    }
  }

  void _settle(double target, {double velocity = 0}) {
    _drag = target;
    if (target == 0 && _active.value == this) _active.value = null;
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
    _offset.stop();
    _drag = _offset.value;
    _active.value = this;
  }

  void _update(DragUpdateDetails d) {
    _drag += _rtl ? -d.delta.dx : d.delta.dx;
    _offset.value = _band(_drag);
  }

  void _end(DragEndDetails d) {
    final velocity = (_rtl ? -1 : 1) * d.velocity.pixelsPerSecond.dx;
    final offset = _offset.value;
    if (offset == 0) return _settle(0);
    final actions = _shown;
    if (_fullSwipe) return _run(actions.first, full: true);
    final extent = _extent(actions);
    final opening = velocity.abs() > SwipeMetrics.flingVelocity
        ? velocity.sign == offset.sign
        : offset.abs() > extent / 2;
    _settle(opening ? offset.sign * extent : 0, velocity: velocity);
  }

  void _run(GlassSwipeAction action, {bool full = false}) {
    if (full && !_reduceMotion) {
      // The row slides out of the way, then the action runs.
      final target = _offset.value.sign * _width;
      _offset
          .animateWith(
            SpringSimulation(SwipeMetrics.spring, _offset.value, target, 0),
          )
          .whenCompleteOrCancel(() {
            action.onPressed();
            if (mounted) _settle(0);
          });
      return;
    }
    _settle(0);
    action.onPressed();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    customSemanticsActions: {
      for (final a in [...widget.leading, ...widget.trailing])
        CustomSemanticsAction(label: a.label): () => _run(a),
    },
    child: LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _start,
          onHorizontalDragUpdate: _update,
          onHorizontalDragEnd: _end,
          child: AnimatedBuilder(
            animation: _offset,
            builder: (context, child) => _layout(child!),
            child: widget.child,
          ),
        );
      },
    ),
  );

  Widget _layout(Widget child) {
    final offset = _offset.value;
    final reveal = offset.abs();
    final open = reveal > 0.5;
    final progress = (reveal / SwipeMetrics.actionExtent).clamp(0.0, 1.0);
    final platter = CupertinoDynamicColor.resolve(
      CupertinoColors.secondarySystemGroupedBackground,
      context,
    );
    final row = DecoratedBox(
      decoration: ShapeDecoration(
        color: Color.lerp(GlassColors.transparent, platter, progress),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(
            SwipeMetrics.rowRadius * progress,
          ),
        ),
      ),
      child: child,
    );
    return Stack(
      children: [
        if (open) _actions(offset),
        Transform.translate(
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
      ],
    );
  }

  /// The actions in the space the row has uncovered.
  Widget _actions(double offset) {
    final actions = _shown;
    final width = offset.abs() - SwipeMetrics.gap;
    final full = _fullSwipe;
    // From the row towards the edge: the first action is outermost.
    final ordered = actions.reversed.toList();
    final items = <Widget>[
      for (var i = 0; i < ordered.length; i++) ...[
        if (i > 0) const SizedBox(width: SwipeMetrics.gap),
        Expanded(
          // Past the full-swipe point the outermost action takes it all.
          flex: full ? (i == ordered.length - 1 ? 1000 : 1) : 1,
          child: SwipeActionButton(
            action: ordered[i],
            mode: widget.mode,
            onPressed: () => _run(ordered[i]),
          ),
        ),
      ],
    ];
    // Narrower than the actions need, they keep their size and are
    // uncovered from the edge in.
    final natural =
        actions.length * SwipeMetrics.actionExtent - SwipeMetrics.gap;
    final shown = width < 0 ? 0.0 : width;
    final edge = offset < 0
        ? AlignmentDirectional.centerEnd
        : AlignmentDirectional.centerStart;
    return Positioned.fill(
      child: Align(
        alignment: edge,
        child: ClipRect(
          child: SizedBox(
            width: shown,
            child: OverflowBox(
              alignment: edge,
              minWidth: shown < natural ? natural : shown,
              maxWidth: shown < natural ? natural : shown,
              child: Row(
                textDirection: offset < 0
                    ? Directionality.of(context)
                    : (_rtl ? TextDirection.ltr : TextDirection.rtl),
                children: items,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
