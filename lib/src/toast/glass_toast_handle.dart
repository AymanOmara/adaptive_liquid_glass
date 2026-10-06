/// Controls a toast after [showGlassToast] has queued it.
///
/// A handle works while the toast waits its turn too: [dismiss] pulls
/// it from the queue without ever showing it, and [closed] completes
/// either way.
abstract interface class GlassToastHandle {
  /// Closes the toast: the shown one animates out, a waiting one leaves
  /// the queue. Safe to call again after it has closed.
  void dismiss();

  /// Completes once the toast has left the screen or the queue.
  Future<void> get closed;
}
