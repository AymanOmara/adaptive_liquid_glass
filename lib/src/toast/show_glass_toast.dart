import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        ScaffoldFeatureController,
        ScaffoldMessenger,
        SnackBar,
        SnackBarAction,
        SnackBarBehavior,
        SnackBarClosedReason;

import '../core/effective_glass_mode.dart';
import '../core/glass.dart';
import '../core/glass_render_mode.dart';
import '../core/render_mode_resolver.dart';
import '../core/theme.dart';
import '../platform/glass_platform.dart';
import 'glass_toast_action.dart';
import 'glass_toast_handle.dart';
import 'toast_metrics.dart';
import 'toast_queue.dart';

/// Shows a toast: an iOS glass capsule sliding in from the top with a
/// spring.
///
/// ```dart
/// showGlassToast(
///   context,
///   message: 'Upload complete',
///   icon: CupertinoIcons.checkmark_circle,
///   action: GlassToastAction(label: 'View', onPressed: openFile),
/// )
/// ```
///
/// Swipe up to dismiss, or wait: the toast auto-dismisses after
/// [duration]. One toast shows at a time; later calls wait in a queue,
/// and the returned [GlassToastHandle] dismisses it early — shown or
/// still waiting. With Reduce Motion it fades instead of sliding, and
/// it is announced to assistive tech as a live region.
///
/// On the Material path it is a `SnackBar` through the nearest
/// `ScaffoldMessenger` when there is one, otherwise a Material 3
/// snackbar-styled surface in the overlay at the bottom.
///
/// The [duration] the toast stays defaults to 4 seconds; null keeps the
/// toast until dismissed.
GlassToastHandle showGlassToast(
  BuildContext context, {
  required String message,
  IconData? icon,
  GlassToastAction? action,
  Duration? duration = ToastMetrics.defaultDuration,
  Glass? glass,
  GlassRenderMode? mode,
}) {
  final effective = resolveGlassMode(
    requested: mode ?? LiquidGlassTheme.of(context).defaultMode,
    environment: GlassPlatform.instance.environment.value,
  );
  if (effective == EffectiveGlassMode.material) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      return _SnackBarHandle(
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon),
                  const SizedBox(width: ToastMetrics.iconGap),
                ],
                Expanded(child: Text(message)),
              ],
            ),
            action: action == null
                ? null
                : SnackBarAction(
                    label: action.label,
                    onPressed: action.onPressed,
                  ),
            duration: duration ?? const Duration(days: 365),
            behavior: SnackBarBehavior.floating,
          ),
        ),
      );
    }
  }
  final overlay = Overlay.of(context, rootOverlay: true);
  final request = ToastRequest(
    message: message,
    icon: icon,
    action: action,
    duration: duration,
    glass: glass,
    mode: mode,
    material: effective == EffectiveGlassMode.material,
  );
  ToastQueue.of(overlay).add(request);
  return request;
}

/// Wraps the `ScaffoldMessenger`'s controller as a [GlassToastHandle].
class _SnackBarHandle implements GlassToastHandle {
  _SnackBarHandle(this._controller);

  final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> _controller;
  bool _dismissed = false;

  @override
  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _controller.close();
  }

  @override
  Future<void> get closed => _controller.closed.then((_) {});
}
