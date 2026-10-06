import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Badge;

import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_system_colors.dart';
import 'badge_metrics.dart';

/// iOS 26's badge: a small solid red capsule with a count (a dot when
/// empty) on a child's top trailing corner, like UIKit's badge on a tab
/// icon.
///
/// ```dart
/// GlassBadge.count(count: unread, child: const Icon(CupertinoIcons.mail))
/// ```
///
/// iOS draws badges as solid system-red capsules, not glass. A hidden
/// badge leaves only the child. On the Material path it is a Material 3
/// [Badge].
class GlassBadge extends StatelessWidget {
  /// Creates a badge.
  const GlassBadge({
    super.key,
    this.label,
    this.child,
    this.isVisible = true,
    this.color,
    this.textColor,
    this.semanticLabel,
    this.mode,
  });

  /// A badge showing [count], capped as "[max]+" (e.g. 99+); hidden when
  /// [count] is 0 or less.
  factory GlassBadge.count({
    Key? key,
    required int count,
    int max = 99,
    Widget? child,
    Color? color,
    Color? textColor,
    String? semanticLabel,
    GlassRenderMode? mode,
  }) => GlassBadge(
    key: key,
    label: count > max ? '$max+' : '$count',
    isVisible: count > 0,
    color: color,
    textColor: textColor,
    semanticLabel: semanticLabel,
    mode: mode,
    child: child,
  );

  /// The text; null or empty draws a dot.
  final String? label;

  /// The widget the badge sits on; the badge stands alone when null.
  final Widget? child;

  /// Whether the badge shows; false shows only the child.
  final bool isVisible;

  /// The badge's colour; defaults to iOS's system red (the Material 3
  /// [Badge]'s default on Android).
  final Color? color;

  /// The text's colour; defaults to white (the Material default).
  final Color? textColor;

  /// What assistive tech reads; defaults to [label] (nothing for a dot).
  final String? semanticLabel;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? _material()
        : _glass(context),
  );

  bool get _isDot => label == null || label!.isEmpty;

  // The label is announced once, beside the child's own semantics.
  Widget _material() => Semantics(
    label: isVisible ? semanticLabel ?? label : null,
    child: Badge(
      label: _isDot ? null : ExcludeSemantics(child: Text(label!)),
      isLabelVisible: isVisible,
      backgroundColor: color,
      textColor: textColor,
      child: child,
    ),
  );

  Widget _glass(BuildContext context) {
    final child = this.child;
    if (!isVisible) return child ?? const SizedBox.shrink();
    final badge = _withSemantics(_badge(context));
    if (child == null) return badge;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        PositionedDirectional(
          top: -(_isDot
              ? BadgeMetrics.dotOffsetTop
              : BadgeMetrics.textOffsetTop),
          end: -(_isDot
              ? BadgeMetrics.dotOffsetEnd
              : BadgeMetrics.textOffsetEnd),
          child: badge,
        ),
      ],
    );
  }

  Widget _badge(BuildContext context) {
    final c = CupertinoDynamicColor.resolve(
      color ?? GlassSystemColors.red,
      context,
    );
    if (_isDot) {
      return SizedBox.square(
        dimension: BadgeMetrics.dot,
        child: DecoratedBox(
          decoration: ShapeDecoration(shape: const StadiumBorder(), color: c),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: BadgeMetrics.height,
        minHeight: BadgeMetrics.height,
        maxHeight: BadgeMetrics.height,
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(shape: const StadiumBorder(), color: c),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BadgeMetrics.horizontalPadding,
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label!,
              maxLines: 1,
              style: BadgeMetrics.text.copyWith(
                color: textColor ?? GlassColors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _withSemantics(Widget badge) => _isDot && semanticLabel == null
      ? badge
      : Semantics(
          label: semanticLabel ?? label,
          child: ExcludeSemantics(child: badge),
        );
}
