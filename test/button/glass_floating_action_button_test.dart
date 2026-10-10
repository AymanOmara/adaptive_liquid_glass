import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('glass: a large prominent circle, or a capsule with a label', (
    t,
  ) async {
    shaderEnv();
    var taps = 0;
    await t.pumpWidget(
      plainHost(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassFloatingActionButton(
              onPressed: () => taps++,
              icon: CupertinoIcons.add,
              semanticLabel: 'Add',
            ),
            GlassFloatingActionButton.extended(
              onPressed: () => taps++,
              icon: CupertinoIcons.add,
              label: const Text('New event'),
            ),
          ],
        ),
      ),
    );
    final buttons = t.widgetList<GlassButton>(find.byType(GlassButton));
    expect(buttons.map((b) => b.shape), [
      GlassButtonShape.circle,
      GlassButtonShape.capsule,
    ]);
    for (final b in buttons) {
      expect(b.style, GlassButtonStyle.glassProminent);
      expect(b.size, GlassControlSize.large);
    }
    expect(find.byType(FloatingActionButton), findsNothing);
    await t.tap(find.text('New event'));
    expect(taps, 1);
  }, variant: ios);

  testWidgets('Material: FloatingActionButton and its extended form', (
    t,
  ) async {
    shaderEnv();
    var taps = 0;
    await t.pumpWidget(
      appHost(
        Column(
          children: [
            GlassFloatingActionButton(
              onPressed: () => taps++,
              icon: CupertinoIcons.add,
              tooltip: 'Add',
            ),
            GlassFloatingActionButton.extended(
              onPressed: () => taps++,
              icon: CupertinoIcons.add,
              label: const Text('New event'),
              tint: Colors.teal,
            ),
          ],
        ),
      ),
    );
    expect(find.byType(LiquidGlass), findsNothing);
    final fabs = t
        .widgetList<FloatingActionButton>(find.byType(FloatingActionButton))
        .toList();
    expect(fabs, hasLength(2));
    expect(fabs.first.isExtended, isFalse);
    expect(fabs.first.tooltip, 'Add');
    expect(fabs.last.isExtended, isTrue);
    expect(fabs.last.backgroundColor, Colors.teal);
    expect(find.text('New event'), findsOneWidget);
    await t.tap(find.text('New event'));
    expect(taps, 1);
  }, variant: android);

  testWidgets('Material: semanticLabel replaces the visible label', (t) async {
    shaderEnv();
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      appHost(
        GlassFloatingActionButton.extended(
          onPressed: () {},
          icon: CupertinoIcons.add,
          label: const Text('New'),
          semanticLabel: 'New event',
        ),
      ),
    );
    expect(find.bySemanticsLabel('New event'), findsOneWidget);
    expect(find.bySemanticsLabel('New'), findsNothing);
    handle.dispose();
  }, variant: android);
}
