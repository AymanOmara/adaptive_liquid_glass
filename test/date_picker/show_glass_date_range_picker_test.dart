import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

/// The last value [_open]'s picker completed with; [_done] says whether
/// it has completed at all.
DateTimeRange? _picked;
bool _done = false;

/// Pumps a button calling [showGlassDateRangePicker] over October 2026
/// and taps it.
Future<void> _open(
  WidgetTester t, {
  DateTimeRange? initialRange,
  DateTime? firstDate,
  DateTime? lastDate,
  int? firstDayOfWeek,
}) async {
  _picked = null;
  _done = false;
  await t.pumpWidget(
    appHost(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            _picked = await showGlassDateRangePicker(
              context: context,
              initialRange:
                  initialRange ??
                  DateTimeRange(
                    start: DateTime(2026, 10, 6),
                    end: DateTime(2026, 10, 6),
                  ),
              firstDate: firstDate ?? DateTime(2020),
              lastDate: lastDate ?? DateTime(2030),
              firstDayOfWeek: firstDayOfWeek,
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

Future<void> _tap(WidgetTester t, String day) async {
  await t.tap(find.text(day));
  await t.pumpAndSettle();
}

/// Whether the Done button is enabled.
bool _doneEnabled(WidgetTester t) => t
    .widget<GlassButton>(
      find.ancestor(
        of: find.bySemanticsLabel('Done'),
        matching: find.byType(GlassButton),
      ),
    )
    .active;

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
    testWidgets('picking a start and an end; Done completes with them', (
      t,
    ) async {
      shaderEnv();
      await _open(t);
      expect(find.byType(GlassSheet), findsOneWidget);
      await _tap(t, '12');
      await _tap(t, '16');
      await t.tap(find.bySemanticsLabel('Done'));
      await t.pumpAndSettle();
      expect(_done, isTrue);
      expect(
        _picked,
        DateTimeRange(
          start: DateTime(2026, 10, 12),
          end: DateTime(2026, 10, 16),
        ),
      );
    }, variant: ios);

    testWidgets('Done is disabled until the end is picked', (t) async {
      shaderEnv();
      await _open(t);
      // The initial one-day range is complete.
      expect(_doneEnabled(t), isTrue);
      await _tap(t, '12');
      expect(_doneEnabled(t), isFalse);
      await t.tap(find.bySemanticsLabel('Done'), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(_done, isFalse);
      await _tap(t, '12');
      expect(_doneEnabled(t), isTrue);
      await t.tap(find.bySemanticsLabel('Done'));
      await t.pumpAndSettle();
      expect(
        _picked,
        DateTimeRange(
          start: DateTime(2026, 10, 12),
          end: DateTime(2026, 10, 12),
        ),
      );
    }, variant: ios);

    testWidgets('a tap before the start starts again there', (t) async {
      shaderEnv();
      await _open(t);
      await _tap(t, '20');
      await _tap(t, '10');
      expect(_doneEnabled(t), isFalse);
      await _tap(t, '14');
      await t.tap(find.bySemanticsLabel('Done'));
      await t.pumpAndSettle();
      expect(
        _picked,
        DateTimeRange(
          start: DateTime(2026, 10, 10),
          end: DateTime(2026, 10, 14),
        ),
      );
    }, variant: ios);

    testWidgets('the ends and the days between read as selected', (t) async {
      shaderEnv();
      final handle = t.ensureSemantics();
      await _open(
        t,
        initialRange: DateTimeRange(
          start: DateTime(2026, 10, 8),
          end: DateTime(2026, 10, 10),
        ),
      );
      for (final d in ['8', '9', '10']) {
        expect(
          t.getSemantics(find.text(d)),
          isSemantics(isSelected: true),
        );
      }
      for (final d in ['7', '11']) {
        expect(
          t.getSemantics(find.text(d)),
          isSemantics(isSelected: false),
        );
      }
      handle.dispose();
    }, variant: ios);

    testWidgets('the close button completes with null', (t) async {
      shaderEnv();
      await _open(t);
      await t.tap(find.bySemanticsLabel('Close'));
      await t.pumpAndSettle();
      expect(_done, isTrue);
      expect(_picked, isNull);
    }, variant: ios);

    testWidgets('firstDayOfWeek leads the calendar with that day', (t) async {
      shaderEnv();
      await _open(t, firstDayOfWeek: DateTime.monday % 7);
      expect(_weekdays(t).first, 'MON');
      expect(
        t.getCenter(find.text('1')).dx,
        moreOrLessEquals(t.getCenter(find.text('THU')).dx),
      );
    }, variant: ios);

    testWidgets('days outside the bounds cannot be picked', (t) async {
      shaderEnv();
      await _open(
        t,
        firstDate: DateTime(2026, 10, 5),
        lastDate: DateTime(2026, 10, 25),
      );
      await _tap(t, '3');
      // Still the initial complete range: the tap did nothing.
      expect(_doneEnabled(t), isTrue);
      await _tap(t, '10');
      await _tap(t, '28');
      expect(_doneEnabled(t), isFalse);
      await _tap(t, '25');
      await t.tap(find.bySemanticsLabel('Done'));
      await t.pumpAndSettle();
      expect(
        _picked,
        DateTimeRange(
          start: DateTime(2026, 10, 10),
          end: DateTime(2026, 10, 25),
        ),
      );
    }, variant: ios);
  });

  group('Material', () {
    testWidgets('showDateRangePicker; Save completes with the range', (
      t,
    ) async {
      shaderEnv();
      await _open(
        t,
        initialRange: DateTimeRange(
          start: DateTime(2026, 10, 6),
          end: DateTime(2026, 10, 9),
        ),
      );
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      expect(find.byType(GlassSheet), findsNothing);
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(
        _picked,
        DateTimeRange(start: DateTime(2026, 10, 6), end: DateTime(2026, 10, 9)),
      );
    }, variant: android);
  });

  group('GlassCalendar.range', () {
    testWidgets('a range wrapping a week row draws one band per row', (
      t,
    ) async {
      shaderEnv();
      await t.pumpWidget(
        appHost(
          GlassCalendar.range(
            rangeStart: DateTime(2026, 10, 9),
            rangeEnd: DateTime(2026, 10, 13),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            onRangeChanged: (_, _) {},
          ),
        ),
      );
      // Oct 9-10 end one Sunday-first row, Oct 11-13 begin the next.
      expect(
        find.descendant(
          of: find.byType(GlassCalendar),
          matching: find.byType(PositionedDirectional),
        ),
        findsNWidgets(2),
      );
    }, variant: ios);

    testWidgets('the single-day calendar draws no band', (t) async {
      shaderEnv();
      await t.pumpWidget(
        appHost(
          GlassCalendar(
            selected: DateTime(2026, 10, 9),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            onSelected: (_) {},
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(GlassCalendar),
          matching: find.byType(PositionedDirectional),
        ),
        findsNothing,
      );
    }, variant: ios);
  });
}
