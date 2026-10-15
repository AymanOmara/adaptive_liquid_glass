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

  group('pathOf / usesGlass', () {
    void setEnv({
      TargetPlatform platform = TargetPlatform.iOS,
      int? ios = 26,
      bool reduceTransparency = false,
      bool forced = false,
      bool shader = true,
    }) => GlassPlatform.instance.debugEnvironment = GlassEnvironment(
      platform: platform,
      iosMajorVersion: platform == TargetPlatform.iOS ? ios : null,
      reduceTransparency: reduceTransparency,
      shaderSupported: shader,
      reduceTransparencyForced: forced,
    );

    /// The path at a context under [theme] and [highContrast], with what
    /// [GlassAdaptive] shows there.
    Future<(GlassEffectivePath, bool, String)> probe(
      WidgetTester t, {
      GlassRenderMode? mode,
      LiquidGlassThemeData theme = const LiquidGlassThemeData(),
      bool highContrast = false,
    }) async {
      late GlassEffectivePath path;
      late bool glass;
      await t.pumpWidget(
        MediaQuery(
          data: MediaQueryData(highContrast: highContrast),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: LiquidGlassTheme(
              data: theme,
              child: Builder(
                builder: (context) {
                  path = GlassAdaptive.pathOf(context, mode: mode);
                  glass = GlassAdaptive.usesGlass(context, mode: mode);
                  return _adaptive(mode: mode);
                },
              ),
            ),
          ),
        ),
      );
      final shown = find.text('glass').evaluate().isNotEmpty
          ? 'glass'
          : 'material';
      return (path, glass, shown);
    }

    Future<void> expectPath(
      WidgetTester t,
      GlassEffectivePath expected, {
      GlassRenderMode? mode,
      LiquidGlassThemeData theme = const LiquidGlassThemeData(),
      bool highContrast = false,
    }) async {
      final (path, glass, shown) = await probe(
        t,
        mode: mode,
        theme: theme,
        highContrast: highContrast,
      );
      expect(path, expected);
      expect(glass, expected != GlassEffectivePath.material);
      expect(shown, glass ? 'glass' : 'material');
    }

    testWidgets('iOS 26 auto is native', (t) async {
      setEnv();
      await expectPath(t, GlassEffectivePath.native);
    });

    testWidgets('older iOS auto is the shader, degraded without it', (t) async {
      setEnv(ios: 18);
      await expectPath(t, GlassEffectivePath.shader);
      setEnv(ios: 18, shader: false);
      await expectPath(t, GlassEffectivePath.degraded);
    });

    testWidgets('Android auto is Material; glass with the theme flag', (
      t,
    ) async {
      setEnv(platform: TargetPlatform.android);
      await expectPath(t, GlassEffectivePath.material);
      await expectPath(
        t,
        GlassEffectivePath.shader,
        theme: const LiquidGlassThemeData(supportLiquidGlassOnAndroid: true),
      );
    });

    testWidgets('an explicit mode and the theme default are honoured', (
      t,
    ) async {
      setEnv();
      await expectPath(
        t,
        GlassEffectivePath.material,
        mode: GlassRenderMode.material,
      );
      await expectPath(
        t,
        GlassEffectivePath.shader,
        theme: const LiquidGlassThemeData(defaultMode: GlassRenderMode.shader),
      );
      setEnv(platform: TargetPlatform.android);
      await expectPath(
        t,
        GlassEffectivePath.shader,
        mode: GlassRenderMode.native,
      );
    });

    testWidgets('high contrast and Reduce Transparency go opaque', (t) async {
      setEnv(ios: 18);
      await expectPath(t, GlassEffectivePath.opaque, highContrast: true);
      setEnv(ios: 18, reduceTransparency: true);
      await expectPath(t, GlassEffectivePath.opaque);
      // Native glass follows the system setting itself...
      setEnv(reduceTransparency: true);
      await expectPath(t, GlassEffectivePath.native);
      // ...but not one the app forced on.
      setEnv(reduceTransparency: true, forced: true);
      await expectPath(t, GlassEffectivePath.opaque);
    });
  });
}
