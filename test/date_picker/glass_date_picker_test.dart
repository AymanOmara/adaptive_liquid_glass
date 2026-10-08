import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

class _Harness extends StatefulWidget {
  const _Harness({
    this.style = GlassDatePickerStyle.compact,
    this.pickerMode = GlassDatePickerMode.date,
    this.minuteInterval = 1,
    this.showWeekNumbers = false,
    this.use24HourFormat,
    this.enabled = true,
    this.initial,
  });

  final GlassDatePickerStyle style;
  final GlassDatePickerMode pickerMode;
  final int minuteInterval;
  final bool showWeekNumbers;
  final bool? use24HourFormat;
  final bool enabled;
  final DateTime? initial;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late DateTime value = widget.initial ?? DateTime(2026, 10, 6);

  @override
  Widget build(BuildContext context) => GlassDatePicker(
    value: value,
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
    style: widget.style,
    pickerMode: widget.pickerMode,
    minuteInterval: widget.minuteInterval,
    showWeekNumbers: widget.showWeekNumbers,
    use24HourFormat: widget.use24HourFormat,
    onChanged: widget.enabled ? (d) => setState(() => value = d) : null,
  );
}

_HarnessState _state(WidgetTester t) =>
    t.state<_HarnessState>(find.byType(_Harness));

final _at930 = DateTime(2026, 10, 6, 9, 30);

/// Steps the wheel column whose semantics [value] reads up by one row.
Future<void> _increase(WidgetTester t, String value) async {
  t.semantics.performAction(
    find.semantics.byValue(value),
    SemanticsAction.increase,
  );
  await t.pumpAndSettle();
}

/// Drags the [column]th wheel column up by one row and lets it settle.
Future<void> _scroll(WidgetTester t, int column) async {
  await t.drag(
    find.descendant(
      of: find.byType(GlassWheelPicker<int>).at(column),
      matching: find.byType(ListWheelScrollView),
    ),
    const Offset(0, -1.4 * WheelPickerMetrics.itemExtent),
  );
  await t.pumpAndSettle();
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

  testWidgets('graphical: the calendar is inline and picks a day', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(_Harness(style: GlassDatePickerStyle.graphical, initial: _at930)),
    );
    expect(find.byType(GlassCalendar), findsOneWidget);
    await t.tap(find.text('20'));
    await t.pumpAndSettle();
    expect(_state(t).value, DateTime(2026, 10, 20, 9, 30));
    expect(find.byType(GlassCalendar), findsOneWidget);
  }, variant: ios);

  testWidgets('graphical: week numbers lead each row', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(
        const _Harness(
          style: GlassDatePickerStyle.graphical,
          showWeekNumbers: true,
        ),
      ),
    );
    expect(find.text('40'), findsOneWidget);
    expect(find.text('41'), findsOneWidget);
    expect(find.text('44'), findsOneWidget);
    expect(find.text('45'), findsNothing);
  }, variant: ios);

  testWidgets('wheel: the columns change the date', (t) async {
    shaderEnv();
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      appHost(const _Harness(style: GlassDatePickerStyle.wheel)),
    );
    expect(find.byType(GlassDateWheel), findsOneWidget);
    expect(find.byType(GlassWheelPicker<int>), findsNWidgets(3));
    expect(find.text('October'), findsOneWidget);
    await _increase(t, '6');
    expect(_state(t).value, DateTime(2026, 10, 7));
    await _increase(t, 'October');
    expect(_state(t).value, DateTime(2026, 11, 7));
    expect(find.text('November'), findsOneWidget);
    handle.dispose();
  }, variant: ios);

  testWidgets('wheel: a month with fewer days clamps the day', (t) async {
    shaderEnv();
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      appHost(
        _Harness(
          style: GlassDatePickerStyle.wheel,
          initial: DateTime(2026, 10, 31),
        ),
      ),
    );
    await _increase(t, 'October');
    expect(_state(t).value, DateTime(2026, 11, 30));
    handle.dispose();
  }, variant: ios);

  testWidgets('time: the capsule shows the time and the wheel changes it', (
    t,
  ) async {
    shaderEnv();
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      appHost(
        _Harness(
          pickerMode: GlassDatePickerMode.time,
          use24HourFormat: false,
          initial: _at930,
        ),
      ),
    );
    expect(find.text('9:30 AM'), findsOneWidget);
    await t.tap(find.text('9:30 AM'));
    await t.pumpAndSettle();
    expect(find.byType(GlassDateWheel), findsOneWidget);
    expect(find.byType(GlassWheelPicker<int>), findsNWidgets(3));
    t.semantics.performAction(
      find.semantics.byLabel('Hour'),
      SemanticsAction.increase,
    );
    await t.pumpAndSettle();
    expect(_state(t).value, DateTime(2026, 10, 6, 10, 30));
    await _increase(t, 'AM');
    expect(_state(t).value, DateTime(2026, 10, 6, 22, 30));
    expect(find.text('10:30 PM'), findsOneWidget);
    handle.dispose();
  }, variant: ios);

  testWidgets('time: 24-hour format has no period column', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(
        _Harness(
          pickerMode: GlassDatePickerMode.time,
          use24HourFormat: true,
          initial: _at930,
        ),
      ),
    );
    expect(find.text('09:30'), findsOneWidget);
    await t.tap(find.text('09:30'));
    await t.pumpAndSettle();
    expect(find.byType(GlassWheelPicker<int>), findsNWidgets(2));
    expect(find.text('9'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('AM'), findsNothing);
  }, variant: ios);

  testWidgets('time: minuteInterval steps the minute column', (t) async {
    shaderEnv();
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      appHost(
        _Harness(
          pickerMode: GlassDatePickerMode.time,
          minuteInterval: 15,
          use24HourFormat: false,
          initial: _at930,
        ),
      ),
    );
    await t.tap(find.text('9:30 AM'));
    await t.pumpAndSettle();
    t.semantics.performAction(
      find.semantics.byLabel('Minute'),
      SemanticsAction.increase,
    );
    await t.pumpAndSettle();
    expect(_state(t).value, DateTime(2026, 10, 6, 9, 45));
    handle.dispose();
  }, variant: ios);

  testWidgets('dateAndTime: both capsules', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(
        _Harness(
          pickerMode: GlassDatePickerMode.dateAndTime,
          use24HourFormat: false,
          initial: _at930,
        ),
      ),
    );
    expect(find.text('Oct 6, 2026'), findsOneWidget);
    expect(find.text('9:30 AM'), findsOneWidget);
    await t.tap(find.text('Oct 6, 2026'));
    await t.pumpAndSettle();
    expect(find.byType(GlassCalendar), findsOneWidget);
    await t.tap(find.text('20'));
    await t.pumpAndSettle();
    expect(_state(t).value, DateTime(2026, 10, 20, 9, 30));
  }, variant: ios);

  testWidgets('dateAndTime wheel: a weekday date column', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(
        _Harness(
          style: GlassDatePickerStyle.wheel,
          pickerMode: GlassDatePickerMode.dateAndTime,
          use24HourFormat: false,
          initial: _at930,
        ),
      ),
    );
    expect(find.byType(GlassWheelPicker<int>), findsNWidgets(4));
    expect(find.textContaining('Tue Oct 6'), findsOneWidget);
    await _scroll(t, 0);
    expect(_state(t).value, DateTime(2026, 10, 7, 9, 30));
  }, variant: ios);

  testWidgets('RTL: the time capsule leads the date capsule', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        _Harness(
          pickerMode: GlassDatePickerMode.dateAndTime,
          use24HourFormat: false,
          initial: _at930,
        ),
        direction: TextDirection.rtl,
      ),
    );
    expect(
      t.getTopLeft(find.text('Oct 6, 2026')).dx,
      greaterThan(t.getTopLeft(find.text('9:30 AM')).dx),
    );
  }, variant: ios);

  testWidgets('Reduce Motion: the wheel jumps', (t) async {
    shaderEnv();
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      appHost(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: _Harness(style: GlassDatePickerStyle.wheel),
        ),
      ),
    );
    t.semantics.performAction(
      find.semantics.byValue('6'),
      SemanticsAction.increase,
    );
    await t.pump();
    expect(_state(t).value, DateTime(2026, 10, 7));
    handle.dispose();
  }, variant: ios);

  testWidgets('disabled: no capsule tap and no wheel actions', (t) async {
    shaderEnv();
    final handle = t.ensureSemantics();
    await t.pumpWidget(appHost(const _Harness(enabled: false)));
    await t.tap(find.text('Oct 6, 2026'));
    await t.pumpAndSettle();
    expect(find.byType(GlassCalendar), findsNothing);
    await t.pumpWidget(
      appHost(
        const _Harness(style: GlassDatePickerStyle.wheel, enabled: false),
      ),
    );
    final day = t.getSemantics(find.byType(GlassWheelPicker<int>).at(1));
    expect(day.getSemanticsData().value, '6');
    expect(day.getSemanticsData().hasAction(SemanticsAction.increase), isFalse);
    handle.dispose();
  }, variant: ios);

  testWidgets('Material: time opens showTimePicker', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(const _Harness(pickerMode: GlassDatePickerMode.time)),
    );
    await t.tap(find.byType(TextButton));
    await t.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
  }, variant: android);

  testWidgets('Material: graphical shows CalendarDatePicker inline', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(const _Harness(style: GlassDatePickerStyle.graphical)),
    );
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    await t.tap(find.text('20'));
    await t.pumpAndSettle();
    expect(_state(t).value, DateTime(2026, 10, 20));
  }, variant: android);

  testWidgets('Material: dateAndTime shows two buttons', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(const _Harness(pickerMode: GlassDatePickerMode.dateAndTime)),
    );
    expect(find.byType(TextButton), findsNWidgets(2));
  }, variant: android);

  testWidgets('Material: wheel renders GlassDateWheel on a Material', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(const _Harness(style: GlassDatePickerStyle.wheel)),
    );
    expect(find.byType(GlassDateWheel), findsOneWidget);
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
