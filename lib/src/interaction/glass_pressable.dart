import 'package:flutter/widgets.dart';

/// Makes glass content a button when [onPressed] is set: tap, focus,
/// Enter/Space activation and button semantics.
///
/// Built whether or not [onPressed] is set, so toggling it keeps the child
/// mounted. Without it the region is inert: no button semantics (glass is
/// decoration, not a disabled button), no focus, no tap.
///
/// The press visuals of interactive glass are separate (a pointer
/// `Listener` in the member), so both run on the same touch.
class GlassPressable extends StatelessWidget {
  /// Creates a pressable region.
  const GlassPressable({super.key, this.onPressed, required this.child});

  /// Called on tap or keyboard activation; null makes the region inert.
  final VoidCallback? onPressed;

  /// Content on the glass.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    // Every widget below is built whether or not [onPressed] is set (no
    // FocusableActionDetector: it adds and removes its Actions), so
    // toggling it changes properties only.
    return Semantics(
      container: enabled,
      button: enabled ? true : null,
      enabled: enabled ? true : null,
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: _ActivateAction(onPressed),
        },
        child: Focus(
          canRequestFocus: enabled,
          skipTraversal: !enabled,
          child: MouseRegion(
            cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
            child: GestureDetector(
              behavior: enabled
                  ? HitTestBehavior.opaque
                  : HitTestBehavior.deferToChild,
              onTap: onPressed,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivateAction extends Action<ActivateIntent> {
  _ActivateAction(this.onPressed);

  final VoidCallback? onPressed;

  @override
  bool isEnabled(ActivateIntent intent) => onPressed != null;

  @override
  Object? invoke(ActivateIntent intent) {
    onPressed?.call();
    return null;
  }
}
