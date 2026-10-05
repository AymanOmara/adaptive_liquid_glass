import 'package:flutter/material.dart';

import '../core/glass.dart';
import '../core/glass_shape.dart';
import '../core/shape_border.dart';
import '../foreground/glass_label_style.dart';
import '../interaction/glass_pressable.dart';

/// Material 3 rendering of a glass member (spec §8).
class MaterialGlass extends StatelessWidget {
  /// Creates a Material glass surface.
  const MaterialGlass({
    super.key,
    required this.glass,
    required this.shape,
    this.fadeIn = false,
    this.adaptiveForeground = false,
    this.onPressed,
    required this.child,
  });

  /// Glass description.
  final Glass glass;

  /// Shape.
  final GlassShape shape;

  /// Fade in when first shown (members that appear after the group).
  final bool fadeIn;

  /// Colour text and icons with the surface's matching "on" colour.
  final bool adaptiveForeground;

  /// Makes the surface a button; see `LiquidGlass.onPressed`.
  final VoidCallback? onPressed;

  /// Content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (glass.variant == GlassVariant.identity) return child;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = glass.tintColor;
    final seeded = tint == null
        ? null
        : ColorScheme.fromSeed(seedColor: tint, brightness: theme.brightness);
    final Color color = seeded != null
        ? seeded.primaryContainer
        : glass.variant == GlassVariant.clear
        ? scheme.surfaceContainerLow.withValues(alpha: 0.85)
        : scheme.surfaceContainerHigh;
    final content = adaptiveForeground
        ? GlassLabelStyle(
            color: seeded?.onPrimaryContainer ?? scheme.onSurface,
            child: child,
          )
        : child;

    Widget surface = Material(
      color: color,
      elevation: glass.variant == GlassVariant.regular ? 1 : 0,
      shadowColor: scheme.shadow,
      surfaceTintColor: Colors.transparent,
      shape: sizeIndependentBorder(shape),
      clipBehavior: Clip.antiAlias,
      child: _pressable(content),
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

  /// Interactive glass ripples (InkWell); a plain surface with [onPressed]
  /// still taps, focuses and activates, without a ripple.
  Widget _pressable(Widget content) {
    final onPressed = this.onPressed;
    if (!glass.isInteractive) {
      return onPressed == null
          ? content
          : GlassPressable(onPressed: onPressed, child: content);
    }
    if (onPressed == null) {
      return InkWell(onTap: () {}, excludeFromSemantics: true, child: content);
    }
    return Semantics(
      container: true,
      button: true,
      enabled: true,
      child: InkWell(onTap: onPressed, child: content),
    );
  }
}
