import 'package:flutter/widgets.dart';

import 'glass_toast_view.dart';
import 'toast_request.dart';

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
    request.queue = this;
    if (_current == null) {
      _show(request);
    } else {
      _pending.add(request);
    }
  }

  /// Drops [request] while it still waits, completing it unshown.
  void remove(ToastRequest request) {
    _pending.remove(request);
    request.queue = null;
    request.complete();
  }

  void _show(ToastRequest request) {
    request.queue = null;
    _current = request;
    final view = GlassToastView(
      request: request,
      material: request.material,
      onClosed: () => _closed(request),
    );
    final entry = OverlayEntry(
      builder: (_) => request.capturedThemes?.wrap(view) ?? view,
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
    request.complete();
    if (_pending.isNotEmpty) _show(_pending.removeAt(0));
  }
}
