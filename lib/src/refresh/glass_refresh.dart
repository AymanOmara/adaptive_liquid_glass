import 'dart:math' as math;

import 'package:flutter/material.dart' show RefreshIndicator;
import 'package:flutter/physics.dart' show SpringSimulation;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart';

import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/swiftui_spring.dart';
import 'glass_refresh_indicator.dart';
import 'glass_refresh_scroll_physics.dart';
import 'refresh_metrics.dart';
import 'uikit_pull_adapter.dart';

/// iOS 26's pull to refresh around any scrollable, like SwiftUI's
/// `.refreshable`.
///
/// ```dart
/// GlassRefresh(
///   onRefresh: () => reload(),
///   child: ListView(children: [...]),
/// )
/// ```
///
/// The indicator floats over the top of the content (the child keeps its
/// own layout), reveals its spokes with the pull and starts the refresh
/// with a haptic as soon as the pull passes the threshold.
/// While the refresh runs the content is held down by the spinner's room,
/// as `UIRefreshControl` holds a list, and it snaps back on SwiftUI's
/// spring once refresh completes. A scrollable that inherits bouncing
/// physics (iOS's default) gets UIScrollView's rubber band under the pull
/// ([GlassRefreshScrollPhysics]), so the content travels as far as iOS's
/// for the same finger travel; one that sets its own `BouncingScrollPhysics`
/// gets the same pull and bounce from its position. Measured against
/// SwiftUI's `.refreshable` List on iOS 26.4: the pull within 4 pt for
/// 50-300 pt of finger travel, the bounce back from a short pull within
/// 2.5 pt per frame, and a flick up past the top within 1.1 pt rms.
/// Clamping physics also work (the pull is then tracked from the
/// overscroll). On the Material path this is Material's
/// own [RefreshIndicator].
class GlassRefresh extends StatefulWidget {
  /// Creates the wrapper.
  const GlassRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
    this.semanticLabel,
    this.enableFeedback = true,
    this.edgeOffset,
    this.mode,
  });

  /// Called once per pull past the threshold; the indicator stays until
  /// the future completes.
  final Future<void> Function() onRefresh;

  /// The scrollable to wrap.
  final Widget child;

  /// The spinner's colour (the ring's on the Material path). Defaults to
  /// the system's.
  final Color? color;

  /// Announced while refreshing. Defaults to 'Refreshing'.
  final String? semanticLabel;

  /// Whether arming plays a haptic (`HapticFeedback.mediumImpact`).
  final bool enableFeedback;

  /// How far below the wrapper's top the indicator's room starts, as
  /// `UIRefreshControl` sits below the scroll view's top inset. Defaults
  /// to the top media padding, which a `ListView` without its own padding
  /// also insets by.
  final double? edgeOffset;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassRefresh> createState() => _GlassRefreshState();
}

class _GlassRefreshState extends State<GlassRefresh>
    with TickerProviderStateMixin {
  /// The pull progress, 0 to 1+; also the snap-back animation's value.
  late final AnimationController _controller;

  /// The overscroll past the top, in pixels.
  double _pull = 0;

  /// The finger's travel past the top during this drag, in pixels.
  double _travel = 0;

  /// The scrollable's signed overscroll past the top: positive while
  /// pulled, negative once scrolled into the content.
  final _overscroll = ValueNotifier<double>(0);

  bool _dragging = false;

  /// The refresh started under the finger: the release settles the hold.
  bool _settlePending = false;
  bool _refreshing = false;

  /// From the trigger until the snap-back settles: the content is held
  /// down by [_holdDepth].
  bool _holding = false;

  /// The hold's depth, in pixels: eases from the released pull into
  /// [RefreshMetrics.indicatorExtent], then springs back to 0.
  late final AnimationController _holdDepth;

  double get _hold => _holding ? _holdDepth.value : 0;

  /// A SwiftUI spring on [_holdDepth] from where it is to [target],
  /// landing exactly on it (a spring stops within its tolerance).
  Future<void> _springHold(double response, double damping, double target) =>
      _holdDepth
          .animateWith(
            SpringSimulation(
              swiftUISpring(response: response, dampingFraction: damping),
              _holdDepth.value,
              target,
              0,
            ),
          )
          .then((_) => _holdDepth.value = target);

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// UIKit's pull for a child that sets its own bouncing physics.
  final _pullAdapter = UIKitPullAdapter();

  /// Follows the first scrollable below, which reports at depth 0 (the
  /// first finger on it comes before any of its notifications).
  void _findScrollable() {
    ScrollableState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        found = element.state as ScrollableState;
      } else {
        element.visitChildren(visit);
      }
    }

    if (!mounted) return;
    context.visitChildElements(visit);
    _pullAdapter.attach(found);
  }

  void _findScrollableAfterFrame() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _findScrollable());

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    _pullAdapter.attach(
      notification.context?.findAncestorStateOfType<ScrollableState>(),
    );
    _overscroll.value =
        notification.metrics.minScrollExtent - notification.metrics.pixels;
    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _dragging = true;
        // A post-refresh snap-back keeps going under a new drag; the
        // held content would jump otherwise.
        if (!_holding) _controller.stop();
        _travel = 0;
        _pull = math.max(
          0,
          notification.metrics.minScrollExtent - notification.metrics.pixels,
        );
      }
    } else if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails == null && _dragging) {
        _dragging = false;
        _endDrag();
      } else {
        _pull = math.max(
          0,
          notification.metrics.minScrollExtent - notification.metrics.pixels,
        );
        final delta = notification.dragDetails?.delta.dy ?? 0;
        _travel = _pull > 0 ? math.max(0, _travel + delta) : 0;
      }
    } else if (notification is OverscrollNotification) {
      // Clamping physics never move the pixels past the extent; the
      // pull arrives as overscroll instead (negative at the top).
      _pull = math.max(0, _pull - notification.overscroll);
      _travel = _pull;
    } else if (notification is ScrollEndNotification) {
      if (_dragging) {
        _dragging = false;
        _endDrag();
      }
    }
    _updateProgress();
    return false;
  }

  /// While dragging and not refreshing, the pull drives the progress;
  /// past the threshold the refresh starts at once, finger still down, as
  /// `UIRefreshControl`'s does (measured), with a haptic.
  void _updateProgress() {
    if (!_dragging || _holding) return;
    // The finger's travel past the top arms it too, at the travel UIKit
    // needs for its 173 pt: a scrollable with its own bouncing physics
    // keeps Flutter's friction, which holds the content back harder.
    final progress = math.max(
      _pull / RefreshMetrics.triggerDistance,
      _travel / RefreshMetrics.triggerTravel,
    );
    _controller.value = progress;
    if (progress >= 1) {
      if (widget.enableFeedback) HapticFeedback.mediumImpact();
      _trigger();
    }
  }

  void _endDrag() {
    if (_settlePending) {
      _settlePending = false;
      _settle();
    } else if (!_holding && !_refreshing) {
      _snapBack();
    }
  }

  /// Starts the refresh: the indicator spins at full pull until
  /// [GlassRefresh.onRefresh] completes. Under the finger the content
  /// stays where it is pulled to (held no higher than the spinner's
  /// room); the release eases it into the hold.
  void _trigger() {
    setState(() {
      _refreshing = true;
      _holding = true;
      _controller.value = 1;
    });
    _holdDepth.value = RefreshMetrics.indicatorExtent;
    if (_dragging) {
      _settlePending = true;
    } else {
      _settle();
    }
    widget.onRefresh().whenComplete(() {
      if (mounted) _snapBack();
    });
  }

  /// The released content eases into the hold, as UIScrollView's bounce
  /// settles on its refresh inset.
  void _settle() {
    _holdDepth.value = math.max(_pull, RefreshMetrics.indicatorExtent);
    if (_reduceMotion) {
      _holdDepth.value = RefreshMetrics.indicatorExtent;
    } else {
      _springHold(
        RefreshMetrics.holdResponse,
        RefreshMetrics.holdDamping,
        RefreshMetrics.indicatorExtent,
      );
    }
  }

  /// Springs the progress back to 0, ending the refresh.
  void _snapBack() {
    _settlePending = false;
    if (_reduceMotion) {
      setState(() {
        _refreshing = false;
        _holding = false;
        _controller.value = 0;
        _holdDepth.value = 0;
      });
      return;
    }
    setState(() => _refreshing = false);
    if (_holding) {
      // The held content returns on the measured snap-back.
      _springHold(
        RefreshMetrics.snapResponse,
        RefreshMetrics.snapDamping,
        0,
      ).then((_) {
        _holding = false;
        _holdDepth.value = 0;
      });
    }
    _controller
        .animateWith(
          SpringSimulation(
            swiftUISpring(
              response: RefreshMetrics.snapResponse,
              dampingFraction: RefreshMetrics.snapDamping,
            ),
            _controller.value,
            0,
            0,
          ),
        )
        // The spring settles within its tolerance, not at 0; a value just
        // above 0 would leave the disk showing at its smallest scale.
        .then((_) => _controller.value = 0);
  }

  // Created here, not lazily: one first read in dispose would create
  // its ticker on a deactivated element.
  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this);
    _holdDepth = AnimationController.unbounded(vsync: this);
    _findScrollableAfterFrame();
  }

  @override
  void didUpdateWidget(GlassRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    _findScrollableAfterFrame();
  }

  @override
  void dispose() {
    _pullAdapter.dispose();
    _controller.dispose();
    _holdDepth.dispose();
    _overscroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? RefreshIndicator(
            onRefresh: widget.onRefresh,
            color: widget.color,
            semanticsLabel: widget.semanticLabel,
            child: widget.child,
          )
        : _glass(),
  );

  /// Gives a scrollable that inherits bouncing physics (iOS's default)
  /// UIScrollView's rubber band under the pull, as
  /// [GlassRefreshScrollPhysics]; clamping platforms keep theirs.
  Widget _rubberBand(BuildContext context, Widget child) {
    final behavior = ScrollConfiguration.of(context);
    final inherited = behavior.getScrollPhysics(context);
    if (inherited is! BouncingScrollPhysics ||
        inherited is GlassRefreshScrollPhysics) {
      return child;
    }
    // One behaviour per inherited one: a new one each frame would make
    // the scrollable replace its position on every frame of the pull.
    if (!identical(behavior, _bandFor)) {
      _bandFor = behavior;
      _band = behavior.copyWith(
        physics: GlassRefreshScrollPhysics(
          decelerationRate: inherited.decelerationRate,
          parent: inherited.parent,
        ),
      );
    }
    return ScrollConfiguration(behavior: _band!, child: child);
  }

  ScrollBehavior? _bandFor;
  ScrollBehavior? _band;

  /// The child is shifted down by what the hold adds beyond the pull
  /// (the release's bounce returns into the hold, not past it), clipped
  /// to the wrapper; while held, the spinner rides up with content
  /// scrolled into, as UIKit's content inset carries it.
  Widget _glass() => NotificationListener<ScrollNotification>(
    onNotification: _onScroll,
    child: AnimatedBuilder(
      animation: Listenable.merge([_controller, _holdDepth, _overscroll]),
      builder: (context, _) {
        final overscroll = _overscroll.value;
        final shift = math.max(0.0, _hold - math.max(0.0, overscroll));
        return Stack(
          children: [
            ClipRect(
              clipBehavior: shift == 0 ? Clip.none : Clip.hardEdge,
              child: Transform.translate(
                offset: Offset(0, shift),
                child: _rubberBand(context, widget.child),
              ),
            ),
            PositionedDirectional(
              top:
                  (widget.edgeOffset ?? MediaQuery.paddingOf(context).top) +
                  (_holding ? math.min(0.0, overscroll) : 0),
              start: 0,
              end: 0,
              height: RefreshMetrics.indicatorExtent,
              child: IgnorePointer(
                child: Center(
                  child: GlassRefreshIndicator(
                    progress: _controller.value,
                    refreshing: _refreshing,
                    color: widget.color,
                    semanticLabel: widget.semanticLabel,
                    mode: widget.mode,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
