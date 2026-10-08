import 'dart:math' as math;

import 'package:flutter/cupertino.dart'
    show CupertinoSliverRefreshControl, RefreshIndicatorMode;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart';

import '../core/glass_render_mode.dart';
import 'glass_refresh_indicator.dart';
import 'refresh_metrics.dart';

/// iOS 26's pull to refresh as a sliver, like SwiftUI's `.refreshable`:
/// put it first in a [CustomScrollView]'s `slivers`.
///
/// ```dart
/// CustomScrollView(
///   physics: const AlwaysScrollableScrollPhysics(
///     parent: BouncingScrollPhysics(),
///   ),
///   slivers: [
///     SliverGlassRefresh(onRefresh: () => reload()),
///     SliverList.list(children: [...]),
///   ],
/// )
/// ```
///
/// The scrollable must be able to overscroll from the top, so it needs
/// `BouncingScrollPhysics` (e.g. `AlwaysScrollableScrollPhysics(parent:
/// BouncingScrollPhysics())`); with clamping physics the control never
/// arms. On the Material path the same sliver is used — a sliver cannot
/// host Material's `RefreshIndicator` — and the indicator's own Material
/// path shows a `CircularProgressIndicator`.
class SliverGlassRefresh extends StatefulWidget {
  /// Creates the sliver.
  const SliverGlassRefresh({
    super.key,
    required this.onRefresh,
    this.color,
    this.semanticLabel,
    this.enableFeedback = true,
    this.mode,
  });

  /// Called once per pull past the threshold; the indicator stays until
  /// the future completes.
  final Future<void> Function() onRefresh;

  /// The ring's / spinner's fill. Defaults to system blue.
  final Color? color;

  /// Announced while refreshing. Defaults to 'Refreshing'.
  final String? semanticLabel;

  /// Whether arming plays a haptic (`HapticFeedback.mediumImpact`).
  final bool enableFeedback;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<SliverGlassRefresh> createState() => _SliverGlassRefreshState();
}

class _SliverGlassRefreshState extends State<SliverGlassRefresh> {
  @override
  Widget build(BuildContext context) => CupertinoSliverRefreshControl(
    refreshTriggerPullDistance: RefreshMetrics.triggerDistance,
    refreshIndicatorExtent: RefreshMetrics.indicatorExtent,
    onRefresh: () {
      if (widget.enableFeedback) HapticFeedback.mediumImpact();
      return widget.onRefresh();
    },
    builder:
        (
          context,
          refreshState,
          pulledExtent,
          triggerDistance,
          indicatorExtent,
        ) {
          final refreshing =
              refreshState == RefreshIndicatorMode.armed ||
              refreshState == RefreshIndicatorMode.refresh ||
              refreshState == RefreshIndicatorMode.done;
          return SizedBox(
            height: pulledExtent,
            child: ClipRect(
              child: OverflowBox(
                minHeight: 0,
                maxHeight: math.max(pulledExtent, indicatorExtent),
                child: Center(
                  child: GlassRefreshIndicator(
                    progress: pulledExtent / triggerDistance,
                    refreshing: refreshing,
                    color: widget.color,
                    semanticLabel: widget.semanticLabel,
                    mode: widget.mode,
                  ),
                ),
              ),
            ),
          );
        },
  );
}
