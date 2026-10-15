import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/effective_glass_mode.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/core/glass_mode_builder.dart';
import 'package:adaptive_liquid_glass/src/degraded/degraded_glass.dart';
import 'package:adaptive_liquid_glass/src/layer/glass_layer.dart';
import 'package:adaptive_liquid_glass/src/material/material_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_backdrop.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/shader/shader_glass_budget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `LiquidGlassThemeData.supportLiquidGlassOnAndroid`: `auto` draws the
/// shader glass on Android, loading the shader on first use when
/// `AdaptiveLiquidGlass.initialize` did not preload it.
final android = TargetPlatformVariant.only(TargetPlatform.android);

void env({bool shader = true}) {
  GlassPlatform.instance.debugEnvironment = GlassEnvironment(
    platform: defaultTargetPlatform,
    iosMajorVersion: defaultTargetPlatform == TargetPlatform.iOS ? 18 : null,
    reduceTransparency: false,
    shaderSupported: shader,
  );
}

Widget host(LiquidGlassThemeData theme, Widget child, {bool shader = true}) {
  env(shader: shader); // after the variant set the platform
  return LiquidGlassTheme(
    data: theme,
    child: MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

const flagOn = LiquidGlassThemeData(supportLiquidGlassOnAndroid: true);
const glass = LiquidGlass(child: SizedBox(width: 40, height: 40));

void main() {
  setUp(() {
    GlassProgram.instance.debugReset(skipLoad: true);
    ShaderGlassBudget.debugWarned = false;
  });

  tearDown(() {
    GlassPlatform.instance.debugReset();
    GlassProgram.instance.debugReset();
  });

  testWidgets('flag on: shader glass, loaded lazily without initialize', (
    t,
  ) async {
    expect(GlassProgram.instance.program.value, isNull);
    await t.pumpWidget(host(flagOn, glass));
    expect(find.byType(GlassBackdrop), findsOneWidget);
    expect(find.byType(MaterialGlass), findsNothing);
    expect(GlassProgram.instance.debugLoadCalls, greaterThan(0));
    // The program is still loading: the glass draws its plain fallback.
    await t.pump();
    expect(t.takeException(), isNull);
  }, variant: android);

  testWidgets('flag on without shader support: the frosted blur', (t) async {
    await t.pumpWidget(host(flagOn, glass, shader: false));
    expect(find.byType(DegradedGlass), findsOneWidget);
    expect(find.byType(MaterialGlass), findsNothing);
    expect(find.byType(GlassBackdrop), findsNothing);
    expect(t.takeException(), isNull);
  }, variant: android);

  testWidgets('flag off: Material 3', (t) async {
    await t.pumpWidget(host(const LiquidGlassThemeData(), glass));
    expect(find.byType(MaterialGlass), findsOneWidget);
    expect(find.byType(GlassBackdrop), findsNothing);
    expect(GlassProgram.instance.debugLoadCalls, 0);
  }, variant: android);

  testWidgets('an explicit widget mode wins over the flag', (t) async {
    await t.pumpWidget(
      host(
        flagOn,
        const LiquidGlass(
          mode: GlassRenderMode.material,
          child: SizedBox(width: 40, height: 40),
        ),
      ),
    );
    expect(find.byType(MaterialGlass), findsOneWidget);
    expect(find.byType(GlassBackdrop), findsNothing);
  }, variant: android);

  testWidgets('a non-auto defaultMode wins over the flag', (t) async {
    await t.pumpWidget(
      host(flagOn.copyWith(defaultMode: GlassRenderMode.material), glass),
    );
    expect(find.byType(MaterialGlass), findsOneWidget);
  }, variant: android);

  testWidgets('components resolve with the flag too', (t) async {
    final seen = <EffectiveGlassMode>[];
    await t.pumpWidget(
      host(
        flagOn,
        GlassModeBuilder(
          builder: (context, mode) {
            seen.add(mode);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen.last, EffectiveGlassMode.shader);
  }, variant: android);

  Widget six() => Wrap(
    children: [
      for (var i = 0; i < 6; i++)
        const LiquidGlass(child: SizedBox(width: 20, height: 20)),
    ],
  );

  testWidgets('under the flag the glass draws on the shared layer', (t) async {
    await t.pumpWidget(host(flagOn, six()));
    expect(find.byType(GlassBackdrop), findsNWidgets(6));
    expect(find.byType(DegradedGlass), findsNothing);
  }, variant: android);

  testWidgets('the Android shader budget applies under the flag', (t) async {
    GlassSharedLayer.debugEnabled = false;
    addTearDown(() => GlassSharedLayer.debugEnabled = null);
    await t.pumpWidget(
      host(
        const LiquidGlassThemeData(
          supportLiquidGlassOnAndroid: true,
          androidShaderBudget: 4,
        ),
        six(),
      ),
    );
    expect(find.byType(GlassBackdrop), findsNWidgets(4));
    expect(find.byType(DegradedGlass), findsNWidgets(2));
  }, variant: android);
}
