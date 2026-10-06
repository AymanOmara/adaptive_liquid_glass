import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SearchBar;

import '../core/cupertino_l10n.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/ios_text.dart';
import '../liquid_glass.dart';
import 'search_metrics.dart';

/// iOS 26's search field: a glass capsule with a magnifying glass, the
/// text and a clear button.
///
/// ```dart
/// GlassSearchField(onChanged: (query) => setState(() => this.query = query))
/// ```
///
/// The placeholder defaults to the localized "Search". Put it in a
/// `GlassScaffold.bottomAccessory` slot or a toolbar for iOS 26's bottom
/// search. On the Material path it is a Material 3 [SearchBar].
class GlassSearchField extends StatefulWidget {
  /// Creates a search field.
  const GlassSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.glass,
    this.mode,
  });

  /// The text; one is made when null.
  final TextEditingController? controller;

  /// The field's focus.
  final FocusNode? focusNode;

  /// The text shown while empty. Defaults to the localized "Search".
  final String? placeholder;

  /// Called as the text changes, including when it is cleared.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits from the keyboard.
  final ValueChanged<String>? onSubmitted;

  /// Whether the field takes focus when shown.
  final bool autofocus;

  /// The glass. Defaults to the theme's default glass.
  final Glass? glass;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassSearchField> createState() => _GlassSearchFieldState();
}

class _GlassSearchFieldState extends State<GlassSearchField> {
  TextEditingController? _own;

  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final placeholder =
        widget.placeholder ??
        cupertinoL10n(context).searchTextFieldPlaceholderLabel;
    return GlassModeBuilder(
      mode: widget.mode,
      builder: (context, mode) => mode == EffectiveGlassMode.material
          ? SearchBar(
              controller: _controller,
              focusNode: widget.focusNode,
              hintText: placeholder,
              autoFocus: widget.autofocus,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              leading: const Icon(CupertinoIcons.search),
            )
          : _glass(context, placeholder),
    );
  }

  Widget _glass(BuildContext context, String placeholder) {
    Color resolve(Color c) => CupertinoDynamicColor.resolve(c, context);
    final secondary = resolve(CupertinoColors.secondaryLabel);
    return SizedBox(
      height: SearchMetrics.height,
      child: LiquidGlass(
        glass: widget.glass,
        mode: widget.mode,
        padding: const EdgeInsetsDirectional.only(
          start: SearchMetrics.startInset,
          end: SearchMetrics.endInset,
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.search,
              size: SearchMetrics.iconSize,
              color: secondary,
            ),
            const SizedBox(width: SearchMetrics.iconGap),
            Expanded(
              child: CupertinoTextField.borderless(
                controller: _controller,
                focusNode: widget.focusNode,
                autofocus: widget.autofocus,
                placeholder: placeholder,
                placeholderStyle: IOSText.style(
                  SearchMetrics.fontSize,
                  color: secondary,
                ),
                style: IOSText.style(
                  SearchMetrics.fontSize,
                  color: resolve(CupertinoColors.label),
                ),
                padding: EdgeInsets.zero,
                textInputAction: TextInputAction.search,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
              ),
            ),
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => _controller.text.isEmpty
                  ? const SizedBox.shrink()
                  : Semantics(
                      button: true,
                      label: cupertinoL10n(context).clearButtonLabel,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _clear,
                        child: Padding(
                          padding: const EdgeInsets.all(
                            SearchMetrics.clearPadding,
                          ),
                          child: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            size: SearchMetrics.clearSize,
                            color: resolve(CupertinoColors.tertiaryLabel),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
