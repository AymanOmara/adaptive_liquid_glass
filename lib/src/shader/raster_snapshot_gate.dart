import 'package:flutter/widgets.dart';

/// Whether the engine can rasterise an off-screen image now
/// (`Layer.toImageSync`, `RenderRepaintBoundary.toImage`).
///
/// Such a snapshot is drawn on the window's surface. Without one (before
/// the first frame reaches the screen, or while the app is in the
/// background) Impeller makes a throwaway surface for it, and on Android's
/// OpenGL ES backend (Flutter 3.47) that crashes the raster thread: a null
/// dereference in `BlitCopyBufferToTextureCommandGLES::Encode` while the
/// new surface's `ContentContext` is set up. Callers wait for [isOpen] and
/// listen for it to open.
class RasterSnapshotGate extends ChangeNotifier {
  RasterSnapshotGate._() {
    WidgetsBinding.instance.waitUntilFirstFrameRasterized.then(
      (_) => notifyListeners(),
    );
    _lifecycle = AppLifecycleListener(onStateChange: (_) => notifyListeners());
  }

  /// The shared gate.
  static final RasterSnapshotGate instance = RasterSnapshotGate._();

  // Kept alive for the app's lifetime with [instance].
  // ignore: unused_field
  late final AppLifecycleListener _lifecycle;

  /// Overrides [isOpen] in tests, where no frame is ever rasterised.
  @visibleForTesting
  static bool? debugOverride;

  /// Whether a snapshot is safe now: a frame has reached the screen and
  /// the app is in the foreground.
  bool get isOpen {
    final o = debugOverride;
    if (o != null) return o;
    final binding = WidgetsBinding.instance;
    if (!binding.firstFrameRasterized) return false;
    return switch (binding.lifecycleState) {
      null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
      _ => false,
    };
  }
}
