import 'dart:convert';

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/testing.dart';
import 'package:flutter/material.dart';

import 'demo.dart';
import 'launch.dart';
import 'scenes/motion_view.dart';
import 'scenes/scene.dart';
import 'scenes/scene_view.dart';

// `lib/native_demo.dart` has its own entry point:
// `flutter run -t lib/native_demo.dart`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlass.precache();
  final args = await LaunchArgs.read();
  final constants = args.constants == null
      ? GlassConstants.standard
      : GlassConstants.fromJson(
          (jsonDecode(args.constants!) as Map).cast<String, Object?>(),
        );
  if (args.motion != null) return runMotion(args.motion!, constants);
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
  runApp(
    LiquidGlassTheme(
      data: LiquidGlassThemeData(constants: constants),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: scene == null ? const Demo() : SceneView(scene: scene),
      ),
    ),
  );
}
