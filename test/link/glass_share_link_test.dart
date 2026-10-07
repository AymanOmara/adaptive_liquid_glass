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

  testWidgets('icon-only: the share glyph on glass, labelled Share', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(plainHost(GlassShareLink(onShare: () {})));
    expect(find.byIcon(CupertinoIcons.share), findsOneWidget);
    expect(find.byType(LiquidGlass), findsOneWidget);
    expect(find.byType(Text), findsNothing);
    expect(
      t.getSemantics(find.byIcon(CupertinoIcons.share)),
      isSemantics(isButton: true, label: 'Share', hasTapAction: true),
    );
    s.dispose();
  }, variant: ios);

  testWidgets('with a label: a capsule reading the label', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(
      plainHost(GlassShareLink(label: 'Share recipe', onShare: () {})),
    );
    expect(find.text('Share recipe'), findsOneWidget);
    expect(
      t.getSemantics(find.text('Share recipe')),
      isSemantics(isButton: true, label: 'Share recipe'),
    );
    s.dispose();
  }, variant: ios);

  testWidgets('tapping calls onShare', (t) async {
    shaderEnv();
    var shares = 0;
    await t.pumpWidget(plainHost(GlassShareLink(onShare: () => shares++)));
    await t.tap(find.byIcon(CupertinoIcons.share));
    expect(shares, 1);
  }, variant: ios);

  testWidgets('semanticLabel overrides the default', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(
      plainHost(GlassShareLink(semanticLabel: 'Send', onShare: () {})),
    );
    expect(find.bySemanticsLabel('Send'), findsOneWidget);
    expect(find.bySemanticsLabel('Share'), findsNothing);
    s.dispose();
  }, variant: ios);

  testWidgets('null onShare disables the trigger', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(plainHost(const GlassShareLink(onShare: null)));
    expect(
      t.getSemantics(find.byIcon(CupertinoIcons.share)),
      isSemantics(isButton: true, isEnabled: false, hasTapAction: false),
    );
    s.dispose();
  }, variant: ios);

  testWidgets('right to left: the glyph is right of the label', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassShareLink(label: 'Share', onShare: () {}),
        direction: TextDirection.rtl,
      ),
    );
    expect(
      t.getCenter(find.byIcon(CupertinoIcons.share)).dx,
      greaterThan(t.getCenter(find.text('Share')).dx),
    );
  }, variant: ios);

  testWidgets(
    'Material: an IconButton icon-only, a FilledButton with a label',
    (t) async {
      shaderEnv();
      var shares = 0;
      await t.pumpWidget(
        appHost(
          Column(
            children: [
              GlassShareLink(onShare: () => shares++),
              GlassShareLink(label: 'Share', onShare: () {}),
            ],
          ),
        ),
      );
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(LiquidGlass), findsNothing);
      await t.tap(find.byType(IconButton));
      await t.pumpAndSettle();
      expect(shares, 1);
    },
    variant: android,
  );
}
