import 'package:flutter/foundation.dart' show TargetPlatform;

import 'core/glass_render_mode.dart';
import 'navigation/progressive_blur_program.dart';
import 'platform/glass_platform.dart';
import 'shader/glass_program.dart';
import 'tab_bar/tab_lens_program.dart';

/// One-call setup for the package; optional.
///
/// Not required: without it each shader loads on first use. To have every
/// shader ready before the first frame instead, await [initialize] in
/// `main()`:
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await AdaptiveLiquidGlass.initialize();
///   runApp(const MyApp());
/// }
/// ```
abstract final class AdaptiveLiquidGlass {
  /// Loads every shader the package may need, before the first frame.
  ///
  /// Without this, each shader loads on first use: glass draws as a plain
  /// blur for a frame or two and then switches over in place, and the
  /// scroll edge and tab lens use their fallbacks until ready (see the
  /// class example for how to skip that).
  ///
  /// Returns an already-completed future with nothing loaded when the
  /// environment cannot use shaders, or on Android and any other non-iOS
  /// platform, which render Material by default. Pass [mode] to preload
  /// anyway when the app forces shader glass there — it should match the
  /// theme's `defaultMode`.
  ///
  /// The loads never throw (a failure is reported to `FlutterError` and
  /// the widgets use their fallbacks) and are idempotent, so this is safe
  /// to call more than once.
  static Future<void> initialize({GlassRenderMode? mode}) {
    GlassPlatform.instance.ensureStarted();
    final environment = GlassPlatform.instance.environment.value;
    if (!environment.shaderSupported) {
      return Future<void>.value();
    }
    if (environment.platform != TargetPlatform.iOS &&
        mode != GlassRenderMode.shader) {
      return Future<void>.value();
    }
    return Future.wait<void>([
      GlassProgram.instance.load(),
      TabLensProgram.instance.load(),
      ProgressiveBlurProgram.instance.load(),
    ]);
  }
}
