import 'package:flutter/material.dart';

import '../core/glass.dart';
import '../core/glass_shape.dart';
import '../core/shape_border.dart';

/// Material 3 rendering of a glass member (spec §8).
class MaterialGlass extends StatelessWidget {
  /// Creates a Material glass surface.
  const MaterialGlass({
    super.key,
    required this.glass,
    required this.shape,
    this.fadeIn = false,
    required this.child,
  });

  /// Glass description.
  final Glass glass;

  /// Shape.
  final GlassShape shape;

  /// Fade in when first shown (members that appear after the group).
  final bool fadeIn;

  /// Content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (glass.variant == GlassVariant.identity) return child;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = glass.tintColor;
    final Color color = tint != null
        ? ColorScheme.fromSeed(
            seedColor: tint,
            brightness: theme.brightness,
          ).primaryContainer
        : glass.variant == GlassVariant.clear
        ? scheme.surfaceContainerLow.withValues(alpha: 0.85)
        : scheme.surfaceContainerHigh;

    Widget surface = Material(
      color: color,
      elevation: glass.variant == GlassVariant.regular ? 1 : 0,
      shadowColor: scheme.shadow,
      surfaceTintColor: Colors.transparent,
      shape: sizeIndependentBorder(shape),
      clipBehavior: Clip.antiAlias,
      child: glass.isInteractive
          ? InkWell(onTap: () {}, excludeFromSemantics: true, child: child)
          : child,
    );

    if (fadeIn) {
      surface = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 200),
        builder: (context, v, child) => Opacity(opacity: v, child: child),
        child: surface,
      );
    }
    return surface;
  }
}
