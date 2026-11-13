import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/date_picker/date_picker_metrics.dart';
import 'package:adaptive_liquid_glass/src/date_picker/date_picker_wheel_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

/// Pumps an inline calendar 370 pt wide on Oct 6, 2026, as
/// `-controls calendargraphical` lays it out.
Future<void> _pump(WidgetTester t, {bool inline = true}) => t.pumpWidget(
  appHost(
    SizedBox(
      width: inline ? 370 : null,
      child: GlassCalendar(
        selected: DateTime(2026, 10, 6),
        onSelected: (_) {},
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        firstDayOfWeek: 0,
        inline: inline,
      ),
    ),
  ),
);

/// The circle behind day [n]'s number.
Finder _circle(int n) =>
    find.ancestor(of: find.text('$n'), matching: find.byType(Container)).first;

void main() {
  test('inline calendar metrics are the measured ones', () {
    // `-controls calendargraphical(time)`, iOS 26.4, width 370.
    expect(DatePickerMetrics.inlineTop, 16);
    expect(DatePickerMetrics.inlineHeaderHeight, 37.67);
    expect(DatePickerMetrics.inlineInset, 8);
    expect(DatePickerMetrics.inlineArrowWidth, 43.33);
    expect(DatePickerMetrics.inlineWeekdayGap, 16);
    expect(DatePickerMetrics.inlineWeekdayHeight, 17.67);
    expect(DatePickerMetrics.inlineRow, 44);
    expect(DatePickerMetrics.inlineSelection, 44);
    expect(DatePickerMetrics.selectedTintAlpha, 0.12);
    expect(DatePickerWheelMetrics.timeRowGap, 5.33);
    expect(DatePickerWheelMetrics.timeRowHeight, 40);
    expect(DatePickerWheelMetrics.timeRowInset, 8);
  });

  testWidgets('inline fills its width with 44-pt rows and circles', (t) async {
    await _pump(t);
    expect(t.getSize(find.byType(GlassCalendar)).width, 370);
    expect(t.getSize(_circle(6)), const Size(44, 44));
    // Rows 44 apart; columns split the width in seven (52.86; UIKit 52.67).
    final d6 = t.getCenter(_circle(6)), d13 = t.getCenter(_circle(13));
    final d7 = t.getCenter(_circle(7));
    expect(d13.dy - d6.dy, closeTo(44, 0.01));
    expect(d7.dx - d6.dx, closeTo(370 / 7, 0.01));
    // Header 16 below the top, weekdays 16 under its 37.67, rows 1 after.
    final top = t.getTopLeft(find.byType(GlassCalendar)).dy;
    final weekday = t.getTopLeft(find.text('SUN')).dy;
    expect(
      weekday - top,
      closeTo(
        16 + 37.67 + 16 + (17.67 - t.getSize(find.text('SUN')).height) / 2,
        0.5,
      ),
    );
  });

  testWidgets('a selected day other than today is tinted, not solid', (
    t,
  ) async {
    await _pump(t);
    final deco = t.widget<Container>(_circle(6)).decoration! as ShapeDecoration;
    expect(deco.color!.a, closeTo(DatePickerMetrics.selectedTintAlpha, 0.01));
    final text = t.widget<Text>(find.text('6'));
    expect(text.style!.color!.b, greaterThan(0.9));
  });

  testWidgets('the popover calendar keeps its 320-pt layout', (t) async {
    await _pump(t, inline: false);
    expect(
      t.getSize(find.byType(GlassCalendar)).width,
      DatePickerMetrics.calendarWidth,
    );
    expect(
      t.getSize(_circle(6)),
      const Size.square(DatePickerMetrics.selection),
    );
  });
}
