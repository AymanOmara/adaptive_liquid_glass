import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show InputDecoration, OutlineInputBorder, TextField;
import 'package:flutter/services.dart' show TextInputFormatter;

import '../core/effective_glass_mode.dart';
import '../core/glass.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../core/ios_text.dart';
import '../liquid_glass.dart';
import '../scroll_indicators/glass_scroll_indicator_visibility.dart';
import '../scroll_indicators/glass_scroll_indicators.dart';
import 'text_field_metrics.dart';

/// A scrolling, multi-line text editor, as SwiftUI's `TextEditor` in a
/// glass rounded rectangle on iOS 26; a filled Material 3 [TextField]
/// that expands to its height on Android.
///
/// ```dart
/// SizedBox(
///   height: 240,
///   child: GlassTextEditor(
///     controller: notes,
///     placeholder: 'Notes',
///   ),
/// )
/// ```
///
/// The editor fills the height its parent gives it, or
/// [height] (200 by default) when the parent leaves the height unbounded.
/// Its text scrolls inside it, with UIKit-style scroll indicators
/// ([scrollIndicators]). While the keyboard covers part of the editor, the
/// covered part is left out of the text area, so the caret and the last
/// lines can always be scrolled into view.
class GlassTextEditor extends StatefulWidget {
  /// Creates a text editor.
  const GlassTextEditor({
    super.key,
    this.controller,
    this.focusNode,
    this.scrollController,
    this.placeholder,
    this.height,
    this.enabled = true,
    this.readOnly = false,
    this.keyboardType = TextInputType.multiline,
    this.textCapitalization = TextCapitalization.sentences,
    this.autocorrect = true,
    this.inputFormatters,
    this.onChanged,
    this.autofocus = false,
    this.semanticLabel,
    this.scrollIndicators = GlassScrollIndicatorVisibility.automatic,
    this.glass,
    this.mode,
  });

  /// The text; one is made when null.
  final TextEditingController? controller;

  /// The editor's focus.
  final FocusNode? focusNode;

  /// The text's scroll position.
  final ScrollController? scrollController;

  /// The text shown while empty.
  final String? placeholder;

  /// The height when the parent's is unbounded; defaults to 200.
  final double? height;

  /// Whether the text can be edited and selected.
  final bool enabled;

  /// Whether the text can be selected but not changed.
  final bool readOnly;

  /// The keyboard's type.
  final TextInputType keyboardType;

  /// How the keyboard capitalizes.
  final TextCapitalization textCapitalization;

  /// Whether to suggest corrections.
  final bool autocorrect;

  /// The editor's input formatters.
  final List<TextInputFormatter>? inputFormatters;

  /// Called as the text changes.
  final ValueChanged<String>? onChanged;

  /// Whether the editor takes focus when shown.
  final bool autofocus;

  /// What assistive tech reads as the editor's label; falls back to the
  /// placeholder.
  final String? semanticLabel;

  /// Whether the text's scroll indicators show, as SwiftUI's
  /// `.scrollIndicators(_:)`.
  final GlassScrollIndicatorVisibility scrollIndicators;

  /// The glass. Defaults to the theme's default glass.
  final Glass? glass;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassTextEditor> createState() => _GlassTextEditorState();
}

class _GlassTextEditorState extends State<GlassTextEditor> {
  TextEditingController? _ownText;
  ScrollController? _ownScroll;

  TextEditingController get _controller =>
      widget.controller ?? (_ownText ??= TextEditingController());

  ScrollController get _scroll =>
      widget.scrollController ?? (_ownScroll ??= ScrollController());

  final GlobalKey _box = GlobalKey();

  /// How far the keyboard reaches up into the editor.
  double _covered = 0;

  @override
  void dispose() {
    _ownText?.dispose();
    _ownScroll?.dispose();
    super.dispose();
  }

  /// Measures [_covered] after layout, as UITextView adjusts its content
  /// inset for the keyboard.
  void _measureKeyboard(double keyboard) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _box.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || !box.attached) return;
      final screen = MediaQuery.sizeOf(context).height;
      final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      final covered = keyboard == 0
          ? 0.0
          : (bottom - (screen - keyboard)).clamp(0.0, box.size.height);
      if ((covered - _covered).abs() > 0.5) {
        setState(() => _covered = covered);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _measureKeyboard(MediaQuery.viewInsetsOf(context).bottom);
    return LayoutBuilder(
      builder: (context, constraints) {
        final editor = GlassModeBuilder(
          mode: widget.mode,
          builder: (context, mode) => mode == EffectiveGlassMode.material
              ? _material(context)
              : _glass(context),
        );
        return SizedBox(
          key: _box,
          height: constraints.hasBoundedHeight
              ? null
              : widget.height ?? TextFieldMetrics.editorHeight,
          child: editor,
        );
      },
    );
  }

  Widget _semantics(Widget field) => widget.semanticLabel == null
      ? field
      : Semantics(label: widget.semanticLabel, child: field);

  Widget _glass(BuildContext context) {
    final secondary = CupertinoDynamicColor.resolve(
      GlassColors.secondaryLabel,
      context,
    );
    final field = CupertinoTextField.borderless(
      controller: _controller,
      focusNode: widget.focusNode,
      scrollController: _scroll,
      autofocus: widget.autofocus,
      placeholder: widget.placeholder,
      placeholderStyle: IOSText.style(
        TextFieldMetrics.fontSize,
        color: secondary,
      ),
      style: IOSText.style(
        TextFieldMetrics.fontSize,
        color: CupertinoDynamicColor.resolve(GlassColors.label, context),
      ),
      // Start and end insets are equal, so no direction is needed.
      padding: const EdgeInsets.symmetric(
        horizontal: TextFieldMetrics.editorHorizontalInset,
        vertical: TextFieldMetrics.editorVerticalInset,
      ),
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      expands: true,
      maxLines: null,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      autocorrect: widget.autocorrect,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
    );
    return LiquidGlass(
      glass: widget.glass,
      mode: widget.mode,
      shape: const GlassShape.rect(TextFieldMetrics.multiLineRadius),
      child: Opacity(
        opacity: widget.enabled ? 1 : TextFieldMetrics.disabledOpacity,
        child: Padding(
          padding: EdgeInsets.only(bottom: math.max(0, _covered)),
          child: GlassScrollIndicators(
            visibility: widget.scrollIndicators,
            controller: _scroll,
            mode: widget.mode,
            child: _semantics(field),
          ),
        ),
      ),
    );
  }

  static const _materialShape = OutlineInputBorder(
    borderSide: BorderSide.none,
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );

  Widget _material(BuildContext context) {
    final field = TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      scrollController: _scroll,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      expands: true,
      maxLines: null,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      autocorrect: widget.autocorrect,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.placeholder,
        filled: true,
        border: _materialShape,
        enabledBorder: _materialShape,
        focusedBorder: _materialShape,
        disabledBorder: _materialShape,
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: math.max(0, _covered)),
      child: GlassScrollIndicators(
        visibility: widget.scrollIndicators,
        controller: _scroll,
        mode: widget.mode,
        child: _semantics(field),
      ),
    );
  }
}
