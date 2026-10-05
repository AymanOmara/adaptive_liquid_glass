import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/group/glass_member.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hosts.dart';

final _program = ValueNotifier<Object?>(null);

class _Stateful extends StatefulWidget {
  const _Stateful();

  @override
  State<_Stateful> createState() => _StatefulState();
}

class _StatefulState extends State<_Stateful> {
  @override
  Widget build(BuildContext context) => const Text('Go');
}

void _env({bool rt = false, bool shader = true}) {
  GlassPlatform.instance.debugEnvironment = GlassEnvironment(
    platform: defaultTargetPlatform,
    iosMajorVersion: defaultTargetPlatform == TargetPlatform.iOS ? 26 : null,
    reduceTransparency: rt,
    shaderSupported: shader,
  );
}

bool _memberComposites(WidgetTester t) =>
    t.renderObject(find.byType(GlassMemberBox)).needsCompositing;

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

  testWidgets('once the shader loads the fallback adds no compositing', (
    t,
  ) async {
    _env();
    await t.pumpWidget(plainHost(const LiquidGlass(child: _Stateful())));
    _program.value = Object();
    await t.pump();
    expect(_memberComposites(t), isFalse);
  }, variant: ios);

  testWidgets('native members add no compositing for the fallback', (t) async {
    _env();
    await t.pumpWidget(
      plainHost(
        const LiquidGlassTheme(
          data: LiquidGlassThemeData(nativeEnabled: true),
          child: LiquidGlass(child: _Stateful()),
        ),
      ),
    );
    expect(_memberComposites(t), isFalse);
  }, variant: ios);

  testWidgets('Reduce Transparency toggling keeps the content mounted', (
    t,
  ) async {
    _env();
    await t.pumpWidget(plainHost(const LiquidGlass(child: _Stateful())));
    final state = t.state(find.byType(_Stateful));
    _env(rt: true);
    await t.pump();
    expect(t.state(find.byType(_Stateful)), same(state));
    _env();
    await t.pump();
    expect(t.state(find.byType(_Stateful)), same(state));
  }, variant: ios);

  testWidgets('degraded path: Reduce Transparency keeps the content mounted', (
    t,
  ) async {
    _env(shader: false);
    await t.pumpWidget(plainHost(const LiquidGlass(child: _Stateful())));
    final state = t.state(find.byType(_Stateful));
    _env(rt: true, shader: false);
    await t.pump();
    expect(t.state(find.byType(_Stateful)), same(state));
    _env(shader: false);
    await t.pump();
    expect(t.state(find.byType(_Stateful)), same(state));
  }, variant: ios);

  for (final (name, variant) in [('shader', ios), ('Material', android)]) {
    testWidgets('$name: toggling onPressed keeps the content mounted', (
      t,
    ) async {
      _env();
      final handle = t.ensureSemantics();
      final pressed = ValueNotifier<VoidCallback?>(() {});
      await t.pumpWidget(
        appHost(
          ValueListenableBuilder<VoidCallback?>(
            valueListenable: pressed,
            builder: (_, onPressed, _) =>
                LiquidGlass(onPressed: onPressed, child: const _Stateful()),
          ),
        ),
      );
      final state = t.state(find.byType(_Stateful));
      expect(
        t.getSemantics(find.text('Go')),
        isSemantics(isButton: true, hasTapAction: true, isFocusable: true),
      );

      pressed.value = null;
      await t.pump();
      await t.pump(); // Focus publishes canRequestFocus a frame later.
      expect(t.state(find.byType(_Stateful)), same(state));
      // Without onPressed, glass is decoration again: not a button, no tap
      // action, not focusable.
      final off = t.getSemantics(find.text('Go'));
      expect(off, isNot(isSemantics(isButton: true)));
      expect(off, isNot(isSemantics(hasTapAction: true)));
      expect(off, isNot(isSemantics(isFocusable: true)));

      pressed.value = () {};
      await t.pump();
      expect(t.state(find.byType(_Stateful)), same(state));
      handle.dispose();
    }, variant: variant);
  }
}
