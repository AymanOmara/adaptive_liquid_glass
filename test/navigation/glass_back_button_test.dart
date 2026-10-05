import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget pushing(Widget page) => MaterialApp(
  home: Builder(
    builder: (c) => TextButton(
      onPressed: () =>
          Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => page)),
      child: const Text('open'),
    ),
  ),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('pops the route', (t) async {
    shaderEnv();
    await t.pumpWidget(
      pushing(const Scaffold(body: Center(child: GlassBackButton()))),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(GlassBackButton), findsOneWidget);
    await t.tap(find.byType(GlassBackButton));
    await t.pumpAndSettle();
    expect(find.byType(GlassBackButton), findsNothing);
  }, variant: ios);

  testWidgets('a circular chevron announced as Back', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: GlassBackButton())),
      ),
    );
    expect(find.byIcon(CupertinoIcons.chevron_back), findsOneWidget);
    expect(
      t.widget<LiquidGlass>(find.byType(LiquidGlass)).shape,
      const GlassShape.circle(),
    );
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    s.dispose();
  }, variant: ios);

  testWidgets('Material: a stock BackButton', (t) async {
    shaderEnv();
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: GlassBackButton())),
      ),
    );
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byType(LiquidGlass), findsNothing);
  }, variant: android);
}
