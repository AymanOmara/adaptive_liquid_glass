import 'package:flutter/foundation.dart';

import 'glass_photo_import_progress.dart';

/// Watches and stops a `pickGlassPhotos` import.
///
/// ```dart
/// final controller = GlassPhotoImportController();
/// pickGlassPhotos(maxSelection: 0, controller: controller);
/// // later, e.g. from a Stop button:
/// controller.cancel();
/// ```
///
/// One controller drives one import at a time; it can be reused once that
/// import has finished. [cancel] is safe at any time.
class GlassPhotoImportController {
  final ValueNotifier<bool> _active = ValueNotifier(false);
  final ValueNotifier<GlassPhotoImportProgress?> _progress = ValueNotifier(
    null,
  );
  GlassPhotoImportBinding? _binding;
  bool _disposed = false;

  /// Whether an import is running (including while the picker shows).
  ValueListenable<bool> get isActive => _active;

  /// The latest progress; null before the first import.
  ValueListenable<GlassPhotoImportProgress?> get progress => _progress;

  /// Stops the running import. Items already finished are kept and the
  /// result reports `GlassPickedPhotos.cancelled`. Does nothing when idle or
  /// after [dispose].
  void cancel() => _binding?._cancel();

  /// Releases the listenables. Attaching a disposed controller to an import
  /// throws a [StateError]; [cancel] does nothing.
  void dispose() {
    _disposed = true;
    _binding = null;
    _active.dispose();
    _progress.dispose();
  }
}

/// Connects one import to a controller. Not exported.
GlassPhotoImportBinding attachImport(
  GlassPhotoImportController controller,
  void Function() onCancel,
) {
  if (controller._disposed) {
    throw StateError('This GlassPhotoImportController has been disposed.');
  }
  if (controller._binding != null) {
    throw StateError(
      'This GlassPhotoImportController is already driving an import.',
    );
  }
  final binding = GlassPhotoImportBinding._(controller, onCancel);
  controller._binding = binding;
  controller._active.value = true;
  controller._progress.value = GlassPhotoImportProgress.selecting;
  return binding;
}

/// One import's link to its controller. Not exported.
class GlassPhotoImportBinding {
  GlassPhotoImportBinding._(this._controller, this._onCancel);

  final GlassPhotoImportController _controller;
  final void Function() _onCancel;
  bool _cancelled = false;

  /// Whether cancel has been requested.
  bool get cancelled => _cancelled;

  void _cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel();
  }

  /// Publishes [progress] on the controller.
  void update(GlassPhotoImportProgress progress) {
    if (_controller._disposed) return;
    if (identical(_controller._binding, this)) {
      _controller._progress.value = progress;
    }
  }

  /// Releases the controller for the next import.
  void detach() {
    if (!identical(_controller._binding, this)) return;
    _controller._binding = null;
    if (!_controller._disposed) _controller._active.value = false;
  }
}
