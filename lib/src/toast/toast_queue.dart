import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../core/glass.dart';
import '../core/glass_render_mode.dart';
import 'glass_toast_action.dart';
import 'glass_toast_handle.dart';
import 'glass_toast_view.dart';

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

  final Completer<void> _done = Completer<void>();

  /// The queue still holding this request; null once showing or done.
  ToastQueue? _queue;

  /// Set by the view once it can animate out on request.
  VoidCallback? animateOut;

  /// Set when [dismiss] ran before the view could animate out.
  bool dismissRequested = false;

  @override
  void dismiss() {
    if (_done.isCompleted) return;
    final queue = _queue;
    if (queue != null) {
      queue._remove(this);
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

  void _complete() {
    if (!_done.isCompleted) _done.complete();
  }
}

/// Serves one overlay's toasts one at a time; later ones wait. Internal.
class ToastQueue {
  ToastQueue._(this._overlay);

  /// One queue per overlay.
  static final Expando<ToastQueue> _queues = Expando<ToastQueue>();

  /// The queue serving [overlay], made when absent.
  static ToastQueue of(OverlayState overlay) =>
      _queues[overlay] ??= ToastQueue._(overlay);

  final OverlayState _overlay;
  final List<ToastRequest> _pending = <ToastRequest>[];
  ToastRequest? _current;
  OverlayEntry? _entry;

  /// Enqueues [request], showing it straight away when idle.
  void add(ToastRequest request) {
    request._queue = this;
    if (_current == null) {
      _show(request);
    } else {
      _pending.add(request);
    }
  }

  void _remove(ToastRequest request) {
    _pending.remove(request);
    request._queue = null;
    request._complete();
  }

  void _show(ToastRequest request) {
    request._queue = null;
    _current = request;
    final entry = OverlayEntry(
      builder: (_) => GlassToastView(
        request: request,
        material: request.material,
        onClosed: () => _closed(request),
      ),
    );
    _entry = entry;
    _overlay.insert(entry);
  }

  void _closed(ToastRequest request) {
    if (_current != request) return;
    final entry = _entry;
    _entry = null;
    _current = null;
    if (entry != null && _overlay.mounted) entry.remove();
    request._complete();
    if (_pending.isNotEmpty) _show(_pending.removeAt(0));
  }
}
