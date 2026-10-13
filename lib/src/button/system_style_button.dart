import 'package:flutter/cupertino.dart';

import '../core/glass_brightness.dart';
import '../core/glass_colors.dart';
import '../core/glass_shape.dart';
import '../core/glass_system_colors.dart';
import '../core/shape_border.dart';
import '../interaction/glass_pressable.dart';
import 'glass_button.dart';
import 'glass_button_metrics.dart';
import 'glass_button_role.dart';
import 'glass_button_shape.dart';
import 'glass_button_style.dart';
import 'system_button_metrics.dart';

/// A [GlassButton] in one of SwiftUI's styles without glass: `.bordered`,
/// `.borderedProminent`, `.borderless` or `.plain`, on the Cupertino path.
///
/// Bordered styles take the glass button's height and padding for the
/// control size; borderless and plain hug their label, as SwiftUI's do.
/// Every style dims while pressed and draws a disabled button in iOS's
/// tertiary label colour. Internal: `GlassButton` builds it.
class SystemStyleButton extends StatefulWidget {
  /// Creates the button.
  const SystemStyleButton({
    super.key,
    required this.button,
    required this.metrics,
  });

  /// The button to render.
  final GlassButton button;

  /// Its resolved metrics.
  final GlassButtonMetrics metrics;

  @override
  State<SystemStyleButton> createState() => _SystemStyleButtonState();
}

class _SystemStyleButtonState extends State<SystemStyleButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.button;
    final m = widget.metrics;
    Color resolve(Color c) =>
        Color(CupertinoDynamicColor.resolve(c, context).toARGB32());
    final destructive = b.role == GlassButtonRole.destructive;
    final accent = destructive
        ? resolve(GlassSystemColors.red)
        : resolve(b.tint ?? CupertinoTheme.of(context).primaryColor);
    final enabled = b.onPressed != null;
    final active = b.active;
    final bordered =
        b.style == GlassButtonStyle.bordered ||
        b.style == GlassButtonStyle.borderedProminent;
    final prominent = b.style == GlassButtonStyle.borderedProminent;
    final dark = glassBrightnessOf(context) == Brightness.dark;

    final Color labelColor = !enabled
        ? resolve(GlassColors.buttonDisabledLabel)
        : switch (b.style) {
            GlassButtonStyle.borderedProminent => GlassColors.white,
            GlassButtonStyle.plain when !destructive => resolve(
              GlassColors.plainButtonLabel,
            ),
            _ => accent,
          };
    final Color? fill = !bordered
        ? null
        : !enabled
        ? resolve(GlassColors.borderedButtonFill)
        : prominent
        ? accent
        // SwiftUI's untinted `.bordered` is grey; a tint or a destructive
        // role colours the fill too.
        : b.tint == null && !destructive
        ? resolve(GlassColors.borderedButtonFill)
        : accent.withValues(
            alpha: dark
                ? SystemButtonMetrics.tintedFillOpacityDark
                : SystemButtonMetrics.tintedFillOpacityLight,
          );

    final scale =
        MediaQuery.textScalerOf(context).scale(m.fontSize) / m.fontSize;
    final iconOnly = b.icon != null && b.label == null;
    final GlassShape outline = !bordered
        ? GlassShape.rect(m.cornerRadius)
        : switch (b.shape) {
            // iOS 26 draws bordered buttons as capsules by default
            // (estimated, as glass buttons).
            GlassButtonShape.automatic ||
            GlassButtonShape.capsule => const GlassShape.capsule(),
            GlassButtonShape.circle => const GlassShape.circle(),
            GlassButtonShape.roundedRect => GlassShape.rect(m.cornerRadius),
          };
    final circle = bordered && b.shape == GlassButtonShape.circle;

    // An explicit label replaces the visible one rather than doubling it.
    Widget content = ExcludeSemantics(
      excluding: b.semanticLabel != null,
      child: _content(m),
    );
    if (b.loading) {
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
    }
    content = DefaultTextStyle.merge(
      style: TextStyle(
        fontSize: m.fontSize,
        fontWeight: b.role == GlassButtonRole.cancel
            ? FontWeight.w600
            : FontWeight.w400,
        color: labelColor,
      ),
      maxLines: scale > 1 ? null : 1,
      textAlign: scale > 1 ? TextAlign.center : null,
      child: IconTheme.merge(
        data: IconThemeData(size: m.iconSize, color: labelColor),
        child: content,
      ),
    );

    if (bordered) {
      final height = (iconOnly ? m.iconOnlyHeight : m.height) * scale;
      final BoxConstraints box = iconOnly
          ? BoxConstraints.tightFor(
              width: circle ? height : height + m.iconOnlyExtraWidth * scale,
              height: height,
            )
          : BoxConstraints(minHeight: height, minWidth: circle ? height : 0);
      content = DecoratedBox(
        decoration: ShapeDecoration(
          color: fill,
          shape: sizeIndependentBorder(outline),
        ),
        child: ConstrainedBox(
          constraints: box,
          child: Padding(
            padding: iconOnly || circle
                ? EdgeInsets.zero
                : EdgeInsetsDirectional.symmetric(horizontal: m.padding),
            child: Center(widthFactor: 1, heightFactor: 1, child: content),
          ),
        ),
      );
    }

    Widget button = AnimatedOpacity(
      opacity: _pressed && active ? SystemButtonMetrics.pressedOpacity : 1,
      duration: _pressed
          ? SystemButtonMetrics.pressIn
          : SystemButtonMetrics.pressOut,
      child: content,
    );
    button = GestureDetector(
      onTapDown: active ? (_) => _setPressed(true) : null,
      onTapUp: active ? (_) => _setPressed(false) : null,
      onTapCancel: active ? () => _setPressed(false) : null,
      child: GlassPressable(
        onPressed: active ? b.onPressed : null,
        shape: outline,
        child: button,
      ),
    );
    // One node; a disabled or loading button is still a (disabled) button.
    return MergeSemantics(
      child: Semantics(
        label: b.semanticLabel,
        value: b.loading ? b.loadingLabel : null,
        button: active ? null : true,
        enabled: active ? null : false,
        child: button,
      ),
    );
  }

  Widget _content(GlassButtonMetrics m) {
    final b = widget.button;
    if (b.child != null) return b.child!;
    final i = Icon(b.icon);
    if (b.label == null) return i;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        i,
        SizedBox(width: m.iconGap),
        Flexible(child: b.label!),
      ],
    );
  }
}
