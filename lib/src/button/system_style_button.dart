import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;

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
import 'system_button_press.dart';

/// A [GlassButton] in one of SwiftUI's styles without glass: `.bordered`,
/// `.borderedProminent`, `.borderless` or `.plain`, on the Cupertino path.
///
/// Bordered styles share glass button heights but have their own measured
/// horizontal padding. Borderless and plain hug their label.
/// Pressed fill and label follow their own measured highlight in each
/// appearance. Internal: `GlassButton` builds it.
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
  int? _pressPointer;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _endPress(int pointer) {
    if (pointer != _pressPointer) return;
    _pressPointer = null;
    _setPressed(false);
  }

  void _cancelPress() {
    _pressPointer = null;
    _setPressed(false);
  }

  @override
  void didUpdateWidget(SystemStyleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.button.active) {
      _pressPointer = null;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pressed = _pressed && widget.button.active;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: pressed ? 1 : 0),
      duration: pressed
          ? SystemButtonMetrics.pressIn
          : SystemButtonMetrics.pressOut,
      curve: pressed ? Curves.linear : SystemButtonMetrics.releaseCurve,
      builder: (context, progress, _) => _buildButton(context, progress),
    );
  }

  Widget _buildButton(BuildContext context, double progress) {
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
        : b.foregroundColor != null
        ? resolve(b.foregroundColor!)
        : switch (b.style) {
            GlassButtonStyle.borderedProminent => GlassColors.white,
            GlassButtonStyle.plain when !destructive => resolve(
              GlassColors.plainButtonLabel,
            ),
            _ => accent,
          };
    final Color? idleFill = !bordered
        ? null
        : !enabled
        ? resolve(GlassColors.borderedButtonFill)
        : prominent
        ? accent
        // An untinted destructive bordered button also keeps the neutral
        // fill; only its label is red (measured on iOS 26.4).
        : b.tint == null
        ? resolve(GlassColors.borderedButtonFill)
        : accent.withValues(
            alpha: dark
                ? SystemButtonMetrics.tintedFillOpacityDark
                : SystemButtonMetrics.tintedFillOpacityLight,
          );

    final fill = Color.lerp(
      idleFill,
      SystemButtonPress.fill(
        idleFill,
        b.style,
        dark: dark,
        tinted: b.tint != null,
      ),
      progress,
    );

    final scale =
        MediaQuery.textScalerOf(context).scale(m.fontSize) / m.fontSize;
    final iconOnly = b.icon != null && b.label == null;
    final GlassShape outline = !bordered
        ? GlassShape.rect(m.cornerRadius)
        : switch (b.shape) {
            // iOS 26 draws bordered buttons as capsules by default.
            GlassButtonShape.automatic ||
            GlassButtonShape.capsule => const GlassShape.capsule(),
            GlassButtonShape.circle => const GlassShape.circle(),
            GlassButtonShape.roundedRect => GlassShape.rect(
              b.cornerRadius ?? m.cornerRadius,
            ),
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
          b.loadingValue == null
              ? CupertinoActivityIndicator(
                  radius: m.fontSize * 0.5,
                  color: labelColor,
                )
              : CupertinoActivityIndicator.partiallyRevealed(
                  radius: m.fontSize * 0.5,
                  color: labelColor,
                  progress: b.loadingValue!.clamp(0.0, 1.0),
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

    content = Opacity(
      opacity:
          1 +
          (SystemButtonPress.labelOpacity(b.style, dark: dark) - 1) * progress,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(
          GlassColors.white.withValues(
            alpha:
                SystemButtonPress.labelWhiteMix(b.style, dark: dark) * progress,
          ),
          BlendMode.srcATop,
        ),
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

    final button = Listener(
      // The tap recognizer waits kPressTimeout before onTapDown. Native
      // buttons highlight at touch delivery, so start visuals directly while
      // leaving activation and scroll arbitration to the existing recognizers.
      onPointerDown: active
          ? (event) {
              if (_pressPointer != null ||
                  (event.buttons & kPrimaryButton) == 0) {
                return;
              }
              _pressPointer = event.pointer;
              _setPressed(true);
            }
          : null,
      onPointerUp: (event) => _endPress(event.pointer),
      onPointerCancel: (event) => _endPress(event.pointer),
      child: GestureDetector(
        onTapCancel: active ? _cancelPress : null,
        child: GlassPressable(
          onPressed: active ? b.effectiveOnPressed : null,
          shape: outline,
          child: content,
        ),
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
