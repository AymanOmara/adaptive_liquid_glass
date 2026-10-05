import 'package:flutter/cupertino.dart';

import '../core/glass.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../liquid_glass.dart';
import 'button_metrics.dart';
import 'material_glass_button.dart';

/// SwiftUI's glass button styles.
enum GlassButtonStyle {
  /// `.glass`: plain interactive glass with a readable label.
  glass,

  /// `.glassProminent`: glass tinted with the accent, white label.
  glassProminent,
}

/// SwiftUI's button roles.
enum GlassButtonRole {
  /// No role.
  none,

  /// Destroys data: red label, or red tint when prominent.
  destructive,

  /// Cancels: semibold label.
  cancel,
}

/// SwiftUI's `ControlSize`. On iOS 26 glass buttons, mini is drawn as
/// small and extraLarge as large.
enum GlassControlSize {
  /// `.mini`.
  mini,

  /// `.small`.
  small,

  /// `.regular`, the default.
  regular,

  /// `.large`.
  large,

  /// `.extraLarge`.
  extraLarge,
}

/// SwiftUI's `ButtonBorderShape` for glass buttons.
enum GlassButtonShape {
  /// A capsule (icon-only buttons too, as on iOS 26).
  automatic,

  /// A capsule.
  capsule,

  /// A circle (square layout).
  circle,

  /// A rounded rectangle with the size's corner radius.
  roundedRect,
}

/// The default [GlassControlSize] for glass buttons below it, like
/// SwiftUI's `.controlSize(_:)`.
class GlassControlSizeScope extends InheritedWidget {
  /// Creates the scope.
  const GlassControlSizeScope({
    super.key,
    required this.size,
    required super.child,
  });

  /// The size buttons below use unless they set one.
  final GlassControlSize size;

  /// The nearest scope's size, if any.
  static GlassControlSize? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassControlSizeScope>()?.size;

  @override
  bool updateShouldNotify(GlassControlSizeScope old) => old.size != size;
}

/// Exact metrics for glass buttons below, overriding their control size.
/// Internal: bars use it for their item metrics.
class GlassButtonMetricsScope extends InheritedWidget {
  /// Creates the scope.
  const GlassButtonMetricsScope({
    super.key,
    required this.metrics,
    required super.child,
  });

  /// The metrics buttons below use.
  final GlassButtonMetrics metrics;

  /// The nearest scope's metrics, if any.
  static GlassButtonMetrics? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<GlassButtonMetricsScope>()
      ?.metrics;

  @override
  bool updateShouldNotify(GlassButtonMetricsScope old) =>
      old.metrics != metrics;
}

/// A SwiftUI glass button: `.buttonStyle(.glass)` or `.glassProminent`.
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
/// Built on [LiquidGlass], so it joins an enclosing `GlassGroup` and morphs
/// with [glassId]. On the Material path it is a Material 3 button.
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
    this.mode,
    this.glassId,
    this.semanticLabel,
  }) : child = null;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  /// Plain or prominent glass.
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

  /// The prominent fill; defaults to the accent colour. A destructive role
  /// uses red instead.
  final Color? tint;

  /// Rendering mode; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// Morph identity inside a `GlassGroup`.
  final Object? glassId;

  /// The accessibility label; give one to icon-only buttons.
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
        : _glass(context),
  );

  Widget _glass(BuildContext context) {
    final m =
        GlassButtonMetricsScope.maybeOf(context) ??
        glassButtonMetrics(resolvedSize(context));
    // Plain colours (not CupertinoDynamicColor) for the glass and label.
    Color resolve(Color c) =>
        Color(CupertinoDynamicColor.resolve(c, context).toARGB32());
    final red = resolve(CupertinoColors.systemRed);
    final prominent = style == GlassButtonStyle.glassProminent;
    final accent = role == GlassButtonRole.destructive
        ? red
        : resolve(tint ?? CupertinoTheme.of(context).primaryColor);
    final Color? labelColor = prominent
        ? const Color(0xFFFFFFFF)
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
      GlassButtonShape.roundedRect => GlassShape.rect(m.cornerRadius),
    };
    final circle = shape == GlassButtonShape.circle;
    final height = (_iconOnly ? m.iconOnlyHeight : m.height) * scale;
    final BoxConstraints box = _iconOnly
        ? BoxConstraints.tightFor(
            width: circle ? height : height + m.iconOnlyExtraWidth * scale,
            height: height,
          )
        : BoxConstraints(minHeight: height, minWidth: circle ? height : 0);

    Widget content = _content(m);
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
      maxLines: 1,
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
          child: Center(widthFactor: 1, heightFactor: 1, child: content),
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
    final i = Icon(icon);
    if (label == null) return i;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        i,
        SizedBox(width: m.iconGap),
        label!,
      ],
    );
  }
}
