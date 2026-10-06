import 'package:flutter/widgets.dart';

/// Activates pressable glass from the keyboard (Space, Enter).
class GlassActivateAction extends Action<ActivateIntent> {
  /// Calls [onPressed] on activation.
  GlassActivateAction(this.onPressed);

  /// Called on activation; null disables the action.
  final VoidCallback? onPressed;

  @override
  bool isEnabled(ActivateIntent intent) => onPressed != null;

  @override
  Object? invoke(ActivateIntent intent) {
    onPressed?.call();
    return null;
  }
}
