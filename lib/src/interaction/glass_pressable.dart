import 'package:flutter/widgets.dart';

/// Makes glass content a button: tap, focus, Enter/Space activation and
/// button semantics.
///
/// The press visuals of interactive glass are separate (a pointer
/// `Listener` in the member), so both run on the same touch.
class GlassPressable extends StatelessWidget {
  /// Creates a pressable region.
  const GlassPressable({
    super.key,
    required this.onPressed,
    required this.child,
  });

  /// Called on tap or keyboard activation.
  final VoidCallback onPressed;

  /// Content on the glass.
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    enabled: true,
    child: FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onPressed();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: child,
      ),
    ),
  );
}
