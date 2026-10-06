import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/date_picker/glass_calendar.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  DateTime value = DateTime(2026, 10, 6);

  @override
  Widget build(BuildContext context) => GlassDatePicker(
    value: value,
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
    onChanged: (d) => setState(() => value = d),
  );
}

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('shows the date; the calendar picks a day', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(const _Harness()));
    expect(find.text('Oct 6, 2026'), findsOneWidget);
    await t.tap(find.text('Oct 6, 2026'));
    await t.pumpAndSettle();
    expect(find.byType(GlassCalendar), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    await t.tap(find.text('20'));
    await t.pumpAndSettle();
    expect(find.byType(GlassCalendar), findsNothing);
    expect(find.text('Oct 20, 2026'), findsOneWidget);
  }, variant: ios);

  testWidgets('the calendar pages between months', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(const _Harness()));
    await t.tap(find.text('Oct 6, 2026'));
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Next month'));
    await t.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
  }, variant: ios);

  testWidgets('Material: a text button opening showDatePicker', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(const _Harness()));
    await t.tap(find.byType(TextButton));
    await t.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  }, variant: android);
}
