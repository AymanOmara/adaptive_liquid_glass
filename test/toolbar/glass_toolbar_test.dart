import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _button(String label, [List<String>? taps]) => GlassButton.icon(
  onPressed: () => taps?.add(label),
  icon: CupertinoIcons.circle,
  semanticLabel: label,
);

Widget _host(Widget toolbar, {TextDirection dir = TextDirection.ltr}) =>
    MaterialApp(
      builder: (c, child) => Directionality(textDirection: dir, child: child!),
      home: Scaffold(
        body: Align(alignment: Alignment.bottomCenter, child: toolbar),
      ),
    );

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('a spacer pushes the groups to the ends', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _host(
        GlassToolbar(
          children: [_button('A'), const GlassToolbarSpacer(), _button('B')],
        ),
      ),
    );
    final a = t.getRect(find.bySemanticsLabel('A'));
    final b = t.getRect(find.bySemanticsLabel('B'));
    expect(a.left, lessThan(40));
    expect(b.right, greaterThan(800 - 40));
  }, variant: ios);

  testWidgets('right to left mirrors the groups', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _host(
        GlassToolbar(
          children: [_button('A'), const GlassToolbarSpacer(), _button('B')],
        ),
        dir: TextDirection.rtl,
      ),
    );
    expect(
      t.getRect(find.bySemanticsLabel('A')).left,
      greaterThan(t.getRect(find.bySemanticsLabel('B')).left),
    );
  }, variant: ios);

  testWidgets('a single group is centred and its items work', (t) async {
    shaderEnv();
    final taps = <String>[];
    await t.pumpWidget(
      _host(GlassToolbar(children: [_button('A', taps), _button('B', taps)])),
    );
    final a = t.getRect(find.bySemanticsLabel('A'));
    final b = t.getRect(find.bySemanticsLabel('B'));
    expect((a.left + b.right) / 2, moreOrLessEquals(400, epsilon: 1));
    await t.tap(find.bySemanticsLabel('B'));
    expect(taps, ['B']);
  }, variant: ios);

  testWidgets('GlassScaffold floats a toolbar like a tab bar', (t) async {
    shaderEnv();
    t.view.physicalSize = const Size(402, 874);
    t.view.devicePixelRatio = 1;
    t.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: GlassScaffold(
          toolbar: GlassToolbar(children: [_button('A')]),
          body: const SizedBox(key: Key('body')),
        ),
      ),
    );
    expect(
      t.getRect(find.byType(GlassToolbar)).bottom,
      moreOrLessEquals(874 - 21),
    );
    final padding = MediaQuery.paddingOf(
      t.element(find.byKey(const Key('body'))),
    );
    expect(padding.bottom, moreOrLessEquals(21 + 46.33));
  }, variant: ios);
}
