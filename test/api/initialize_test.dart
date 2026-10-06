import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/navigation/progressive_blur_program.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/tab_lens_program.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hosts.dart';

void main() {
  setUp(() {
    GlassProgram.instance.debugReset(skipLoad: true);
    TabLensProgram.instance.debugReset(skipLoad: true);
    ProgressiveBlurProgram.instance.debugReset(skipLoad: true);
  });
  tearDown(GlassPlatform.instance.debugReset);

  testWidgets('initialize loads all three programs on shader iOS', (t) async {
    shaderEnv();
    await AdaptiveLiquidGlass.initialize();
    expect(GlassProgram.instance.debugLoadCalls, 1);
    expect(TabLensProgram.instance.debugLoadCalls, 1);
    expect(ProgressiveBlurProgram.instance.debugLoadCalls, 1);
    expect(t.takeException(), isNull);
  }, variant: ios);

  testWidgets('initialize is safe to call twice', (t) async {
    shaderEnv();
    await AdaptiveLiquidGlass.initialize();
    await AdaptiveLiquidGlass.initialize();
    expect(GlassProgram.instance.debugLoadCalls, 2);
    expect(TabLensProgram.instance.debugLoadCalls, 2);
    expect(ProgressiveBlurProgram.instance.debugLoadCalls, 2);
    expect(t.takeException(), isNull);
  }, variant: ios);

  testWidgets('initialize is a no-op on the Material path', (t) async {
    shaderEnv();
    await AdaptiveLiquidGlass.initialize();
    expect(GlassProgram.instance.debugLoadCalls, 0);
    expect(TabLensProgram.instance.debugLoadCalls, 0);
    expect(ProgressiveBlurProgram.instance.debugLoadCalls, 0);
  }, variant: android);

  testWidgets('initialize preloads on Android when shader mode is forced', (
    t,
  ) async {
    shaderEnv();
    await AdaptiveLiquidGlass.initialize(mode: GlassRenderMode.shader);
    expect(GlassProgram.instance.debugLoadCalls, 1);
    expect(TabLensProgram.instance.debugLoadCalls, 1);
    expect(ProgressiveBlurProgram.instance.debugLoadCalls, 1);
  }, variant: android);

  testWidgets('initialize is a no-op without shader support', (t) async {
    GlassPlatform.instance.debugEnvironment = const GlassEnvironment(
      platform: TargetPlatform.iOS,
      iosMajorVersion: 18,
      reduceTransparency: false,
      shaderSupported: false,
    );
    await AdaptiveLiquidGlass.initialize();
    expect(GlassProgram.instance.debugLoadCalls, 0);
    expect(TabLensProgram.instance.debugLoadCalls, 0);
    expect(ProgressiveBlurProgram.instance.debugLoadCalls, 0);
  }, variant: ios);

  testWidgets('precache still loads the glass program', (t) async {
    await LiquidGlass.precache();
    expect(GlassProgram.instance.debugLoadCalls, 1);
    expect(TabLensProgram.instance.debugLoadCalls, 0);
    expect(t.takeException(), isNull);
  }, variant: ios);
}
