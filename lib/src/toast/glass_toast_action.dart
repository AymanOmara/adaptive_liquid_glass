import 'package:flutter/widgets.dart';

/// A button inside a [showGlassToast] toast.
///
/// ```dart
/// showGlassToast(
///   context,
///   message: 'File moved',
///   action: GlassToastAction(
///     label: 'Undo',
///     onPressed: moveItBack,
///   ),
/// )
/// ```
@immutable
class GlassToastAction {
  /// Creates an action.
  const GlassToastAction({required this.label, required this.onPressed});

  /// The button's label.
  final String label;

  /// Called when the button is tapped; the toast then dismisses itself.
  final VoidCallback onPressed;
}
