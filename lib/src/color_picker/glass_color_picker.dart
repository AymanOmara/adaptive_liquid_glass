import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ListTile, showModalBottomSheet;

import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../list/glass_list_tile.dart';
import '../sheet/glass_sheet_detent.dart';
import '../sheet/show_glass_sheet.dart';
import 'color_hex.dart';
import 'color_swatch_dot.dart';
import 'glass_color_picker_panel.dart';

/// iOS 26's colour picker row, like SwiftUI's `ColorPicker`: a label at
/// the start and a round swatch at the end, opening a glass sheet with a
/// preset grid, a spectrum, an opacity slider and a hex field.
///
/// ```dart
/// GlassColorPicker(
///   label: const Text('Accent'),
///   value: accent,
///   onChanged: (c) => setState(() => accent = c),
/// )
/// ```
///
/// Every change in the sheet calls [onChanged] at once, so the swatch and
/// the app follow it live. Without [supportsOpacity] the sheet has no
/// opacity slider and the colour is always opaque. Null [onChanged]
/// disables the row. Put the row in a `GlassListSection` for a platter.
/// On the Material path it is a Material 3 [ListTile] opening a modal
/// bottom sheet with the same content. The geometry is estimated, not
/// yet measured against SwiftUI.
class GlassColorPicker extends StatefulWidget {
  /// Creates a colour picker row.
  const GlassColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.supportsOpacity = true,
    this.mode,
    this.semanticLabel,
    this.gridLabel = 'Grid',
    this.spectrumLabel = 'Spectrum',
    this.hueLabel = 'Hue',
    this.opacityLabel = 'Opacity',
    this.hexLabel = 'Hex',
  });

  /// The selected colour.
  final Color value;

  /// Called with every change made in the sheet; null disables the row.
  final ValueChanged<Color>? onChanged;

  /// The row's label, usually a [Text].
  final Widget label;

  /// Whether the sheet lets the user set the colour's opacity.
  final bool supportsOpacity;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// What assistive tech reads as the row's label instead of [label].
  final String? semanticLabel;

  /// The sheet's preset grid title.
  final String gridLabel;

  /// The sheet's spectrum title.
  final String spectrumLabel;

  /// The hue bar's screen-reader label.
  final String hueLabel;

  /// The sheet's opacity row label.
  final String opacityLabel;

  /// The sheet's hex row label.
  final String hexLabel;

  @override
  State<GlassColorPicker> createState() => _GlassColorPickerState();
}

class _GlassColorPickerState extends State<GlassColorPicker> {
  bool get _enabled => widget.onChanged != null;

  /// The sheet's content; it keeps the colour while open and reports
  /// every change through [GlassColorPicker.onChanged].
  Widget _panel(BuildContext context) => GlassColorPickerPanel(
    value: widget.value,
    onChanged: (c) => widget.onChanged?.call(c),
    supportsOpacity: widget.supportsOpacity,
    mode: widget.mode,
    gridLabel: widget.gridLabel,
    spectrumLabel: widget.spectrumLabel,
    hueLabel: widget.hueLabel,
    opacityLabel: widget.opacityLabel,
    hexLabel: widget.hexLabel,
  );

  Future<void> _showGlass() => showGlassSheet<void>(
    context: context,
    detents: const [GlassSheetDetent.large],
    mode: widget.mode,
    builder: _panel,
  );

  Future<void> _showMaterial() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: _panel,
  );

  @override
  Widget build(BuildContext context) {
    final hex = formatHexColor(widget.value, withAlpha: widget.supportsOpacity);
    final title = widget.semanticLabel == null
        ? widget.label
        : ExcludeSemantics(child: widget.label);
    final swatch = ExcludeSemantics(
      child: ColorSwatchDot(
        color: widget.supportsOpacity
            ? widget.value
            : widget.value.withValues(alpha: 1),
      ),
    );
    return GlassModeBuilder(
      mode: widget.mode,
      builder: (context, effective) => MergeSemantics(
        child: Semantics(
          button: true,
          enabled: _enabled,
          label: widget.semanticLabel,
          value: hex,
          child: effective == EffectiveGlassMode.material
              ? ListTile(
                  title: title,
                  trailing: swatch,
                  enabled: _enabled,
                  onTap: _enabled ? _showMaterial : null,
                )
              : GlassListTile(
                  title: title,
                  trailing: swatch,
                  enabled: _enabled,
                  onTap: _enabled ? _showGlass : null,
                  mode: widget.mode,
                ),
        ),
      ),
    );
  }
}
