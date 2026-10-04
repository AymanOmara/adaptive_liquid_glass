import 'dart:convert';

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/testing.dart';
import 'package:flutter/material.dart';

import 'demo.dart';
import 'launch.dart';
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
  final scenes = await Scene.loadAll();
  final scene = args.scene == null ? null : scenes[args.scene];
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
