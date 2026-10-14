import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ListTile, showModalBottomSheet;

import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../list/glass_list_tile.dart';
import '../sheet/glass_sheet_detent.dart';
import '../sheet/show_glass_sheet.dart';
import 'color_hex.dart';
import 'color_picker_metrics.dart';
import 'color_swatch_dot.dart';
import 'glass_color_picker_panel.dart';

/// iOS 26's colour picker row, like SwiftUI's `ColorPicker`: a label at
/// the start and a round swatch at the end, opening a glass sheet laid out
/// as UIColorPickerViewController's: the label as its title, a close
/// button, Grid / Spectrum / Sliders pages, an opacity slider and the
/// current colour.
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
/// bottom sheet with the same content. The sheet's geometry is measured
/// from UIKit on iOS 26.4; the spectrum page keeps a saturation-value
/// square and hue bar where UIKit draws one hue-by-brightness map.
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
    this.slidersLabel = 'Sliders',
    this.hueLabel = 'Hue',
    this.opacityLabel = 'Opacity',
    this.hexLabel = 'sRGB Hex Color #',
    this.closeLabel = 'Close',
    this.savedColors,
    this.onSavedColorsChanged,
    this.savedColorLabel = 'Saved colour',
    this.addColorLabel = 'Add to saved colours',
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

  /// The sheet's preset grid segment.
  final String gridLabel;

  /// The sheet's spectrum segment.
  final String spectrumLabel;

  /// The sheet's sliders segment (red, green, blue and the hex code).
  final String slidersLabel;

  /// The sheet's close button screen-reader label.
  final String closeLabel;

  /// The word for hue in the spectrum's screen-reader value.
  final String hueLabel;

  /// The sheet's opacity caption.
  final String opacityLabel;

  /// The sheet's hex field label.
  final String hexLabel;

  /// The saved colours beside the current one in the sheet. Null shares
  /// one in-memory list between every picker, starting with UIKit's
  /// (black, blue, green, yellow, red), kept until the app quits.
  final List<Color>? savedColors;

  /// Called with the new saved colours when the sheet's "+" saves the
  /// current colour or a long press removes one. With [savedColors],
  /// store the list (persist it if you like) and pass it back.
  final ValueChanged<List<Color>>? onSavedColorsChanged;

  /// A saved colour's screen-reader label, before its hex code.
  final String savedColorLabel;

  /// The sheet's "+" (save the colour) screen-reader label.
  final String addColorLabel;

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
    title: widget.label,
    onClose: () => Navigator.of(context).maybePop(),
    closeLabel: widget.closeLabel,
    gridLabel: widget.gridLabel,
    spectrumLabel: widget.spectrumLabel,
    slidersLabel: widget.slidersLabel,
    hueLabel: widget.hueLabel,
    opacityLabel: widget.opacityLabel,
    hexLabel: widget.hexLabel,
    savedColors: widget.savedColors,
    onSavedColorsChanged: widget.onSavedColorsChanged,
    savedColorLabel: widget.savedColorLabel,
    addColorLabel: widget.addColorLabel,
  );

  /// UIColorPickerViewController's sheet: 601 pt tall (less the opacity
  /// row without opacity), floating, no grabber (measured).
  Future<void> _showGlass() => showGlassSheet<void>(
    context: context,
    detents: [
      GlassSheetDetent.contentHeight(
        ColorPickerMetrics.sheetHeight -
            (widget.supportsOpacity ? 0 : ColorPickerMetrics.opacityBlock),
      ),
    ],
    showGrabber: false,
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
