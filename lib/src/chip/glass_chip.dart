import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show FilterChip, InputChip;

import '../core/effective_glass_mode.dart';
import '../core/glass.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_system_colors.dart';
import '../core/ios_text.dart';
import '../core/theme.dart';
import '../liquid_glass.dart';
import 'chip_metrics.dart';

/// A glass capsule chip with an optional leading icon, a selected state
/// (tinted glass) and an optional delete button.
///
/// ```dart
/// GlassChip(
///   label: 'Whale watching',
///   icon: CupertinoIcons.tag,
///   selected: picked,
///   onSelected: (v) => setState(() => picked = v),
///   onDeleted: () => remove('Whale watching'),
/// )
/// ```
///
/// A tap toggles [selected] through [onSelected]; without it the chip is a
/// display-only tag, and [onDeleted] alone makes it an input chip. On the
/// Material path it is a Material 3 `FilterChip`, or an `InputChip` when
/// [onSelected] is null.
class GlassChip extends StatelessWidget {
  /// Creates a chip.
  const GlassChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onSelected,
    this.onDeleted,
    this.deleteLabel,
    this.selectedColor,
    this.glass,
    this.mode,
  });

  /// The chip's text.
  final String label;

  /// An icon before the label.
  final IconData? icon;

  /// Whether the chip is selected (tinted glass, white label).
  final bool selected;

  /// Called with the new value on tap; null makes the chip not tappable.
  final ValueChanged<bool>? onSelected;

  /// Shows a delete button at the end; called when it is tapped.
  final VoidCallback? onDeleted;

  /// What assistive tech reads for the delete button. Defaults to
  /// "Remove $label".
  final String? deleteLabel;

  /// The selected tint; defaults to iOS 26's blue.
  final Color? selectedColor;

  /// The unselected glass. Defaults to the theme's default glass.
  final Glass? glass;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? _material(context)
        : _glass(context),
  );

  Widget _material(BuildContext context) => onSelected != null
      ? FilterChip(
          label: Text(label),
          avatar: icon == null ? null : Icon(icon),
          selected: selected,
          onSelected: onSelected,
          onDeleted: onDeleted,
          deleteButtonTooltipMessage: deleteLabel ?? 'Remove $label',
          selectedColor: selectedColor == null
              ? null
              : CupertinoDynamicColor.resolve(selectedColor!, context),
        )
      : InputChip(
          label: Text(label),
          avatar: icon == null ? null : Icon(icon),
          onDeleted: onDeleted,
          deleteButtonTooltipMessage: deleteLabel ?? 'Remove $label',
          isEnabled: true,
        );

  Widget _glass(BuildContext context) {
    // A flat colour: `Glass.tint` keeps what it is given, and a resolved
    // CupertinoDynamicColor would stay a dynamic instance.
    Color resolve(Color c) =>
        Color(CupertinoDynamicColor.resolve(c, context).toARGB32());
    final content = Semantics(
      // Merges into the glass's own button node; a display-only chip is
      // not selectable.
      selected: onSelected == null ? null : selected,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: ChipMetrics.iconSize),
            const SizedBox(width: ChipMetrics.iconGap),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: IOSText.style(
              ChipMetrics.labelSize,
              weight: FontWeight.w500,
              color: selected ? GlassColors.white : null,
            ),
          ),
          if (onDeleted != null) ...[
            const SizedBox(
              width: ChipMetrics.iconGap - ChipMetrics.deleteHitPadding,
            ),
            Semantics(
              container: true,
              button: true,
              label: deleteLabel ?? 'Remove $label',
              onTap: onDeleted,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDeleted,
                excludeFromSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.all(ChipMetrics.deleteHitPadding),
                  child: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    size: ChipMetrics.deleteSize,
                    color: selected
                        ? GlassColors.white
                        : CupertinoDynamicColor.resolve(
                            GlassColors.secondaryLabel,
                            context,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return SizedBox(
      height: ChipMetrics.height,
      child: LiquidGlass(
        glass: selected
            ? (glass ?? LiquidGlassTheme.of(context).defaultGlass).tint(
                resolve(selectedColor ?? GlassSystemColors.blue),
              )
            : glass,
        mode: mode,
        onPressed: onSelected == null ? null : () => onSelected!(!selected),
        padding: EdgeInsetsDirectional.only(
          start: ChipMetrics.horizontalPadding,
          end: onDeleted == null
              ? ChipMetrics.horizontalPadding
              : ChipMetrics.deletePadding,
        ),
        child: selected
            ? IconTheme.merge(
                data: const IconThemeData(color: GlassColors.white),
                child: content,
              )
            : content,
      ),
    );
  }
}
