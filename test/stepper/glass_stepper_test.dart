import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  double value = 1;

  @override
  Widget build(BuildContext context) => GlassStepper(
    value: value,
    max: 2,
    onChanged: (v) => setState(() => value = v),
  );
}

double _value(WidgetTester t) =>
    t.state<_HarnessState>(find.byType(_Harness)).value;

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('a 93 x 31.33 capsule; plus and minus step, bounded', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness()));
    expect(t.getSize(find.byType(GlassStepper)), GlassStepper.size);
    await t.tap(find.byIcon(CupertinoIcons.plus));
    await t.pump();
    expect(_value(t), 2);
    // At the maximum the plus half is disabled.
    await t.tap(find.byIcon(CupertinoIcons.plus));
    await t.pump();
    expect(_value(t), 2);
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byIcon(CupertinoIcons.minus));
      await t.pump();
    }
    expect(_value(t), 0);
  }, variant: ios);

  testWidgets('right to left: minus is on the right', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(const _Harness(), direction: TextDirection.rtl),
    );
    expect(
      t.getCenter(find.byIcon(CupertinoIcons.minus)).dx,
      greaterThan(t.getCenter(find.byIcon(CupertinoIcons.plus)).dx),
    );
  }, variant: ios);

  testWidgets('Material: icon buttons', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(const _Harness()));
    expect(find.byType(IconButton), findsNWidgets(2));
  }, variant: android);
}
