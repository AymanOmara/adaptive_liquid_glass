import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _wheel({ValueChanged<DateTime>? onChanged}) => GlassDateWheel(
  value: DateTime(2026, 10, 6),
  firstDate: DateTime(2020),
  lastDate: DateTime(2030),
  onChanged: onChanged,
);

Finder _column(int i, String text) => find.descendant(
  of: find.byType(GlassWheelPicker<int>).at(i),
  matching: find.text(text),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('date columns follow the locale order (mdy)', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_wheel(onChanged: (_) {})));
    expect(_column(0, 'October'), findsOneWidget);
    expect(_column(1, '6'), findsOneWidget);
    expect(_column(2, '2026'), findsOneWidget);
    expect(find.byType(LiquidGlass), findsNWidgets(2));
  }, variant: ios);

  testWidgets('null onChanged disables every column', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_wheel()));
    for (final w in t.widgetList<GlassWheelPicker<int>>(
      find.byType(GlassWheelPicker<int>),
    )) {
      expect(w.onChanged, isNull);
    }
  }, variant: ios);

  test('minuteInterval must divide 60', () {
    expect(
      () => GlassDateWheel(
        value: DateTime(2026),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        onChanged: null,
        minuteInterval: 7,
      ),
      throwsAssertionError,
    );
  });

  testWidgets('Material: one Material surface, no glass', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(_wheel(onChanged: (_) {})));
    expect(find.byType(LiquidGlass), findsNothing);
    expect(
      find.descendant(
        of: find.byType(GlassDateWheel),
        matching: find.byType(Material),
      ),
      findsOneWidget,
    );
  }, variant: android);
}
