import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hosts.dart';

const _key = Key('content');

Widget _glass({EdgeInsetsGeometry? padding}) => LiquidGlass(
  padding: padding,
  child: const SizedBox(key: _key, width: 40, height: 20),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('no padding by default', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_glass()));
    expect(t.getSize(find.byType(LiquidGlass)), const Size(40, 20));
  }, variant: ios);

  testWidgets('padding grows the glass around the child', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        _glass(
          padding: const EdgeInsetsDirectional.only(
            start: 16,
            end: 4,
            top: 8,
            bottom: 2,
          ),
        ),
      ),
    );
    expect(t.getSize(find.byType(LiquidGlass)), const Size(60, 30));
    final glass = t.getTopLeft(find.byType(LiquidGlass));
    expect(t.getTopLeft(find.byKey(_key)) - glass, const Offset(16, 8));
  }, variant: ios);

  testWidgets('directional padding mirrors in RTL', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        _glass(padding: const EdgeInsetsDirectional.only(start: 16)),
        direction: TextDirection.rtl,
      ),
    );
    final glass = t.getRect(find.byType(LiquidGlass));
    expect(t.getRect(find.byKey(_key)).right, glass.right - 16);
  }, variant: ios);

  testWidgets('padding applies on the Material path too', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(_glass(padding: const EdgeInsets.all(10))));
    expect(t.getSize(find.byType(LiquidGlass)), const Size(60, 40));
  }, variant: android);
}
