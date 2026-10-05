import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/core/shape_border.dart';
import 'package:adaptive_liquid_glass/src/degraded/glass_loading_surface.dart';
import 'package:adaptive_liquid_glass/src/group/glass_member.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hosts.dart';

/// Stands in for the shader program: the asset does not load under
/// `flutter test`.
final _program = ValueNotifier<Object?>(null);

class _Stateful extends StatefulWidget {
  const _Stateful();

  @override
  State<_Stateful> createState() => _StatefulState();
}

class _StatefulState extends State<_Stateful> {
  @override
  Widget build(BuildContext context) => const SizedBox(width: 120, height: 44);
}

RenderGlassLoadingSurface _surface(WidgetTester t) =>
    t.renderObject(find.byType(GlassLoadingSurface));

bool _blurOn(WidgetTester t) {
  final s = _surface(t);
  return s.enabled && s.opaqueColor == null;
}

void main() {
  setUp(() {
    GlassProgram.instance.debugReset(skipLoad: true);
    _program.value = null;
    glassShaderProgram = _program;
  });
  tearDown(() {
    glassShaderProgram = GlassProgram.instance.program;
    GlassPlatform.instance.debugReset();
  });

  testWidgets('until the shader loads, glass is a blur-only surface', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const LiquidGlass(child: _Stateful())));
    expect(_blurOn(t), isTrue);
  }, variant: ios);

  testWidgets('then switches to the shader without a jump', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const LiquidGlass(child: _Stateful())));
    final state = t.state(find.byType(_Stateful));
    final rect = t.getRect(find.byType(_Stateful));

    _program.value = Object();
    await t.pump();

    expect(_blurOn(t), isFalse);
    expect(t.state(find.byType(_Stateful)), same(state)); // not remounted
    expect(t.getRect(find.byType(_Stateful)), rect);
  }, variant: ios);

  testWidgets('a loaded shader shows no fallback', (t) async {
    shaderEnv();
    _program.value = Object();
    await t.pumpWidget(plainHost(const LiquidGlass(child: _Stateful())));
    expect(_blurOn(t), isFalse);
  }, variant: ios);

  testWidgets('Reduce Transparency falls back to the opaque fill', (t) async {
    GlassPlatform.instance.debugEnvironment = const GlassEnvironment(
      platform: TargetPlatform.iOS,
      iosMajorVersion: 26,
      reduceTransparency: true,
      shaderSupported: true,
    );
    await t.pumpWidget(plainHost(const LiquidGlass(child: _Stateful())));
    expect(_surface(t).enabled, isTrue);
    expect(_surface(t).opaqueColor, opaqueGlassColor(Brightness.light));
  }, variant: ios);

  testWidgets('native glass does not wait for the shader', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const LiquidGlassTheme(
          data: LiquidGlassThemeData(nativeEnabled: true),
          child: LiquidGlass(child: _Stateful()),
        ),
      ),
    );
    expect(_blurOn(t), isFalse);
  }, variant: ios);

  testWidgets('precache() is optional: glass shows without it', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const LiquidGlass(child: _Stateful())));
    expect(find.byType(_Stateful), findsOneWidget);
    expect(t.takeException(), isNull);
  }, variant: ios);

  testWidgets('the Material path never loads the shader', (t) async {
    // Loading for real fails under `flutter test` and reports an error.
    GlassProgram.instance.debugReset();
    shaderEnv();
    await t.pumpWidget(appHost(const LiquidGlass(child: _Stateful())));
    await t.pump();
    expect(t.takeException(), isNull);
  }, variant: android);

  testWidgets('a failed load is not retried on every rebuild', (t) async {
    // Loading for real fails under `flutter test` and reports an error.
    GlassProgram.instance.debugReset();
    shaderEnv();
    Widget group(double spacing) => plainHost(
      GlassGroup(
        spacing: spacing,
        child: const LiquidGlass(child: _Stateful()),
      ),
    );
    await t.pumpWidget(group(0));
    await t.pump();
    expect(t.takeException(), isNotNull); // the first attempt
    await t.pumpWidget(group(4));
    await t.pump();
    expect(t.takeException(), isNull);
  }, variant: ios);
}
