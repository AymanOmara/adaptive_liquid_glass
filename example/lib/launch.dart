import 'package:flutter/services.dart';

/// Launch arguments forwarded by the iOS host (`-scene`, `-renderer`,
/// `-constants`, `-motion`, `-sceneFile`, `-mode`, `-flip`) over the
/// `example/launch` channel.
class LaunchArgs {
  /// Creates the arguments.
  LaunchArgs(
    this.scene,
    this.renderer,
    this.constants,
    this.motion, [
    this.sceneFile,
    this.mode,
    this.flip,
  ]);

  /// Static scene id, or null for the demo.
  final String? scene;

  /// `flutter` or `swiftui`.
  final String? renderer;

  /// Optional `GlassConstants` JSON override.
  final String? constants;

  /// Motion scene id (Task 16).
  final String? motion;

  /// Scene list asset; null means `assets/scenes.json`.
  final String? sceneFile;

  /// Glass path for scenes: `shader` (the default, what the fidelity
  /// harness measures), `native` or `auto`.
  final String? mode;

  /// Seconds after which a scene flips its brightness (runtime re-theme
  /// check), or null.
  final double? flip;

  /// Reads the arguments; all null where the channel is not registered.
  static Future<LaunchArgs> read() async {
    try {
      final m = await const MethodChannel('example/launch')
          .invokeMapMethod<String, Object?>('getArgs');
      return LaunchArgs(
        m?['scene'] as String?,
        m?['renderer'] as String?,
        m?['constants'] as String?,
        m?['motion'] as String?,
        m?['sceneFile'] as String?,
        m?['mode'] as String?,
        double.tryParse(m?['flip'] as String? ?? ''),
      );
    } on MissingPluginException {
      return LaunchArgs(null, null, null, null);
    }
  }
}
