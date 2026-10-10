import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _adaptive({GlassRenderMode? mode}) => GlassAdaptive(
  mode: mode,
  glass: const Text('glass'),
  material: (context) => const Text('material'),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('iOS shows the glass widget', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_adaptive()));
    expect(find.text('glass'), findsOneWidget);
    expect(find.text('material'), findsNothing);
  }, variant: ios);

  testWidgets('Android shows the material widget', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(_adaptive()));
    expect(find.text('material'), findsOneWidget);
    expect(find.text('glass'), findsNothing);
  }, variant: android);

  testWidgets('explicit material mode wins on iOS', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_adaptive(mode: GlassRenderMode.material)));
    expect(find.text('material'), findsOneWidget);
    expect(find.text('glass'), findsNothing);
  }, variant: ios);

  testWidgets('switches live when the environment changes', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_adaptive()));
    expect(find.text('glass'), findsOneWidget);

    GlassPlatform.instance.debugEnvironment = const GlassEnvironment(
      platform: TargetPlatform.android,
      iosMajorVersion: null,
      reduceTransparency: false,
      shaderSupported: true,
    );
    await t.pump();
    expect(find.text('material'), findsOneWidget);
    expect(find.text('glass'), findsNothing);
  }, variant: ios);
}
