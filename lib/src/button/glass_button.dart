import 'package:flutter/cupertino.dart';

import '../core/effective_glass_mode.dart';
import '../core/glass.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../core/glass_system_colors.dart';
import '../foreground/glass_foreground.dart';
import '../foreground/glass_label_style.dart';
import '../liquid_glass.dart';
import 'glass_button_glyph_effect.dart';
import 'glass_button_metrics.dart';
import 'glass_button_metrics_scope.dart';
import 'glass_button_role.dart';
import 'glass_button_shape.dart';
import 'glass_button_style.dart';
import 'glass_control_size.dart';
import 'glass_control_size_scope.dart';
import 'material_glass_button.dart';
import 'system_style_button.dart';

/// A SwiftUI button: `.buttonStyle(.glass)` or `.glassProminent`, or one of
/// the system styles without glass (`.bordered`, `.borderedProminent`,
/// `.borderless`, `.plain`) chosen with [style].
///
/// ```dart
/// GlassButton(onPressed: save, child: const Text('Save'))
/// GlassButton.icon(
///   onPressed: share,
///   icon: CupertinoIcons.share,
///   semanticLabel: 'Share',
/// )
/// ```
///
/// The glass styles are built on [LiquidGlass], so they join an enclosing
/// `GlassGroup` and morph with [glassId]; the other styles draw no glass
/// and ignore [glassId]. On the Material path it is a Material 3 button.
class GlassButton extends StatelessWidget {
  /// A button with [child] as its label.
  const GlassButton({
    super.key,
    required this.onPressed,
    this.style = GlassButtonStyle.glass,
    this.role = GlassButtonRole.none,
    this.size,
    this.shape = GlassButtonShape.automatic,
    this.loading = false,
    this.loadingLabel = 'loading',
    this.tint,
    this.foregroundColor,
    this.cornerRadius,
    this.mode,
    this.glassId,
    this.semanticLabel,
    required Widget this.child,
  }) : icon = null,
       label = null;

  /// A button with [icon], and [label] beside it when given.
  const GlassButton.icon({
    super.key,
    required this.onPressed,
    required IconData this.icon,
    this.label,
    this.style = GlassButtonStyle.glass,
    this.role = GlassButtonRole.none,
    this.size,
    this.shape = GlassButtonShape.automatic,
    this.loading = false,
    this.loadingLabel = 'loading',
    this.tint,
    this.foregroundColor,
    this.cornerRadius,
    this.mode,
    this.glassId,
    this.semanticLabel,
  }) : child = null;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  /// The SwiftUI button style: glass, prominent glass, or a style without
  /// glass.
  final GlassButtonStyle style;

  /// The role, which can change the colour or weight.
  final GlassButtonRole role;

  /// Defaults to the enclosing [GlassControlSizeScope], else regular.
  final GlassControlSize? size;

  /// The outline.
  final GlassButtonShape shape;

  /// Shows an activity indicator in place of the content and ignores taps.
  final bool loading;

  /// Read after the label while [loading].
  final String loadingLabel;

  /// The accent: the prominent fill, the `.bordered` fill (at low opacity)
  /// and the `.bordered` and `.borderless` label. Defaults to the theme's
  /// accent colour; a destructive role uses red instead.
  final Color? tint;

  /// The label and icon colour on every path and style, in place of the
  /// style's own (white on prominent glass, the contrast colour on a
  /// Material fill, the role's red). Null keeps the style's colour. A
  /// disabled button keeps the package's disabled look: dimmed on glass,
  /// iOS's disabled grey on the system styles, Material's disabled
  /// colour on the Material path.
  final Color? foregroundColor;

  /// The corner radius of a [GlassButtonShape.roundedRect] button, on
  /// both paths. Null keeps the control size's radius (the Material
  /// path's quarter height). Ignored by the other shapes: a capsule or a
  /// circle has no free radius.
  final double? cornerRadius;

  /// Rendering mode; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// Morph identity inside a `GlassGroup`.
  final Object? glassId;

  /// The accessibility label; give one to icon-only buttons. Replaces the
  /// visible label for assistive tech.
  final String? semanticLabel;

  /// The label (default constructor).
  final Widget? child;

  /// The icon ([GlassButton.icon]).
  final IconData? icon;

  /// The label beside [icon].
  final Widget? label;

  bool get _iconOnly => icon != null && label == null;

  /// Whether taps do anything.
  bool get active => onPressed != null && !loading;

  /// The size this button resolves to in [context].
  GlassControlSize resolvedSize(BuildContext context) =>
      size ??
      GlassControlSizeScope.maybeOf(context) ??
      GlassControlSize.regular;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? MaterialGlassButton(button: this, size: resolvedSize(context))
        : _isGlass
        ? _glass(context)
        : SystemStyleButton(
            button: this,
            metrics:
                GlassButtonMetricsScope.maybeOf(context) ??
                glassButtonMetrics(resolvedSize(context)),
          ),
  );

  bool get _isGlass =>
      style == GlassButtonStyle.glass ||
      style == GlassButtonStyle.glassProminent;

  Widget _glass(BuildContext context) {
    final m =
        GlassButtonMetricsScope.maybeOf(context) ??
        glassButtonMetrics(resolvedSize(context));
    // Plain colours (not CupertinoDynamicColor) for the glass and label.
    Color resolve(Color c) =>
        Color(CupertinoDynamicColor.resolve(c, context).toARGB32());
    final red = resolve(GlassSystemColors.red);
    final prominent = style == GlassButtonStyle.glassProminent;
    final accent = role == GlassButtonRole.destructive
        ? red
        : resolve(tint ?? CupertinoTheme.of(context).primaryColor);
    final Color? labelColor = foregroundColor != null
        ? resolve(foregroundColor!)
        : prominent
        ? GlassColors.white
        : role == GlassButtonRole.destructive
        ? red
        : null;
    final glass = (prominent ? Glass.regular.tint(accent) : Glass.regular)
        .interactive(active);
    final scale =
        MediaQuery.textScalerOf(context).scale(m.fontSize) / m.fontSize;

    final GlassShape outline = switch (shape) {
      GlassButtonShape.automatic ||
      GlassButtonShape.capsule => const GlassShape.capsule(),
      GlassButtonShape.circle => const GlassShape.circle(),
      GlassButtonShape.roundedRect => GlassShape.rect(
        cornerRadius ?? m.cornerRadius,
      ),
    };
    final circle = shape == GlassButtonShape.circle;
    final height = (_iconOnly ? m.iconOnlyHeight : m.height) * scale;
    final BoxConstraints box = _iconOnly
        ? BoxConstraints.tightFor(
            width: circle ? height : height + m.iconOnlyExtraWidth * scale,
            height: height,
          )
        : BoxConstraints(minHeight: height, minWidth: circle ? height : 0);

    // An explicit label replaces the visible one rather than doubling it.
    Widget content = ExcludeSemantics(
      excluding: semanticLabel != null,
      child: _content(m),
    );
    if (loading) {
      content = Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0, alwaysIncludeSemantics: true, child: content),
          CupertinoActivityIndicator(
            radius: m.fontSize * 0.5,
            color: labelColor,
          ),
        ],
      );
    } else if (onPressed == null) {
      content = Opacity(opacity: 0.5, child: content);
    }
    content = DefaultTextStyle.merge(
      style: TextStyle(
        fontSize: m.fontSize,
        fontWeight: role == GlassButtonRole.cancel
            ? FontWeight.w600
            : FontWeight.w400,
        color: labelColor,
      ),
      // One line at the default size; larger Dynamic Type wraps the label,
      // as SwiftUI's buttons do, rather than cutting it off.
      maxLines: scale > 1 ? null : 1,
      textAlign: scale > 1 ? TextAlign.center : null,
      child: IconTheme.merge(
        data: IconThemeData(size: m.iconSize, color: labelColor),
        child: content,
      ),
    );

    Widget button = LiquidGlass(
      glass: glass,
      shape: outline,
      glassId: glassId,
      mode: mode,
      onPressed: active ? onPressed : null,
      child: ConstrainedBox(
        constraints: box,
        child: Padding(
          padding: _iconOnly || circle
              ? EdgeInsets.zero
              : EdgeInsetsDirectional.symmetric(horizontal: m.padding),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: labelColor != null
                ? content
                // SwiftUI's glass button label is opaque black on light
                // content (measured), not the 85% of other glass labels.
                : Builder(
                    builder: (context) => GlassLabelStyle(
                      color:
                          GlassForeground.backgroundBrightnessOf(context) ==
                              Brightness.light
                          ? GlassColors.buttonLabelOnLight
                          : GlassColors.labelOnDark,
                      child: content,
                    ),
                  ),
          ),
        ),
      ),
    );
    // One node: the label and value merge into LiquidGlass's button node.
    // A disabled or loading GlassButton is still a (disabled) button.
    button = MergeSemantics(
      child: Semantics(
        label: semanticLabel,
        value: loading ? loadingLabel : null,
        button: active ? null : true,
        enabled: active ? null : false,
        child: button,
      ),
    );
    return button;
  }

  Widget _content(GlassButtonMetrics m) {
    if (child != null) return child!;
    final Widget i = Builder(
      builder: (c) => GlassButtonGlyphEffect.wrap(c, Icon(icon)),
    );
    if (label == null) return i;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        i,
        SizedBox(width: m.iconGap),
        Flexible(child: label!),
      ],
    );
  }
}
