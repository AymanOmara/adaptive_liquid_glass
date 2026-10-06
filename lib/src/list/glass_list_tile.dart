import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons, ListTile;

import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/ios_text.dart';
import '../interaction/glass_pressable.dart';
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
  final Widget? leading;

  /// Secondary text before the trailing, like Settings' "Off".
  final String? value;

  /// The row's end control, e.g. a `GlassToggle`.
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
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: ListMetrics.minRowHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ListMetrics.horizontalPadding,
          vertical: ListMetrics.verticalPadding,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.leading != null) ...[
              SizedBox.square(
                dimension: ListMetrics.leadingSize,
                child: Center(child: widget.leading),
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
                style: IOSText.style(ListMetrics.valueSize, color: secondary),
              ),
            ],
            if (widget.trailing != null) ...[
              const SizedBox(width: ListMetrics.trailingGap),
              widget.trailing!,
            ],
            if (widget.chevron) ...[
              const SizedBox(width: ListMetrics.trailingGap),
              Icon(
                CupertinoIcons.chevron_forward,
                size: ListMetrics.chevronSize,
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
