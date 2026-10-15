import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

/// The last value [_open]'s picker completed with; [_done] says whether
/// it has completed at all.
DateTime? _picked;
bool _done = false;

/// Pumps a button calling [showGlassDatePicker] for Oct 6, 2026 and taps
/// it.
Future<void> _open(
  WidgetTester t, {
  GlassDatePickerStyle style = GlassDatePickerStyle.graphical,
  int? firstDayOfWeek,
  String? helpText,
}) async {
  _picked = null;
  _done = false;
  await t.pumpWidget(
    appHost(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            _picked = await showGlassDatePicker(
              context,
              initialDate: DateTime(2026, 10, 6),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              style: style,
              firstDayOfWeek: firstDayOfWeek,
              helpText: helpText,
            );
            _done = true;
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await t.tap(find.text('Open'));
  await t.pumpAndSettle();
}

/// The weekday initials of the calendar on screen, leading to trailing.
List<String> _weekdays(WidgetTester t) {
  const names = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
  return [...names]..sort(
    (a, b) =>
        t.getCenter(find.text(a)).dx.compareTo(t.getCenter(find.text(b)).dx),
  );
}

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  group('glass', () {
    testWidgets('a sheet with the calendar; picking a day completes', (
      t,
    ) async {
      shaderEnv();
      await _open(t);
      expect(find.byType(GlassSheet), findsOneWidget);
      expect(find.byType(GlassCalendar), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      await t.tap(find.text('20'));
      await t.pumpAndSettle();
      expect(find.byType(GlassCalendar), findsNothing);
      expect(_done, isTrue);
      expect(_picked, DateTime(2026, 10, 20));
    }, variant: ios);

    testWidgets('the close button completes with null', (t) async {
      shaderEnv();
      await _open(t);
      await t.tap(find.bySemanticsLabel('Close'));
      await t.pumpAndSettle();
      expect(find.byType(GlassCalendar), findsNothing);
      expect(_done, isTrue);
      expect(_picked, isNull);
    }, variant: ios);

    testWidgets('a tap outside completes with null', (t) async {
      shaderEnv();
      await _open(t);
      await t.tapAt(const Offset(20, 20));
      await t.pumpAndSettle();
      expect(find.byType(GlassCalendar), findsNothing);
      expect(_done, isTrue);
      expect(_picked, isNull);
    }, variant: ios);

    testWidgets('helpText titles the sheet', (t) async {
      shaderEnv();
      await _open(t, helpText: 'Due date');
      expect(find.text('Due date'), findsOneWidget);
    }, variant: ios);

    testWidgets('wheel: the columns edit and Done completes', (t) async {
      shaderEnv();
      final handle = t.ensureSemantics();
      await _open(t, style: GlassDatePickerStyle.wheel);
      expect(find.byType(GlassDateWheel), findsOneWidget);
      t.semantics.performAction(
        find.semantics.byValue('6'),
        SemanticsAction.increase,
      );
      await t.pumpAndSettle();
      expect(_done, isFalse);
      await t.tap(find.bySemanticsLabel('Done'));
      await t.pumpAndSettle();
      expect(find.byType(GlassDateWheel), findsNothing);
      expect(_picked, DateTime(2026, 10, 7));
      handle.dispose();
    }, variant: ios);

    testWidgets('wheel: the close button discards the edit', (t) async {
      shaderEnv();
      final handle = t.ensureSemantics();
      await _open(t, style: GlassDatePickerStyle.wheel);
      t.semantics.performAction(
        find.semantics.byValue('6'),
        SemanticsAction.increase,
      );
      await t.pumpAndSettle();
      await t.tap(find.bySemanticsLabel('Close'));
      await t.pumpAndSettle();
      expect(_done, isTrue);
      expect(_picked, isNull);
      handle.dispose();
    }, variant: ios);

    testWidgets('firstDayOfWeek leads the calendar with that day', (t) async {
      shaderEnv();
      await _open(t, firstDayOfWeek: DateTime.monday % 7);
      expect(_weekdays(t).first, 'MON');
      expect(_weekdays(t).last, 'SUN');
      // Oct 1, 2026 is a Thursday: the fourth cell of a Monday week.
      expect(
        t.getCenter(find.text('1')).dx,
        moreOrLessEquals(t.getCenter(find.text('THU')).dx),
      );
    }, variant: ios);
  });

  group('Material', () {
    testWidgets('showDatePicker; OK completes with the date', (t) async {
      shaderEnv();
      await _open(t, helpText: 'Due date');
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.byType(GlassSheet), findsNothing);
      expect(find.text('Due date'), findsOneWidget);
      await t.tap(find.text('20'));
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      expect(_picked, DateTime(2026, 10, 20));
    }, variant: android);

    testWidgets('Cancel completes with null', (t) async {
      shaderEnv();
      await _open(t);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(_done, isTrue);
      expect(_picked, isNull);
    }, variant: android);

    testWidgets('wheel style still opens showDatePicker', (t) async {
      shaderEnv();
      await _open(t, style: GlassDatePickerStyle.wheel);
      expect(find.byType(DatePickerDialog), findsOneWidget);
    }, variant: android);
  });

  group('GlassCalendar.firstDayOfWeek', () {
    Widget calendar({int? firstDayOfWeek}) => appHost(
      GlassCalendar(
        selected: DateTime(2026, 10, 6),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        firstDayOfWeek: firstDayOfWeek,
        onSelected: (_) {},
      ),
    );

    testWidgets('null keeps the locale (Sunday in en_US)', (t) async {
      shaderEnv();
      await t.pumpWidget(calendar());
      expect(_weekdays(t).first, 'SUN');
    }, variant: ios);

    testWidgets('6 leads with Saturday', (t) async {
      shaderEnv();
      await t.pumpWidget(calendar(firstDayOfWeek: 6));
      expect(_weekdays(t), ['SAT', 'SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI']);
      // Oct 1, 2026, a Thursday, is the sixth cell of a Saturday week.
      expect(
        t.getCenter(find.text('1')).dx,
        moreOrLessEquals(t.getCenter(find.text('THU')).dx),
      );
    }, variant: ios);

    testWidgets('GlassDatePicker passes it to its calendar', (t) async {
      shaderEnv();
      await t.pumpWidget(
        appHost(
          GlassDatePicker(
            style: GlassDatePickerStyle.graphical,
            value: DateTime(2026, 10, 6),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            firstDayOfWeek: 1,
            onChanged: (_) {},
          ),
        ),
      );
      expect(_weekdays(t).first, 'MON');
    }, variant: ios);

    testWidgets('GlassDatePicker passes it to its popover calendar', (t) async {
      shaderEnv();
      await t.pumpWidget(
        appHost(
          GlassDatePicker(
            value: DateTime(2026, 10, 6),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            firstDayOfWeek: 1,
            onChanged: (_) {},
          ),
        ),
      );
      await t.tap(find.text('Oct 6, 2026'));
      await t.pumpAndSettle();
      expect(_weekdays(t).first, 'MON');
    }, variant: ios);
  });
}
