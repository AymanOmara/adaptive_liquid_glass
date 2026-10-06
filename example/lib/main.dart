import 'dart:convert';

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/testing.dart';
import 'package:flutter/material.dart';

import 'demo.dart';
import 'launch.dart';
import 'reference_twin.dart';
import 'scenes/motion_view.dart';
import 'scenes/scene.dart';
import 'scenes/scene_view.dart';

// `lib/native_demo.dart` has its own entry point:
// `flutter run -t lib/native_demo.dart`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlass.precache();
  final args = await LaunchArgs.read();
  if (args.twin != null) {
    return runApp(ReferenceTwin(scene: args.twin!, mode: args.mode));
  }
  final constants = args.constants == null
      ? GlassConstants.standard
      : GlassConstants.fromJson(
          (jsonDecode(args.constants!) as Map).cast<String, Object?>(),
        );
  // Harness entries (`-scene`, `-motion`) default to the shader: that is
  // what the fidelity harness fits, and `auto` is native glass on iOS 26.
  // `-mode native` (or `auto`) renders them with Apple's glass instead.
  final harnessMode = switch (args.mode) {
    'native' => GlassRenderMode.native,
    'auto' => GlassRenderMode.auto,
    _ => GlassRenderMode.shader,
  };
  if (args.motion != null) {
    return runMotion(args.motion!, constants, mode: harnessMode);
  }
  final scenes = args.sceneFile == null
      ? await Scene.loadAll()
      : await Scene.loadAll(args.sceneFile!);
  final scene = args.scene == null ? null : scenes[args.scene];
  if (args.scene != null && scene == null) {
    // Never fall back to the demo: a capture would score the wrong screen.
    // Show a solid magenta error screen (like the SwiftUI host) and throw.
    final message = 'Unknown -scene ${args.scene}';
    runApp(
      ColoredBox(
        color: const Color(0xFFFF00FF),
        child: Center(
          child: Text(
            'SCENE FAILED: $message',
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: Color(0xFFFF0000),
              backgroundColor: Color(0xFFFFFFFF),
              fontSize: 24,
            ),
          ),
        ),
      ),
    );
    throw StateError(message);
  }
  // The gallery follows the package default unless `-mode` is passed.
  final mode = scene == null && args.mode == null
      ? GlassRenderMode.auto
      : harnessMode;
  runApp(
    LiquidGlassTheme(
      data: LiquidGlassThemeData(constants: constants, defaultMode: mode),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(),
        // The gallery follows the system brightness; scenes keep the light
        // theme so harness captures stay unchanged.
        darkTheme: scene == null
            ? ThemeData(brightness: Brightness.dark)
            : null,
        home: scene == null
            ? const Demo()
            : SceneView(
                scene: scene,
                flipAfter: switch (args.flip) {
                  null => null,
                  final s => Duration(milliseconds: (s * 1000).round()),
                },
              ),
      ),
    ),
  );
}
