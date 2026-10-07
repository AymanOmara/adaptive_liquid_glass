import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

final _url = Uri.parse('https://flutter.dev');

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('a glass capsule with the arrow glyph and label', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassLink(destination: _url, label: 'flutter.dev', onOpen: (_) {}),
      ),
    );
    expect(find.text('flutter.dev'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.arrow_up_right), findsOneWidget);
    expect(find.byType(LiquidGlass), findsOneWidget);
  }, variant: ios);

  testWidgets('tapping passes the destination to onOpen', (t) async {
    shaderEnv();
    final opened = <Uri>[];
    await t.pumpWidget(
      plainHost(
        GlassLink(destination: _url, label: 'Open', onOpen: opened.add),
      ),
    );
    await t.tap(find.text('Open'));
    expect(opened, [_url]);
  }, variant: ios);

  testWidgets('icon: null hides the glyph', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassLink(destination: _url, label: 'Open', icon: null, onOpen: (_) {}),
      ),
    );
    expect(find.byType(Icon), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  }, variant: ios);

  testWidgets('read as a link to the destination', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(
      plainHost(GlassLink(destination: _url, label: 'Open', onOpen: (_) {})),
    );
    expect(
      t.getSemantics(find.text('Open')),
      isSemantics(isLink: true, hasTapAction: true),
    );
    s.dispose();
  }, variant: ios);

  testWidgets('null onOpen disables the link', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(
      plainHost(GlassLink(destination: _url, label: 'Open', onOpen: null)),
    );
    expect(
      t.getSemantics(find.text('Open')),
      isSemantics(isLink: true, isEnabled: false, hasTapAction: false),
    );
    s.dispose();
  }, variant: ios);

  testWidgets('right to left: the glyph is right of the label', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassLink(destination: _url, label: 'Open', onOpen: (_) {}),
        direction: TextDirection.rtl,
      ),
    );
    expect(
      t.getCenter(find.byIcon(CupertinoIcons.arrow_up_right)).dx,
      greaterThan(t.getCenter(find.text('Open')).dx),
    );
  }, variant: ios);

  testWidgets('Material: a tonal button that opens', (t) async {
    shaderEnv();
    final opened = <Uri>[];
    await t.pumpWidget(
      appHost(GlassLink(destination: _url, label: 'Open', onOpen: opened.add)),
    );
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(LiquidGlass), findsNothing);
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(opened, [_url]);
  }, variant: android);

  testWidgets('Material: read as a link', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(
      appHost(GlassLink(destination: _url, label: 'Open', onOpen: (_) {})),
    );
    expect(
      t.getSemantics(find.text('Open')),
      isSemantics(isLink: true, hasTapAction: true),
    );
    s.dispose();
  }, variant: android);
}
