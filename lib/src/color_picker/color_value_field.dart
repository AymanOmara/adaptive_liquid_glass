import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show TextInputFormatter;

import '../core/glass_colors.dart';
import '../core/ios_text.dart';
import 'color_picker_metrics.dart';

/// The small editable field beside a colour picker slider ("100%", "255")
/// or after the hex label, as UIColorPickerViewController draws it (iOS
/// 26.4, measured): a rounded fill 34.67 pt tall with centred 17-pt text.
///
/// ```dart
/// ColorValueField(
///   text: '255',
///   width: ColorPickerMetrics.fieldWidth,
///   onChanged: (t) => apply(t),
/// )
/// ```
///
/// While focused it keeps what is typed; otherwise it shows [text].
class ColorValueField extends StatefulWidget {
  /// Creates the field.
  const ColorValueField({
    super.key,
    required this.text,
    required this.width,
    required this.onChanged,
    this.onSubmitted,
    this.semanticLabel,
    this.keyboardType = TextInputType.number,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  /// The value shown while the field is not being edited.
  final String text;

  /// The field's width.
  final double width;

  /// Called with every edit.
  final ValueChanged<String> onChanged;

  /// Called when editing is done; [text] is shown again afterwards.
  final ValueChanged<String>? onSubmitted;

  /// What assistive tech reads for the field.
  final String? semanticLabel;

  /// The keyboard to show.
  final TextInputType keyboardType;

  /// Restricts what can be typed.
  final List<TextInputFormatter>? inputFormatters;

  /// The keyboard's capitalisation.
  final TextCapitalization textCapitalization;

  @override
  State<ColorValueField> createState() => _ColorValueFieldState();
}

class _ColorValueFieldState extends State<ColorValueField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (!_focus.hasFocus && _controller.text != widget.text) {
      _controller.text = widget.text;
    }
  }

  @override
  void didUpdateWidget(ColorValueField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _controller.text != widget.text) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: ColorPickerMetrics.fieldHeight,
    child: Semantics(
      label: widget.semanticLabel,
      textField: true,
      child: CupertinoTextField(
        controller: _controller,
        focusNode: _focus,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        autocorrect: false,
        inputFormatters: widget.inputFormatters,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        style: IOSText.style(
          ColorPickerMetrics.fieldTextSize,
          color: CupertinoDynamicColor.resolve(GlassColors.label, context),
        ),
        decoration: BoxDecoration(
          color: CupertinoDynamicColor.resolve(
            GlassColors.colorPickerField,
            context,
          ),
          borderRadius: BorderRadius.circular(ColorPickerMetrics.fieldRadius),
        ),
        onChanged: widget.onChanged,
        onSubmitted: (t) {
          widget.onSubmitted?.call(t);
          _controller.text = widget.text;
        },
      ),
    ),
  );
}
