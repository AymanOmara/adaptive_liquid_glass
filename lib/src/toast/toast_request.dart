import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../core/glass.dart';
import '../core/glass_render_mode.dart';
import 'glass_toast_action.dart';
import 'glass_toast_handle.dart';
import 'toast_queue.dart';

/// A toast waiting its turn or on screen. Internal.
class ToastRequest implements GlassToastHandle {
  /// Creates the request [ToastQueue.add] takes.
  ToastRequest({
    required this.message,
    required this.icon,
    required this.action,
    required this.duration,
    required this.glass,
    required this.mode,
    required this.material,
    this.capturedThemes,
  });

  /// What the toast says.
  final String message;

  /// An icon beside the message; null shows none.
  final IconData? icon;

  /// A button inside the toast; null shows none.
  final GlassToastAction? action;

  /// How long the toast stays; null keeps it until dismissed.
  final Duration? duration;

  /// The glass material.
  final Glass? glass;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// Whether the Material path is used.
  final bool material;

  /// Themes captured from the presenting context, wrapped around the toast
  /// so it draws in the caller's appearance; null uses the overlay's.
  final CapturedThemes? capturedThemes;

  final Completer<void> _done = Completer<void>();

  /// The queue still holding this request; null once showing or done.
  /// Set by [ToastQueue].
  ToastQueue? queue;

  /// Set by the view once it can animate out on request.
  VoidCallback? animateOut;

  /// Set when [dismiss] ran before the view could animate out.
  bool dismissRequested = false;

  @override
  void dismiss() {
    if (_done.isCompleted) return;
    final queue = this.queue;
    if (queue != null) {
      queue.remove(this);
      return;
    }
    final animate = animateOut;
    if (animate != null) {
      animate();
    } else {
      dismissRequested = true;
    }
  }

  @override
  Future<void> get closed => _done.future;

  /// Completes [closed]; called by [ToastQueue] once the toast is gone.
  void complete() {
    if (!_done.isCompleted) _done.complete();
  }
}
