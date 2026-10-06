import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show IconButton, Icons, InputDecoration, TextField;
import 'package:flutter/services.dart' show TextInputFormatter;

import '../core/cupertino_l10n.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../core/ios_text.dart';
import '../liquid_glass.dart';
import 'text_field_metrics.dart';

/// A text field: a glass capsule on iOS 26, Material 3's [TextField] on
/// Android.
///
/// ```dart
/// GlassTextField(
///   placeholder: 'Email',
///   clearButton: true,
///   onChanged: (text) => setState(() => email = text),
/// )
/// ```
///
/// ```dart
/// const GlassTextField.password(
///   placeholder: 'Password',
///   onSubmitted: logIn,
/// )
/// ```
///
/// The text sits between an optional [prefix] and [suffix], with a clear
/// button when [clearButton] is on and the text is not empty. An
/// [errorText] shows under the field. [GlassTextField.password] obscures
/// the text and adds an eye button that shows and hides it.
class GlassTextField extends StatefulWidget {
  /// Creates a text field.
  const GlassTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.prefix,
    this.suffix,
    this.clearButton = false,
    this.errorText,
    this.enabled = true,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.autofillHints,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.semanticLabel,
    this.glass,
    this.mode,
    this.showPasswordLabel = 'Show password',
    this.hidePasswordLabel = 'Hide password',
  }) : _password = false,
       assert(
         !obscureText || maxLines == 1,
         'obscured text must be single-line',
       );

  /// Creates a password field: obscured text with an eye button that
  /// shows and hides it.
  const GlassTextField.password({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.prefix,
    this.errorText,
    this.enabled = true,
    this.textInputAction,
    this.autofillHints = const [AutofillHints.password],
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.semanticLabel,
    this.glass,
    this.mode,
    this.showPasswordLabel = 'Show password',
    this.hidePasswordLabel = 'Hide password',
  }) : obscureText = true,
       maxLines = 1,
       minLines = null,
       suffix = null,
       clearButton = false,
       keyboardType = TextInputType.visiblePassword,
       textCapitalization = TextCapitalization.none,
       autocorrect = false,
       inputFormatters = null,
       _password = true;

  /// The text; one is made when null.
  final TextEditingController? controller;

  /// The field's focus.
  final FocusNode? focusNode;

  /// The text shown while empty.
  final String? placeholder;

  /// What is shown inside the field, before the text.
  final Widget? prefix;

  /// What is shown inside the field, after the text.
  final Widget? suffix;

  /// Whether a clear button shows when the text is not empty and the
  /// field is enabled; tapping it clears the text.
  final bool clearButton;

  /// What is shown under the field; null hides it.
  final String? errorText;

  /// Whether the field can be edited.
  final bool enabled;

  /// Whether the text is shown as dots.
  final bool obscureText;

  /// The most lines; null grows the field without limit.
  final int? maxLines;

  /// The least lines the field takes.
  final int? minLines;

  /// The keyboard's type.
  final TextInputType? keyboardType;

  /// The keyboard's action button.
  final TextInputAction? textInputAction;

  /// How the keyboard capitalizes.
  final TextCapitalization textCapitalization;

  /// Whether to suggest corrections.
  final bool autocorrect;

  /// Hints for the platform's autofill service.
  final Iterable<String>? autofillHints;

  /// The field's input formatters.
  final List<TextInputFormatter>? inputFormatters;

  /// Called as the text changes, including when it is cleared.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits from the keyboard.
  final ValueChanged<String>? onSubmitted;

  /// Whether the field takes focus when shown.
  final bool autofocus;

  /// What assistive tech reads as the field's label; falls back to the
  /// placeholder.
  final String? semanticLabel;

  /// The glass. Defaults to the theme's default glass.
  final Glass? glass;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// What assistive tech reads for the eye button while the text is
  /// hidden.
  final String showPasswordLabel;

  /// What assistive tech reads for the eye button while the text is
  /// shown.
  final String hidePasswordLabel;

  /// Whether this field shows the password's eye button.
  final bool _password;

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField> {
  TextEditingController? _own;

  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController());

  /// Whether the password's text is shown.
  bool _revealed = false;

  /// Whether the field wraps its lines.
  bool get _multiLine => widget.maxLines != 1;

  /// Whether anything sits after the text.
  bool get _hasTrailing =>
      widget._password || widget.clearButton || widget.suffix != null;

  /// The text as the field shows it: hidden until revealed.
  bool get _obscured => widget.obscureText && !_revealed;

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  void _toggleRevealed() => setState(() => _revealed = !_revealed);

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, mode) =>
        mode == EffectiveGlassMode.material ? _material(context) : _glass(),
  );

  Widget _glass() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      _fieldGlass(),
      if (widget.errorText != null) ...[
        const SizedBox(height: TextFieldMetrics.errorGap),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: TextFieldMetrics.startInset,
          ),
          child: Semantics(
            liveRegion: true,
            child: Text(
              widget.errorText!,
              style: IOSText.style(
                TextFieldMetrics.errorFontSize,
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.systemRed,
                  context,
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );

  Widget _fieldGlass() {
    final secondary = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final glass = LiquidGlass(
      glass: widget.glass,
      mode: widget.mode,
      shape: _multiLine
          ? const GlassShape.rect(TextFieldMetrics.multiLineRadius)
          : const GlassShape.capsule(),
      padding: EdgeInsetsDirectional.only(
        start: widget.prefix != null
            ? TextFieldMetrics.prefixInset
            : TextFieldMetrics.startInset,
        end: _hasTrailing
            ? TextFieldMetrics.trailingInset
            : TextFieldMetrics.endInset,
        top: _multiLine ? TextFieldMetrics.multiLineVerticalPadding : 0,
        bottom: _multiLine ? TextFieldMetrics.multiLineVerticalPadding : 0,
      ),
      // Disabled dims the content, not the glass (like GlassButton).
      child: Opacity(
        opacity: widget.enabled ? 1 : TextFieldMetrics.disabledOpacity,
        child: Row(
          crossAxisAlignment: _multiLine
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (widget.prefix != null) ...[
              IconTheme.merge(
                data: IconThemeData(
                  size: TextFieldMetrics.iconSize,
                  color: secondary,
                ),
                child: widget.prefix!,
              ),
              const SizedBox(width: TextFieldMetrics.iconGap),
            ],
            Expanded(child: _cupertinoField(secondary)),
            _trailing(secondary),
          ],
        ),
      ),
    );
    return _multiLine
        ? ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: TextFieldMetrics.height,
            ),
            child: glass,
          )
        : SizedBox(height: TextFieldMetrics.height, child: glass);
  }

  Widget _cupertinoField(Color secondary) {
    final Widget field = CupertinoTextField.borderless(
      controller: _controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      placeholder: widget.placeholder,
      placeholderStyle: IOSText.style(
        TextFieldMetrics.fontSize,
        color: secondary,
      ),
      style: IOSText.style(
        TextFieldMetrics.fontSize,
        color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
      ),
      padding: EdgeInsets.zero,
      enabled: widget.enabled,
      obscureText: _obscured,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      autocorrect: widget.autocorrect,
      autofillHints: widget.autofillHints,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
    return widget.semanticLabel == null
        ? field
        : Semantics(label: widget.semanticLabel, child: field);
  }

  Widget _trailing(Color secondary) {
    if (widget._password) {
      return Semantics(
        button: true,
        label: _revealed ? widget.hidePasswordLabel : widget.showPasswordLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? _toggleRevealed : null,
          child: Padding(
            padding: const EdgeInsets.all(TextFieldMetrics.clearPadding),
            child: ExcludeSemantics(
              child: Icon(
                _revealed ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                size: TextFieldMetrics.iconSize,
                color: secondary,
              ),
            ),
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final clear =
            widget.clearButton && widget.enabled && _controller.text.isNotEmpty;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (clear)
              Semantics(
                button: true,
                label: cupertinoL10n(context).clearButtonLabel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _clear,
                  child: Padding(
                    padding: const EdgeInsets.all(
                      TextFieldMetrics.clearPadding,
                    ),
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      size: TextFieldMetrics.clearSize,
                      color: CupertinoDynamicColor.resolve(
                        CupertinoColors.tertiaryLabel,
                        context,
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.suffix != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: TextFieldMetrics.clearPadding,
                ),
                child: IconTheme.merge(
                  data: IconThemeData(
                    size: TextFieldMetrics.iconSize,
                    color: secondary,
                  ),
                  child: widget.suffix!,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _material(BuildContext context) {
    Widget field() => TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      decoration: InputDecoration(
        hintText: widget.placeholder,
        prefixIcon: widget.prefix,
        suffixIcon: _materialTrailing(context),
        errorText: widget.errorText,
        filled: true,
        enabled: widget.enabled,
      ),
      obscureText: _obscured,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      autocorrect: widget.autocorrect,
      autofillHints: widget.autofillHints,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
    final Widget body = widget.clearButton && !widget._password
        ? ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => field(),
          )
        : field();
    return widget.semanticLabel == null
        ? body
        : Semantics(label: widget.semanticLabel, child: body);
  }

  Widget? _materialTrailing(BuildContext context) {
    if (widget._password) {
      return IconButton(
        icon: Icon(_revealed ? Icons.visibility_off : Icons.visibility),
        tooltip: _revealed
            ? widget.hidePasswordLabel
            : widget.showPasswordLabel,
        onPressed: widget.enabled ? _toggleRevealed : null,
      );
    }
    final Widget? clear =
        widget.clearButton && widget.enabled && _controller.text.isNotEmpty
        ? IconButton(
            icon: const Icon(Icons.clear),
            tooltip: cupertinoL10n(context).clearButtonLabel,
            onPressed: _clear,
          )
        : null;
    if (widget.suffix == null) return clear;
    return clear == null
        ? widget.suffix
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [clear, widget.suffix!],
          );
  }
}
