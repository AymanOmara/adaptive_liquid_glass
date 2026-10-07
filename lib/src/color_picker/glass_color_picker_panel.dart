import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;

import '../controls/glass_slider.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/ios_text.dart';
import '../text_field/glass_text_field.dart';
import 'color_hex.dart';
import 'color_picker_metrics.dart';
import 'color_swatch_grid.dart';
import 'hsv_spectrum.dart';
import 'hue_bar.dart';

/// The content of `GlassColorPicker`'s sheet: the preset grid, the
/// spectrum square with its hue bar, an opacity slider and a hex field.
/// Every change calls [onChanged] at once.
///
/// ```dart
/// GlassColorPickerPanel(
///   value: colour,
///   onChanged: (c) => setState(() => colour = c),
/// )
/// ```
///
/// The panel keeps its own colour while open and follows a new [value]
/// from its parent. Its controls are the package's own, so each picks
/// the glass or Material path by [mode] on its own.
class GlassColorPickerPanel extends StatefulWidget {
  /// Creates the panel.
  const GlassColorPickerPanel({
    super.key,
    required this.value,
    required this.onChanged,
    this.supportsOpacity = true,
    this.mode,
    this.gridLabel = 'Grid',
    this.spectrumLabel = 'Spectrum',
    this.hueLabel = 'Hue',
    this.opacityLabel = 'Opacity',
    this.hexLabel = 'Hex',
  });

  /// The colour shown.
  final Color value;

  /// Called with every change.
  final ValueChanged<Color> onChanged;

  /// Whether the opacity slider is shown; off, the colour is opaque.
  final bool supportsOpacity;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// The preset grid's title and screen-reader label.
  final String gridLabel;

  /// The spectrum section's title and the square's screen-reader label.
  final String spectrumLabel;

  /// The hue bar's screen-reader label.
  final String hueLabel;

  /// The opacity row's label.
  final String opacityLabel;

  /// The hex row's label.
  final String hexLabel;

  @override
  State<GlassColorPickerPanel> createState() => _GlassColorPickerPanelState();
}

class _GlassColorPickerPanelState extends State<GlassColorPickerPanel> {
  late HSVColor _hsv = HSVColor.fromColor(widget.value.withValues(alpha: 1));
  late double _alpha = widget.supportsOpacity ? widget.value.a : 1;
  late final TextEditingController _hex = TextEditingController(
    text: _format(_color),
  );
  final FocusNode _hexFocus = FocusNode();

  /// The last colour given to [GlassColorPickerPanel.onChanged].
  late Color _emitted = widget.value;

  Color get _color => _hsv.toColor().withValues(alpha: _alpha);

  String _format(Color c) =>
      formatHexColor(c, withAlpha: widget.supportsOpacity);

  @override
  void didUpdateWidget(GlassColorPickerPanel old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value && widget.value != _emitted) {
      _hsv = HSVColor.fromColor(widget.value.withValues(alpha: 1));
      _alpha = widget.supportsOpacity ? widget.value.a : 1;
      _emitted = widget.value;
      _hex.text = _format(_color);
    }
  }

  @override
  void dispose() {
    _hex.dispose();
    _hexFocus.dispose();
    super.dispose();
  }

  /// Applies a change from a control other than the hex field.
  void _set({HSVColor? hsv, double? alpha}) {
    setState(() {
      if (hsv != null) _hsv = hsv;
      if (alpha != null) _alpha = alpha;
      _hex.text = _format(_color);
    });
    _emit();
  }

  void _emit() {
    _emitted = _color;
    widget.onChanged(_emitted);
  }

  void _hexChanged(String text) {
    final parsed = parseHexColor(text);
    if (parsed == null) return;
    setState(() {
      _hsv = HSVColor.fromColor(parsed.withValues(alpha: 1));
      if (widget.supportsOpacity) _alpha = parsed.a;
    });
    _emit();
  }

  void _hexSubmitted(String _) => _hex.text = _format(_color);

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, effective) =>
        _content(context, effective == EffectiveGlassMode.material),
  );

  TextStyle? _title(BuildContext context, bool material) => material
      ? null
      : IOSText.style(
          ColorPickerMetrics.titleSize,
          weight: FontWeight.w600,
          color: CupertinoDynamicColor.resolve(
            CupertinoColors.secondaryLabel,
            context,
          ),
        );

  TextStyle? _label(BuildContext context, bool material) => material
      ? null
      : IOSText.style(
          ColorPickerMetrics.labelSize,
          color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
        );

  Widget _content(BuildContext context, bool material) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(ColorPickerMetrics.padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.gridLabel, style: _title(context, material)),
          const SizedBox(height: ColorPickerMetrics.titleGap),
          ColorSwatchGrid(
            selected: _color,
            onSelected: (c) => _set(hsv: HSVColor.fromColor(c)),
          ),
          const SizedBox(height: ColorPickerMetrics.sectionGap),
          Text(widget.spectrumLabel, style: _title(context, material)),
          const SizedBox(height: ColorPickerMetrics.titleGap),
          HsvSpectrum(
            color: _hsv,
            onChanged: (c) => _set(hsv: c),
            semanticLabel: widget.spectrumLabel,
          ),
          const SizedBox(height: ColorPickerMetrics.hueBarGap),
          HueBar(
            color: _hsv,
            onChanged: (c) => _set(hsv: c),
            semanticLabel: widget.hueLabel,
          ),
          if (widget.supportsOpacity) ...[
            const SizedBox(height: ColorPickerMetrics.sectionGap),
            Row(
              children: [
                SizedBox(
                  width: ColorPickerMetrics.labelWidth,
                  child: Text(
                    widget.opacityLabel,
                    style: _label(context, material),
                  ),
                ),
                const SizedBox(width: ColorPickerMetrics.labelGap),
                Expanded(
                  child: GlassSlider(
                    value: _alpha,
                    onChanged: (a) => _set(alpha: a),
                    mode: widget.mode,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: ColorPickerMetrics.sectionGap),
          Row(
            children: [
              SizedBox(
                width: ColorPickerMetrics.labelWidth,
                child: Text(widget.hexLabel, style: _label(context, material)),
              ),
              const SizedBox(width: ColorPickerMetrics.labelGap),
              SizedBox(
                width: ColorPickerMetrics.hexWidth,
                child: GlassTextField(
                  controller: _hex,
                  focusNode: _hexFocus,
                  semanticLabel: widget.hexLabel,
                  keyboardType: TextInputType.text,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
                    LengthLimitingTextInputFormatter(9),
                  ],
                  onChanged: _hexChanged,
                  onSubmitted: _hexSubmitted,
                  mode: widget.mode,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
