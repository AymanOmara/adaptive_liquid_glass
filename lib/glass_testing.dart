/// Widget-test support for apps that use adaptive_liquid_glass.
///
/// Under `flutter test` the package's shaders do not load and the iOS
/// plugin is absent, so the rendering path depends on the host machine.
/// [GlassTesting] pins it:
///
/// ```dart
/// import 'package:adaptive_liquid_glass/glass_testing.dart';
///
/// setUp(() => GlassTesting.setUp(iosMajorVersion: 18));
/// tearDown(GlassTesting.reset);
///
/// testWidgets('shows the glass button', (tester) async {
///   ...
/// }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
/// ```
library;

// The test hooks below are this library's purpose.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/foundation.dart';

import 'src/core/glass_environment.dart';
import 'src/navigation/progressive_blur_program.dart';
import 'src/platform/glass_platform.dart';
import 'src/shader/glass_program.dart';
import 'src/tab_bar/tab_lens_program.dart';
import 'src/tab_bar/tab_vibrancy_program.dart';

/// Pins the device facts the package reads, for widget tests.
abstract final class GlassTesting {
  /// Fixes the environment for the test that follows, and stops the
  /// shader assets loading (they do not load under `flutter test`).
  ///
  /// [platform] defaults to `defaultTargetPlatform` (so a
  /// `TargetPlatformVariant` applies), and [iosMajorVersion] to none.
  /// On iOS, 26 or later picks the native path (platform views, which
  /// widget tests do not draw) and earlier versions the shader path; leave
  /// it unset or pass 18 to test the Flutter-drawn glass. Without
  /// [shaderSupported] glass is drawn degraded, and with
  /// [reduceTransparency] opaque. On Android the default is the Material
  /// path.
  ///
  /// Call it in `setUp` (or at the start of a test, after which
  /// `defaultTargetPlatform` is the variant's); undo it with [reset].
  static void setUp({
    TargetPlatform? platform,
    int? iosMajorVersion,
    bool shaderSupported = true,
    bool reduceTransparency = false,
  }) {
    for (final reset in _programResets) {
      reset(skipLoad: true);
    }
    GlassPlatform.instance.debugEnvironment = GlassEnvironment(
      platform: platform ?? defaultTargetPlatform,
      iosMajorVersion: iosMajorVersion,
      reduceTransparency: reduceTransparency,
      shaderSupported: shaderSupported,
    );
  }

  /// Restores the package's defaults: the live environment and shader
  /// loading.
  static void reset() {
    for (final reset in _programResets) {
      reset();
    }
    GlassPlatform.instance.debugReset();
  }

  static final List<void Function({bool skipLoad})> _programResets = [
    GlassProgram.instance.debugReset,
    TabLensProgram.instance.debugReset,
    TabVibrancyProgram.instance.debugReset,
    ProgressiveBlurProgram.instance.debugReset,
  ];
}
