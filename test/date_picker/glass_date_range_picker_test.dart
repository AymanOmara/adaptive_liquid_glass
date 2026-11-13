import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

class _Harness extends StatefulWidget {
  const _Harness({
    this.style = GlassDatePickerStyle.compact,
    this.enabled = true,
  });

  final GlassDatePickerStyle style;
  final bool enabled;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  DateTimeRange? value = DateTimeRange(
    start: DateTime(2026, 10, 6),
    end: DateTime(2026, 10, 9),
  );
  final changes = <DateTimeRange>[];

  @override
  Widget build(BuildContext context) => GlassDateRangePicker(
    value: value,
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
    style: widget.style,
    onChanged: widget.enabled
        ? (r) => setState(() {
            changes.add(r);
            value = r;
          })
        : null,
  );
}

_HarnessState _state(WidgetTester t) =>
    t.state<_HarnessState>(find.byType(_Harness));

Future<void> _tap(WidgetTester t, String day) async {
  await t.tap(find.text(day));
  await t.pumpAndSettle();
}

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  group('compact', () {
    testWidgets('the capsule reads the range and opens the range sheet', (
      t,
    ) async {
      shaderEnv();
      await t.pumpWidget(appHost(const _Harness()));
      expect(find.text('Oct 6 – Oct 9, 2026'), findsOneWidget);
      await t.tap(find.text('Oct 6 – Oct 9, 2026'));
      await t.pumpAndSettle();
      expect(find.byType(GlassSheet), findsOneWidget);
      await _tap(t, '12');
      await _tap(t, '16');
      await t.tap(find.bySemanticsLabel('Done'));
      await t.pumpAndSettle();
      expect(
        _state(t).value,
        DateTimeRange(
          start: DateTime(2026, 10, 12),
          end: DateTime(2026, 10, 16),
        ),
      );
      expect(find.text('Oct 12 – Oct 16, 2026'), findsOneWidget);
    }, variant: ios);

    testWidgets('disabled: a tap opens nothing', (t) async {
      shaderEnv();
      await t.pumpWidget(appHost(const _Harness(enabled: false)));
      await t.tap(find.text('Oct 6 – Oct 9, 2026'));
      await t.pumpAndSettle();
      expect(find.byType(GlassSheet), findsNothing);
    }, variant: ios);
  });

  group('graphical', () {
    testWidgets('the calendar inline; only complete ranges are reported', (
      t,
    ) async {
      shaderEnv();
      await t.pumpWidget(
        appHost(
          const SingleChildScrollView(
            child: _Harness(style: GlassDatePickerStyle.graphical),
          ),
        ),
      );
      expect(find.byType(GlassCalendar), findsOneWidget);
      await _tap(t, '12');
      // Just the start: nothing reported, the value kept.
      expect(_state(t).changes, isEmpty);
      final calendar = t.widget<GlassCalendar>(find.byType(GlassCalendar));
      expect(calendar.rangeStart, DateTime(2026, 10, 12));
      expect(calendar.rangeEnd, isNull);
      await _tap(t, '20');
      expect(_state(t).changes, [
        DateTimeRange(
          start: DateTime(2026, 10, 12),
          end: DateTime(2026, 10, 20),
        ),
      ]);
    }, variant: ios);
  });

  group('Material', () {
    testWidgets('a button opening showDateRangePicker', (t) async {
      shaderEnv();
      await t.pumpWidget(
        appHost(const _Harness(style: GlassDatePickerStyle.graphical)),
      );
      expect(find.byType(GlassCalendar), findsNothing);
      await t.tap(find.text('Oct 6 – Oct 9, 2026'));
      await t.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(_state(t).changes, [
        DateTimeRange(start: DateTime(2026, 10, 6), end: DateTime(2026, 10, 9)),
      ]);
    }, variant: android);
  });
}
