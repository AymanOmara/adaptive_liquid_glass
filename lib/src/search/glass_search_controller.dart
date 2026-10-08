import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show SearchController;
import 'package:flutter/services.dart' show TextEditingValue, TextSelection;

/// Drives a [GlassSearchable]: the text, whether search is active and the
/// selected scope.
///
/// ```dart
/// final search = GlassSearchController();
/// GlassSearchable(
///   controller: search,
///   child: const MailList(),
/// );
/// ```
///
/// Listening to it reports text edits, activation and scope changes.
/// Dispose it when done; it owns its text controller.
class GlassSearchController extends ChangeNotifier {
  /// Creates a controller over [initialText], starting [initialIsActive]
  /// with [initialScopeIndex] selected.
  GlassSearchController({
    String text = '',
    bool isActive = false,
    int scopeIndex = 0,
  }) : _isActive = isActive,
       _scopeIndex = scopeIndex {
    textController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    textController.addListener(_textChanged);
  }

  /// The field's text controller, a Material [SearchController] so the
  /// Material path's [SearchAnchor] can share it. Owned and disposed by
  /// this controller.
  final SearchController textController = SearchController();

  bool _isActive;

  int _scopeIndex;

  /// Reports the field's own edits to this controller's listeners.
  void _textChanged() => notifyListeners();

  /// The field's text.
  String get text => textController.text;

  /// Sets the field's text, with the selection collapsed at its end.
  set text(String value) => textController.value = TextEditingValue(
    text: value,
    selection: TextSelection.collapsed(offset: value.length),
  );

  /// Whether search is active: the field focused, the Cancel button
  /// shown and the scopes and suggestions presented.
  bool get isActive => _isActive;

  /// The selected scope's index into the searchable's scopes.
  int get scopeIndex => _scopeIndex;

  /// Sets the selected scope's index; listeners are told when it changes.
  set scopeIndex(int value) {
    if (_scopeIndex == value) return;
    _scopeIndex = value;
    notifyListeners();
  }

  /// Puts search into its active presentation.
  void activate() {
    _isActive = true;
    notifyListeners();
  }

  /// Ends search: clears the text and leaves the active presentation.
  /// The selected scope is kept.
  void cancel() {
    textController.clear();
    _isActive = false;
    notifyListeners();
  }

  @override
  void dispose() {
    textController.removeListener(_textChanged);
    textController.dispose();
    super.dispose();
  }
}
