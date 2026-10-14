import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;

import '../controls/glass_segment.dart';
import '../controls/glass_segmented_control.dart';
import '../core/glass_colors.dart';
import '../core/glass_render_mode.dart';
import '../core/ios_text.dart';
import 'checkerboard_painter.dart';
import 'color_channel_slider.dart';
import 'color_hex.dart';
import 'color_picker_metrics.dart';
import 'color_swatch_grid.dart';
import 'color_value_field.dart';
import 'saved_colors.dart';
import 'saved_colors_row.dart';
import 'spectrum_map.dart';

/// The pages of [GlassColorPickerPanel], as UIColorPickerViewController's
/// segmented control.
enum _Page { grid, spectrum, sliders }

/// The content of `GlassColorPicker`'s sheet, laid out as iOS 26.4's
/// UIColorPickerViewController (measured): a title with a close button,
/// a segmented control paging Grid, Spectrum and Sliders (red, green,
/// blue and the hex code), an opacity slider with its percentage, and the
/// current colour under a separator. Every change calls [onChanged] at
/// once.
///
/// ```dart
/// GlassColorPickerPanel(
///   value: colour,
///   onChanged: (c) => setState(() => colour = c),
///   title: const Text('Accent'),
///   onClose: () => Navigator.pop(context),
/// )
/// ```
///
/// The panel keeps its own colour while open and follows a new [value]
/// from its parent. The current colour sits beside the saved colours and
/// a "+" that saves it; [onEyedropper] adds UIKit's eyedropper.
class GlassColorPickerPanel extends StatefulWidget {
  /// Creates the panel.
  const GlassColorPickerPanel({
    super.key,
    required this.value,
    required this.onChanged,
    this.supportsOpacity = true,
    this.mode,
    this.title,
    this.onClose,
    this.closeLabel = 'Close',
    this.gridLabel = 'Grid',
    this.spectrumLabel = 'Spectrum',
    this.slidersLabel = 'Sliders',
    this.hueLabel = 'Hue',
    this.redLabel = 'Red',
    this.greenLabel = 'Green',
    this.blueLabel = 'Blue',
    this.opacityLabel = 'Opacity',
    this.hexLabel = 'sRGB Hex Color #',
    this.savedColors,
    this.onSavedColorsChanged,
    this.savedColorLabel = 'Saved colour',
    this.addColorLabel = 'Add to saved colours',
    this.onEyedropper,
    this.eyedropperLabel = 'Eyedropper',
  });

  /// The colour shown.
  final Color value;

  /// Called with every change.
  final ValueChanged<Color> onChanged;

  /// Whether the opacity slider is shown; off, the colour is opaque.
  final bool supportsOpacity;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// The title centred at the top, usually a [Text]; none when null.
  final Widget? title;

  /// Called by the close button at the top end; no button when null.
  final VoidCallback? onClose;

  /// The close button's screen-reader label.
  final String closeLabel;

  /// The preset grid's segment.
  final String gridLabel;

  /// The spectrum's segment and the square's screen-reader label.
  final String spectrumLabel;

  /// The sliders' segment.
  final String slidersLabel;

  /// The word for hue in the spectrum's screen-reader value.
  final String hueLabel;

  /// The red slider's caption (shown upper case).
  final String redLabel;

  /// The green slider's caption (shown upper case).
  final String greenLabel;

  /// The blue slider's caption (shown upper case).
  final String blueLabel;

  /// The opacity slider's caption (shown upper case).
  final String opacityLabel;

  /// The hex field's label.
  final String hexLabel;

  /// The saved colours beside the current one. Null shares one in-memory
  /// list between every picker (UIKit's saved colours on a fresh device
  /// to begin with), kept until the app quits.
  final List<Color>? savedColors;

  /// Called with the new list when the "+" saves the current colour or a
  /// long press removes one; with [savedColors], store it and pass it back
  /// to keep the change.
  final ValueChanged<List<Color>>? onSavedColorsChanged;

  /// A saved colour's screen-reader label, before its hex code.
  final String savedColorLabel;

  /// The "+" button's screen-reader label.
  final String addColorLabel;

  /// Called by the eyedropper at the top start; no eyedropper when null.
  /// `GlassColorPicker` hides its sheet and runs `pickColorFromApp`.
  final VoidCallback? onEyedropper;

  /// The eyedropper's screen-reader label.
  final String eyedropperLabel;

  @override
  State<GlassColorPickerPanel> createState() => _GlassColorPickerPanelState();
}

class _GlassColorPickerPanelState extends State<GlassColorPickerPanel> {
  late HSVColor _hsv = HSVColor.fromColor(widget.value.withValues(alpha: 1));
  late double _alpha = widget.supportsOpacity ? widget.value.a : 1;
  _Page _page = _Page.grid;

  /// The last colour given to [GlassColorPickerPanel.onChanged].
  late Color _emitted = widget.value;

  /// The app's saved colours as last changed here; null uses
  /// [SavedColors.shared].
  late List<Color>? _saved = widget.savedColors;

  Color get _color => _hsv.toColor().withValues(alpha: _alpha);

  Color get _opaque => _hsv.toColor();

  @override
  void didUpdateWidget(GlassColorPickerPanel old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value && widget.value != _emitted) {
      _hsv = HSVColor.fromColor(widget.value.withValues(alpha: 1));
      _alpha = widget.supportsOpacity ? widget.value.a : 1;
      _emitted = widget.value;
    }
    if (widget.savedColors != old.savedColors) _saved = widget.savedColors;
  }

  void _setSaved(List<Color> next) {
    if (_saved != null) {
      setState(() => _saved = next);
    } else {
      SavedColors.shared.value = next;
    }
    widget.onSavedColorsChanged?.call(next);
  }

  Widget _savedRow(List<Color> saved) => SavedColorsRow(
    colors: saved,
    savedLabel: widget.savedColorLabel,
    addLabel: widget.addColorLabel,
    onPick: (c) => _set(
      hsv: HSVColor.fromColor(c.withValues(alpha: 1)),
      alpha: widget.supportsOpacity ? c.a : null,
    ),
    onAdd: () => _setSaved([...saved, _color]),
    onRemove: (i) => _setSaved([...saved]..removeAt(i)),
  );

  void _set({HSVColor? hsv, double? alpha}) {
    setState(() {
      if (hsv != null) _hsv = hsv;
      if (alpha != null) _alpha = alpha;
    });
    _emitted = _color;
    widget.onChanged(_emitted);
  }

  void _setOpaque(Color c) => _set(hsv: HSVColor.fromColor(c));

  void _hexChanged(String text) {
    final parsed = parseHexColor(text);
    if (parsed == null) return;
    _set(
      hsv: HSVColor.fromColor(parsed.withValues(alpha: 1)),
      alpha: widget.supportsOpacity ? parsed.a : null,
    );
  }

  String get _hex =>
      formatHexColor(_color, withAlpha: widget.supportsOpacity).substring(1);

  TextStyle _style(
    BuildContext context,
    double size,
    CupertinoDynamicColor color, {
    FontWeight weight = FontWeight.w400,
  }) => IOSText.inFontOf(
    IOSText.style(
      size,
      weight: weight,
      color: CupertinoDynamicColor.resolve(color, context),
    ),
    DefaultTextStyle.of(context).style,
  );

  Widget _caption(BuildContext context, String text) => SizedBox(
    // The row below is the field's height; the slider sits 1 pt into it.
    height:
        ColorPickerMetrics.captionSlot -
        (ColorPickerMetrics.fieldHeight - ColorPickerMetrics.trackHeight) / 2,
    child: Align(
      alignment: AlignmentDirectional.topStart,
      child: Text(
        text.toUpperCase(),
        maxLines: 1,
        style: _style(
          context,
          ColorPickerMetrics.captionSize,
          GlassColors.secondaryLabel,
          weight: FontWeight.w600,
        ),
      ),
    ),
  );

  /// A slider with its value field after it.
  Widget _sliderRow(Widget slider, Widget field) => SizedBox(
    height: ColorPickerMetrics.fieldHeight,
    child: Row(
      children: [
        Expanded(child: slider),
        const SizedBox(width: ColorPickerMetrics.fieldGap),
        field,
      ],
    ),
  );

  @override
  // No bottom safe area: UIKit's swatch sits over the home indicator's
  // band, 14.67 pt above the floating sheet's bottom edge (measured).
  Widget build(BuildContext context) => MediaQuery.removePadding(
    context: context,
    removeBottom: true,
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          SizedBox(
            height: ColorPickerMetrics.pageTop - ColorPickerMetrics.segmentTop,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ColorPickerMetrics.padding,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: GlassSegmentedControl<_Page>(
                  selected: _page,
                  mode: widget.mode,
                  trackHeight: ColorPickerMetrics.segmentHeight,
                  onChanged: (p) => setState(() => _page = p),
                  segments: [
                    GlassSegment(
                      value: _Page.grid,
                      label: Text(widget.gridLabel),
                    ),
                    GlassSegment(
                      value: _Page.spectrum,
                      label: Text(widget.spectrumLabel),
                    ),
                    GlassSegment(
                      value: _Page.sliders,
                      label: Text(widget.slidersLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ColorPickerMetrics.padding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // At least the measured page; a wider sheet's grid
                // (square cells) is taller, and every page takes its size.
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: ColorPickerMetrics.pageHeight,
                  ),
                  child: IndexedStack(
                    index: _page.index,
                    children: [
                      ColorSwatchGrid(selected: _color, onSelected: _setOpaque),
                      _spectrum(),
                      _sliders(context),
                    ],
                  ),
                ),
                if (widget.supportsOpacity) ...[
                  const SizedBox(height: ColorPickerMetrics.opacityGap),
                  _caption(context, widget.opacityLabel),
                  _sliderRow(
                    ColorChannelSlider(
                      value: _alpha,
                      checkerboard: true,
                      colors: [_opaque.withValues(alpha: 0), _opaque],
                      thumbColor: _color,
                      semanticLabel: widget.opacityLabel,
                      onChanged: (a) => _set(alpha: a),
                    ),
                    ColorValueField(
                      text: '${(_alpha * 100).round()}%',
                      width: ColorPickerMetrics.fieldWidth,
                      semanticLabel: widget.opacityLabel,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[0-9%]')),
                        LengthLimitingTextInputFormatter(4),
                      ],
                      onChanged: (t) {
                        final v = int.tryParse(t.replaceAll('%', ''));
                        if (v != null) _set(alpha: v.clamp(0, 100) / 100);
                      },
                    ),
                  ),
                ],
                const SizedBox(height: ColorPickerMetrics.separatorGap),
                Container(
                  height: 1 / 3,
                  color: CupertinoDynamicColor.resolve(
                    GlassColors.colorPickerSeparator,
                    context,
                  ),
                ),
                const SizedBox(height: ColorPickerMetrics.swatchGap),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: ClipRRect(
                        key: const ValueKey('current-colour'),
                        borderRadius: BorderRadius.circular(
                          ColorPickerMetrics.swatchRadius,
                        ),
                        child: CustomPaint(
                          painter: _alpha < 1
                              ? const CheckerboardPainter()
                              : null,
                          child: SizedBox.square(
                            dimension: ColorPickerMetrics.swatch,
                            child: ColoredBox(color: _color),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: ColorPickerMetrics.savedStart),
                    Expanded(
                      child: _saved != null
                          ? _savedRow(_saved!)
                          : ValueListenableBuilder<List<Color>>(
                              valueListenable: SavedColors.shared,
                              builder: (context, saved, _) => _savedRow(saved),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: ColorPickerMetrics.bottomPadding),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _header(BuildContext context) => SizedBox(
    height: ColorPickerMetrics.segmentTop,
    child: Stack(
      children: [
        if (widget.title != null)
          Positioned.fill(
            bottom:
                ColorPickerMetrics.segmentTop - ColorPickerMetrics.headerHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ColorPickerMetrics.closeTarget,
                ),
                child: DefaultTextStyle(
                  style: _style(
                    context,
                    ColorPickerMetrics.titleSize,
                    GlassColors.label,
                    weight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: Semantics(header: true, child: widget.title!),
                ),
              ),
            ),
          ),
        if (widget.onEyedropper != null)
          PositionedDirectional(
            start:
                ColorPickerMetrics.eyedropperInset -
                ColorPickerMetrics.closeTarget / 2,
            top:
                ColorPickerMetrics.eyedropperCentre -
                ColorPickerMetrics.closeTarget / 2,
            width: ColorPickerMetrics.closeTarget,
            height: ColorPickerMetrics.closeTarget,
            child: Semantics(
              button: true,
              label: widget.eyedropperLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onEyedropper,
                child: Center(
                  child: ExcludeSemantics(
                    child: Icon(
                      CupertinoIcons.eyedropper,
                      size: ColorPickerMetrics.eyedropperGlyph,
                      color: CupertinoDynamicColor.resolve(
                        GlassColors.label,
                        context,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (widget.onClose != null)
          PositionedDirectional(
            end:
                ColorPickerMetrics.closeInset -
                ColorPickerMetrics.closeTarget / 2,
            top:
                (ColorPickerMetrics.headerHeight -
                    ColorPickerMetrics.closeTarget) /
                2,
            width: ColorPickerMetrics.closeTarget,
            height: ColorPickerMetrics.closeTarget,
            child: Semantics(
              button: true,
              label: widget.closeLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: Center(
                  child: ExcludeSemantics(
                    child: SizedBox.square(
                      dimension: ColorPickerMetrics.closeGlyph,
                      child: CustomPaint(
                        painter: _XmarkPainter(
                          CupertinoDynamicColor.resolve(
                            GlassColors.label,
                            context,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _spectrum() => SpectrumMap(
    color: _hsv,
    onChanged: (c) => _set(hsv: c),
    semanticLabel: widget.spectrumLabel,
    hueLabel: widget.hueLabel,
  );

  Widget _channel(
    BuildContext context,
    String label,
    int value,
    Color Function(int v) at,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _caption(context, label),
      _sliderRow(
        ColorChannelSlider(
          value: value / 255,
          colors: [at(0), at(255)],
          thumbColor: _opaque,
          semanticLabel: label,
          semanticValue: (v) => '${(v * 255).round()}',
          onChanged: (v) => _setOpaque(at((v * 255).round())),
        ),
        ColorValueField(
          text: '$value',
          width: ColorPickerMetrics.fieldWidth,
          semanticLabel: label,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          onChanged: (t) {
            final v = int.tryParse(t);
            if (v != null) _setOpaque(at(v.clamp(0, 255)));
          },
        ),
      ),
    ],
  );

  Widget _sliders(BuildContext context) {
    final c = _opaque;
    final r = (c.r * 255).round();
    final g = (c.g * 255).round();
    final b = (c.b * 255).round();
    const pitchGap =
        ColorPickerMetrics.channelPitch -
        ColorPickerMetrics.captionSlot -
        (ColorPickerMetrics.fieldHeight + ColorPickerMetrics.trackHeight) / 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: ColorPickerMetrics.channelTop),
        _channel(
          context,
          widget.redLabel,
          r,
          (v) => Color.fromARGB(255, v, g, b),
        ),
        const SizedBox(height: pitchGap),
        _channel(
          context,
          widget.greenLabel,
          g,
          (v) => Color.fromARGB(255, r, v, b),
        ),
        const SizedBox(height: pitchGap),
        _channel(
          context,
          widget.blueLabel,
          b,
          (v) => Color.fromARGB(255, r, g, v),
        ),
        const SizedBox(
          height:
              ColorPickerMetrics.hexTop -
              ColorPickerMetrics.channelTop -
              3 * ColorPickerMetrics.channelPitch +
              pitchGap,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                widget.hexLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _style(
                  context,
                  ColorPickerMetrics.fieldTextSize,
                  GlassColors.colorPickerHexLabel,
                ),
              ),
            ),
            const SizedBox(width: ColorPickerMetrics.fieldGap),
            ColorValueField(
              text: _hex,
              width: ColorPickerMetrics.hexFieldWidth,
              semanticLabel: widget.hexLabel,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
                LengthLimitingTextInputFormatter(9),
              ],
              onChanged: _hexChanged,
            ),
          ],
        ),
      ],
    );
  }
}

/// iOS's plain xmark: two strokes corner to corner.
class _XmarkPainter extends CustomPainter {
  const _XmarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const i = 1.0;
    canvas
      ..drawLine(
        const Offset(i, i),
        Offset(size.width - i, size.height - i),
        paint,
      )
      ..drawLine(Offset(size.width - i, i), Offset(i, size.height - i), paint);
  }

  @override
  bool shouldRepaint(_XmarkPainter old) => old.color != color;
}
