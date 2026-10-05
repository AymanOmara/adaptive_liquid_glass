import 'package:flutter/material.dart';

import 'glass_button.dart';

/// Material 3 button heights per [GlassControlSize].
const materialButtonHeights = <GlassControlSize, double>{
  GlassControlSize.mini: 32,
  GlassControlSize.small: 36,
  GlassControlSize.regular: 40,
  GlassControlSize.large: 48,
  GlassControlSize.extraLarge: 56,
};

/// A [GlassButton] as a stock Material 3 button: `FilledButton.tonal` for
/// glass, `FilledButton` for prominent, `TextButton` for cancel, and the
/// matching `IconButton` for icon-only buttons.
class MaterialGlassButton extends StatelessWidget {
  /// Creates the Material button.
  const MaterialGlassButton({
    super.key,
    required this.button,
    required this.size,
  });

  /// The button to render.
  final GlassButton button;

  /// Its resolved size.
  final GlassControlSize size;

  @override
  Widget build(BuildContext context) {
    final b = button;
    final scheme = Theme.of(context).colorScheme;
    final h = materialButtonHeights[size]!;
    final destructive = b.role == GlassButtonRole.destructive;
    final prominent = b.style == GlassButtonStyle.glassProminent;
    final Color? background = destructive
        ? (prominent ? scheme.error : scheme.errorContainer)
        : prominent
        ? b.tint
        : null;
    final Color? foreground = destructive
        ? (prominent ? scheme.onError : scheme.onErrorContainer)
        : null;
    final OutlinedBorder? border = switch (b.shape) {
      GlassButtonShape.roundedRect => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(h / 4),
      ),
      GlassButtonShape.circle => const CircleBorder(),
      _ => null,
    };
    // Loading disables the button but keeps its enabled colours.
    final VoidCallback? onPressed = b.loading ? null : b.onPressed;
    final iconOnly = b.icon != null && b.label == null;
    final cancel = b.role == GlassButtonRole.cancel;
    final Color? loadingBackground = !b.loading || cancel
        ? null
        : background ??
              (prominent ? scheme.primary : scheme.secondaryContainer);
    final Color? loadingForeground = !b.loading
        ? null
        : foreground ??
              (cancel
                  ? (iconOnly ? scheme.onSurfaceVariant : scheme.primary)
                  : prominent
                  ? scheme.onPrimary
                  : scheme.onSecondaryContainer);

    Widget withLoading(Widget content) => !b.loading
        ? content
        : Stack(
            alignment: Alignment.center,
            children: [
              Opacity(opacity: 0, alwaysIncludeSemantics: true, child: content),
              SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              ),
            ],
          );

    final Widget result;
    if (b.icon != null && b.label == null) {
      final style = IconButton.styleFrom(
        fixedSize: Size.square(h),
        minimumSize: Size.square(h),
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: loadingBackground,
        disabledForegroundColor: loadingForeground,
        shape: border,
      );
      final icon = withLoading(Icon(b.icon));
      result = switch ((b.role, b.style)) {
        (GlassButtonRole.cancel, _) => IconButton(
          onPressed: onPressed,
          style: style,
          icon: icon,
        ),
        (_, GlassButtonStyle.glassProminent) => IconButton.filled(
          onPressed: onPressed,
          style: style,
          icon: icon,
        ),
        _ => IconButton.filledTonal(
          onPressed: onPressed,
          style: style,
          icon: icon,
        ),
      };
    } else {
      final style = ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(0, h)),
        backgroundColor: _colour(background, loadingBackground),
        foregroundColor: _colour(foreground, loadingForeground),
        shape: border == null ? null : WidgetStatePropertyAll(border),
      );
      final content = withLoading(
        b.child ??
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(b.icon), const SizedBox(width: 8), b.label!],
            ),
      );
      result = switch ((b.role, b.style)) {
        (GlassButtonRole.cancel, _) => TextButton(
          onPressed: onPressed,
          style: style,
          child: content,
        ),
        (_, GlassButtonStyle.glassProminent) => FilledButton(
          onPressed: onPressed,
          style: style,
          child: content,
        ),
        _ => FilledButton.tonal(
          onPressed: onPressed,
          style: style,
          child: content,
        ),
      };
    }
    return MergeSemantics(
      child: Semantics(
        label: b.semanticLabel,
        value: b.loading ? b.loadingLabel : null,
        child: result,
      ),
    );
  }

  /// [enabled] normally; [loading] also while disabled for loading.
  static WidgetStateProperty<Color?>? _colour(Color? enabled, Color? loading) {
    if (enabled == null && loading == null) return null;
    return WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled) ? loading : enabled,
    );
  }
}
