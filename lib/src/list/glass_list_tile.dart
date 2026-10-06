import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Icons, ListTile, MaterialBasedCupertinoThemeData, Theme;

import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/ios_text.dart';
import '../interaction/glass_pressable.dart';
import 'list_chevron.dart';
import 'list_metrics.dart';
import 'list_section_scope.dart';

/// iOS 26's list row, like SwiftUI's `LabeledContent` row of a Settings
/// platter: a leading icon, a title, a value, a trailing control and a
/// chevron.
///
/// ```dart
/// GlassListTile(
///   leading: const Icon(CupertinoIcons.wifi),
///   title: const Text('Wi-Fi'),
///   value: 'Off',
///   chevron: true,
///   onTap: openWifi,
/// )
/// ```
///
/// Put tiles in a `GlassListSection`, which draws the platter and the
/// separators between rows; a standalone tile draws without either. The
/// row highlights instantly while pressed. On the Material path it is a
/// Material 3 [ListTile].
class GlassListTile extends StatefulWidget {
  /// Creates a list row.
  const GlassListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.value,
    this.trailing,
    this.chevron = false,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.mode,
  });

  /// The row's main text.
  final Widget title;

  /// A second line under the title.
  final Widget? subtitle;

  /// The row's start slot: an icon or a coloured rounded-square icon.
  /// Icons take iOS 26's default list accent (or the [CupertinoTheme]'s
  /// primary colour when it is not the default blue) at
  /// [ListMetrics.iconSize]; override by setting the icon's own colour or
  /// wrapping the leading in an `IconTheme`. A disabled row dims it.
  final Widget? leading;

  /// Secondary text before the trailing, like Settings' "Off".
  final String? value;

  /// The row's end control, e.g. a `GlassToggle`; not icon-tinted.
  final Widget? trailing;

  /// Whether a disclosure chevron is drawn at the end.
  final bool chevron;

  /// Called when the row is tapped.
  final VoidCallback? onTap;

  /// Called when the row is long-pressed.
  final VoidCallback? onLongPress;

  /// Whether the row responds to taps; a disabled row dims its text.
  final bool enabled;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassListTile> createState() => _GlassListTileState();
}

class _GlassListTileState extends State<GlassListTile> {
  /// Whether a pointer is down on the row.
  bool _pressed = false;

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode ?? ListSectionScope.maybeOf(context)?.mode;
    return GlassModeBuilder(
      mode: mode,
      builder: (context, effective) => effective == EffectiveGlassMode.material
          ? _material()
          : _glass(context),
    );
  }

  Widget _material() => ListTile(
    leading: widget.leading,
    title: widget.title,
    subtitle: widget.subtitle,
    trailing: _materialTrailing(),
    onTap: widget.onTap,
    onLongPress: widget.onLongPress,
    enabled: widget.enabled,
  );

  Widget? _materialTrailing() {
    if (widget.value == null && widget.trailing == null && !widget.chevron) {
      return null;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.value != null) Text(widget.value!),
        if (widget.trailing != null) widget.trailing!,
        if (widget.chevron) const Icon(Icons.chevron_right),
      ],
    );
  }

  /// The row's end inset: a trailing control, then a chevron, then text.
  double get _endInset {
    if (widget.trailing != null && !widget.chevron) {
      return ListMetrics.controlEnd;
    }
    if (widget.chevron) return ListMetrics.chevronEnd;
    return ListMetrics.horizontalPadding;
  }

  /// The leading's tint: iOS 26's list accent, the theme's primary
  /// colour when customized, or a dim grey while disabled.
  Color _leadingColor(BuildContext context) {
    if (!widget.enabled) {
      return CupertinoDynamicColor.resolve(
        CupertinoColors.tertiaryLabel,
        context,
      );
    }
    final theme = CupertinoTheme.of(context);
    // Under a MaterialApp the Cupertino theme is derived from the Material
    // colour scheme, whose primary is not an iOS accent choice; only an
    // explicit cupertinoOverrideTheme colour counts there.
    final Color? primary = theme is MaterialBasedCupertinoThemeData
        ? Theme.of(context).cupertinoOverrideTheme?.primaryColor
        : theme.primaryColor;
    // CupertinoTheme.of resolves dynamic colours, so compare against the
    // resolved default blue, not the activeBlue constant itself.
    final defaultBlue = CupertinoDynamicColor.resolve(
      CupertinoColors.activeBlue,
      context,
    );
    if (primary == null || primary == defaultBlue) {
      return CupertinoDynamicColor.resolve(GlassColors.listIcon, context);
    }
    return CupertinoDynamicColor.resolve(primary, context);
  }

  Widget _glass(BuildContext context) {
    final title = CupertinoDynamicColor.resolve(
      widget.enabled ? CupertinoColors.label : CupertinoColors.tertiaryLabel,
      context,
    );
    final secondary = CupertinoDynamicColor.resolve(
      widget.enabled
          ? CupertinoColors.secondaryLabel
          : CupertinoColors.tertiaryLabel,
      context,
    );
    final valueColor = CupertinoDynamicColor.resolve(
      widget.enabled ? GlassColors.listValue : CupertinoColors.tertiaryLabel,
      context,
    );
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: ListMetrics.minRowHeight),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: widget.leading != null
              ? ListMetrics.leadingStart
              : ListMetrics.horizontalPadding,
          end: _endInset,
          top: ListMetrics.verticalPadding,
          bottom: ListMetrics.verticalPadding,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.leading != null) ...[
              SizedBox(
                width: ListMetrics.leadingWidth,
                child: Center(
                  child: IconTheme.merge(
                    data: IconThemeData(
                      size: ListMetrics.iconSize,
                      color: _leadingColor(context),
                    ),
                    child: widget.leading!,
                  ),
                ),
              ),
              const SizedBox(width: ListMetrics.leadingGap),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle.merge(
                    style: IOSText.style(ListMetrics.titleSize, color: title),
                    child: widget.title,
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: ListMetrics.subtitleGap),
                    DefaultTextStyle.merge(
                      style: IOSText.style(
                        ListMetrics.subtitleSize,
                        color: secondary,
                      ),
                      child: widget.subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (widget.value != null) ...[
              const SizedBox(width: ListMetrics.trailingGap),
              Text(
                widget.value!,
                maxLines: 1,
                style: IOSText.style(ListMetrics.valueSize, color: valueColor),
              ),
            ],
            if (widget.trailing != null) ...[
              const SizedBox(width: ListMetrics.trailingGap),
              widget.trailing!,
            ],
            if (widget.chevron) ...[
              const SizedBox(width: ListMetrics.trailingGap),
              ListChevron(
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.tertiaryLabel,
                  context,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return MergeSemantics(
      child: Semantics(
        button: widget.onTap != null ? true : null,
        enabled: widget.onTap != null ? widget.enabled : null,
        // The highlight follows the tap gesture rather than the raw pointer,
        // so a scroll that starts on the row clears it.
        child: GestureDetector(
          onTapDown: _interactive ? (_) => _setPressed(true) : null,
          onTapUp: _interactive ? (_) => _setPressed(false) : null,
          onTapCancel: _interactive ? () => _setPressed(false) : null,
          onLongPress: widget.enabled ? widget.onLongPress : null,
          onLongPressEnd: _interactive ? (_) => _setPressed(false) : null,
          child: GlassPressable(
            onPressed: widget.enabled ? widget.onTap : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: _pressed
                        ? CupertinoDynamicColor.resolve(
                            GlassColors.listRowPressed,
                            context,
                          )
                        : GlassColors.transparent,
                  ),
                ),
                row,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
