import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Card, Theme;

import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import 'glass_tip.dart';
import 'glass_tip_controller.dart';
import 'tip_body.dart';
import 'tip_metrics.dart';

/// An inline tip, like TipKit's `TipView`: a rounded platter with the
/// tip's image, title, message, actions and a close button, placed in your
/// layout (e.g. at the top of a list).
///
/// ```dart
/// GlassTipView(tip: favoriteTip, controller: favoriteTipController)
/// ```
///
/// The close button dismisses the [controller] with
/// [GlassTipDismissReason.closed]; the tip then collapses (at once under
/// Reduce Motion) and builds nothing until the controller is reset. With
/// no controller the tip keeps its own state for this widget's lifetime.
/// Like TipKit's, the platter is opaque (systemGray6), not glass. On the
/// Material path it is a Material 3 card.
class GlassTipView extends StatefulWidget {
  /// Creates an inline tip.
  const GlassTipView({
    super.key,
    required this.tip,
    this.controller,
    this.closeLabel = 'Close',
    this.mode,
  });

  /// What the tip says.
  final GlassTip tip;

  /// Whether the tip shows; share it with a `GlassPopoverTip` of the same
  /// tip, and persist it through [GlassTipController.onDismissed].
  final GlassTipController? controller;

  /// The close button's accessibility label; pass your localised "Close".
  final String closeLabel;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassTipView> createState() => _GlassTipViewState();
}

class _GlassTipViewState extends State<GlassTipView> {
  GlassTipController? _local;

  GlassTipController get _controller =>
      widget.controller ?? (_local ??= GlassTipController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(GlassTipView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.controller ?? _local;
    if (!identical(old, _controller)) {
      old?.removeListener(_changed);
      _controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _local?.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final child = _controller.isDismissed
        ? const SizedBox(key: ValueKey(false), width: double.infinity)
        : KeyedSubtree(key: const ValueKey(true), child: _tip());
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
      child: child,
    );
  }

  Widget _tip() => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, effective) {
      final material = effective == EffectiveGlassMode.material;
      final body = TipBody(
        tip: widget.tip,
        onClose: _controller.dismiss,
        closeLabel: widget.closeLabel,
        material: material,
      );
      if (material) {
        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: body,
        );
      }
      return Semantics(
        container: true,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: CupertinoDynamicColor.resolve(
              TipMetrics.background,
              context,
            ),
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(TipMetrics.cornerRadius),
              side: BorderSide(
                color: CupertinoDynamicColor.resolve(
                  TipMetrics.border,
                  context,
                ),
                width: TipMetrics.borderWidth,
              ),
            ),
          ),
          child: body,
        ),
      );
    },
  );
}
