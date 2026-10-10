import 'package:flutter/material.dart';

import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import 'glass_button.dart';
import 'glass_button_shape.dart';
import 'glass_button_style.dart';
import 'glass_control_size.dart';

/// The screen's primary action: a Material 3 floating action button on the
/// Material path, a large prominent glass button elsewhere.
///
/// ```dart
/// GlassFloatingActionButton(
///   onPressed: compose,
///   icon: CupertinoIcons.add,
///   semanticLabel: 'New event',
/// )
/// GlassFloatingActionButton.extended(
///   onPressed: compose,
///   icon: CupertinoIcons.add,
///   label: const Text('New event'),
/// )
/// ```
///
/// iOS 26 has no floating action button; the glass path draws the large
/// `.glassProminent` button, a circle, or a capsule with [label]. Place it
/// yourself, e.g. in a `Stack` above the tab bar.
class GlassFloatingActionButton extends StatelessWidget {
  /// An icon-only button: `FloatingActionButton` on the Material path.
  const GlassFloatingActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.semanticLabel,
    this.tooltip,
    this.tint,
    this.heroTag,
    this.mode,
    this.glassId,
  }) : label = null;

  /// A button with [label] beside [icon]: `FloatingActionButton.extended`
  /// on the Material path.
  const GlassFloatingActionButton.extended({
    super.key,
    required this.onPressed,
    required this.icon,
    required Widget this.label,
    this.semanticLabel,
    this.tooltip,
    this.tint,
    this.heroTag,
    this.mode,
    this.glassId,
  });

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  /// The icon.
  final IconData icon;

  /// The label beside [icon] ([GlassFloatingActionButton.extended]).
  final Widget? label;

  /// The accessibility label; give one to icon-only buttons.
  final String? semanticLabel;

  /// The Material tooltip, shown on long press; not used on the glass
  /// paths.
  final String? tooltip;

  /// The fill; defaults to the accent colour (Material: the theme's
  /// primary container).
  final Color? tint;

  /// The Material button's hero tag. Null (the default) has no hero, so
  /// several buttons on one route do not clash.
  final Object? heroTag;

  /// Rendering mode; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// Morph identity inside a `GlassGroup`.
  final Object? glassId;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? _material()
        : GlassButton.icon(
            onPressed: onPressed,
            icon: icon,
            label: label,
            style: GlassButtonStyle.glassProminent,
            size: GlassControlSize.large,
            shape: label == null
                ? GlassButtonShape.circle
                : GlassButtonShape.capsule,
            tint: tint,
            mode: mode,
            glassId: glassId,
            semanticLabel: semanticLabel,
          ),
  );

  Widget _material() {
    final label = this.label;
    final Widget button = label == null
        ? FloatingActionButton(
            onPressed: onPressed,
            tooltip: tooltip,
            heroTag: heroTag,
            backgroundColor: tint,
            child: Icon(icon),
          )
        : FloatingActionButton.extended(
            onPressed: onPressed,
            tooltip: tooltip,
            heroTag: heroTag,
            backgroundColor: tint,
            icon: Icon(icon),
            label: label,
          );
    final semanticLabel = this.semanticLabel;
    if (semanticLabel == null) return button;
    // An explicit label replaces the visible one rather than doubling it.
    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      enabled: onPressed != null,
      onTap: onPressed,
      child: button,
    );
  }
}
