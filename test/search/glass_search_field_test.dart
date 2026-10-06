import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _app(List<String> changes) => MaterialApp(
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: GlassSearchField(onChanged: changes.add),
    ),
  ),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('a glass capsule with a localized placeholder', (t) async {
    shaderEnv();
    await t.pumpWidget(_app([]));
    expect(find.byType(LiquidGlass), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.xmark_circle_fill), findsNothing);
  }, variant: ios);

  testWidgets('typing shows the clear button; clearing reports empty', (
    t,
  ) async {
    shaderEnv();
    final changes = <String>[];
    await t.pumpWidget(_app(changes));
    await t.enterText(find.byType(CupertinoTextField), 'glass');
    await t.pump();
    expect(changes.last, 'glass');
    await t.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
    await t.pump();
    expect(changes.last, '');
    expect(find.byIcon(CupertinoIcons.xmark_circle_fill), findsNothing);
  }, variant: ios);

  testWidgets('Material: a Material 3 search bar', (t) async {
    shaderEnv();
    await t.pumpWidget(_app([]));
    expect(find.byType(SearchBar), findsOneWidget);
  }, variant: android);
}
