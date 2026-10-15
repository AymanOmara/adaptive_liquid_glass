import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show DateUtils, DefaultMaterialLocalizations, MaterialLocalizations;

import '../core/glass_colors.dart';
import '../core/glass_system_colors.dart';
import '../core/ios_text.dart';
import 'date_picker_metrics.dart';
import 'date_picker_wheel_metrics.dart';

/// A month calendar as iOS 26's compact date picker shows it: the month,
/// paging arrows, weekday initials and the days, the selected one on a
/// blue circle. `GlassDatePicker` shows it inline in its graphical style
/// and in a popover in its compact style.
///
/// ```dart
/// GlassCalendar(
///   selected: date,
///   firstDate: DateTime(2020),
///   lastDate: DateTime(2030),
///   onSelected: (d) => setState(() => date = d),
/// )
/// ```
///
/// [GlassCalendar.range] picks a range instead: the ends on blue
/// circles joined by a lighter band that wraps per week row.
class GlassCalendar extends StatefulWidget {
  /// Creates a calendar showing [selected]'s month.
  const GlassCalendar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.firstDate,
    required this.lastDate,
    this.showWeekNumbers = false,
    this.firstDayOfWeek,
  }) : assert(
         firstDayOfWeek == null || (firstDayOfWeek >= 0 && firstDayOfWeek < 7),
         'firstDayOfWeek is 0 (Sunday) to 6 (Saturday)',
       ),
       rangeStart = null,
       rangeEnd = null,
       onRangeChanged = null;

  /// Creates a calendar that picks a range from [rangeStart] to
  /// [rangeEnd], as iOS draws one: both ends on blue circles and a
  /// lighter capsule joining the days between, wrapping per week row.
  ///
  /// A tap with no start, after a complete range or before the start
  /// begins a new range at the tapped day; any other tap ends it there
  /// (the start itself gives a one-day range). [onRangeChanged] receives
  /// the new start and end (null until the end is picked); the calendar
  /// shows what its parent passes back. It opens on [rangeStart]'s month,
  /// or today's within the bounds.
  const GlassCalendar.range({
    super.key,
    required this.rangeStart,
    this.rangeEnd,
    required GlassCalendarRangeChanged this.onRangeChanged,
    required this.firstDate,
    required this.lastDate,
    this.showWeekNumbers = false,
    this.firstDayOfWeek,
  }) : assert(
         firstDayOfWeek == null || (firstDayOfWeek >= 0 && firstDayOfWeek < 7),
         'firstDayOfWeek is 0 (Sunday) to 6 (Saturday)',
       ),
       assert(
         rangeEnd == null || rangeStart != null,
         'rangeEnd needs a rangeStart',
       ),
       selected = rangeStart ?? firstDate,
       onSelected = _ignore;

  static void _ignore(DateTime _) {}

  /// The range's first day, in [GlassCalendar.range]; null before one is
  /// picked.
  final DateTime? rangeStart;

  /// The range's last day, in [GlassCalendar.range]; null until it is
  /// picked.
  final DateTime? rangeEnd;

  /// Called in [GlassCalendar.range] with the range a tap makes; null in
  /// the single-day calendar.
  final GlassCalendarRangeChanged? onRangeChanged;

  /// The selected day; in [GlassCalendar.range], the start (or
  /// [firstDate] before one is picked).
  final DateTime selected;

  /// Called with the tapped day.
  final ValueChanged<DateTime> onSelected;

  /// The earliest selectable day.
  final DateTime firstDate;

  /// The latest selectable day.
  final DateTime lastDate;

  /// Whether a column of ISO week numbers leads each row (estimated
  /// layout).
  final bool showWeekNumbers;

  /// The weekday leading each row: 0 for Sunday to 6 for Saturday, as
  /// `MaterialLocalizations.firstDayOfWeekIndex` counts
  /// (`DateTime.monday % 7` is Monday). Null follows the locale.
  final int? firstDayOfWeek;

  @override
  State<GlassCalendar> createState() => _GlassCalendarState();
}

/// Receives a [GlassCalendar.range]'s new [start] and [end]; [end] is
/// null until the range's last day is picked.
typedef GlassCalendarRangeChanged =
    void Function(DateTime start, DateTime? end);

class _GlassCalendarState extends State<GlassCalendar> {
  late DateTime _month = _initialMonth();

  bool get _isRange => widget.onRangeChanged != null;

  DateTime _initialMonth() {
    var d = widget.selected;
    if (_isRange && widget.rangeStart == null) {
      d = _day(DateTime.now());
      final first = _day(widget.firstDate);
      final last = _day(widget.lastDate);
      if (d.isBefore(first)) d = first;
      if (d.isAfter(last)) d = last;
    }
    return DateTime(d.year, d.month);
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime? get _start =>
      widget.rangeStart == null ? null : _day(widget.rangeStart!);

  DateTime? get _end => widget.rangeEnd == null ? null : _day(widget.rangeEnd!);

  void _tap(DateTime day) {
    final onRange = widget.onRangeChanged;
    if (onRange == null) return widget.onSelected(day);
    final start = _start;
    if (start == null || _end != null || day.isBefore(start)) {
      onRange(day, null);
    } else {
      onRange(start, day);
    }
  }

  /// Whether [d] is an end of the range (or the selected day).
  bool _isEnd(DateTime d, DateTime selected) =>
      _isRange ? d == _start || d == _end : d == selected;

  /// Whether [d] lies within a complete range, ends included.
  bool _inRange(DateTime d) {
    final start = _start, end = _end;
    return start != null &&
        end != null &&
        !d.isBefore(start) &&
        !d.isAfter(end);
  }

  bool _selectable(DateTime d) =>
      !d.isBefore(_day(widget.firstDate)) && !d.isAfter(_day(widget.lastDate));

  void _page(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  /// The ISO-8601 week number of [d]'s week: the week of its Thursday,
  /// counted from the year's first Monday. In UTC, so a daylight-saving
  /// hour cannot shorten a day.
  static int _isoWeek(DateTime d) {
    final thursday = DateTime.utc(d.year, d.month, d.day + 3 - (d.weekday - 1));
    return 1 + thursday.difference(DateTime.utc(thursday.year)).inDays ~/ 7;
  }

  /// A week row's leading week-number cell; [start] is the day of the
  /// month in its first cell (zero or negative for a leading blank). The
  /// row's fourth day decides the week, whichever weekday leads it.
  Widget _weekNumber(int start, Color colour) => SizedBox(
    width: DatePickerWheelMetrics.weekNumberWidth,
    child: Center(
      child: ExcludeSemantics(
        child: Text(
          '${_isoWeek(DateTime(_month.year, _month.month, start + 3))}',
          style: IOSText.style(
            DatePickerMetrics.weekdayFontSize,
            color: colour,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n =
        Localizations.of<MaterialLocalizations>(
          context,
          MaterialLocalizations,
        ) ??
        const DefaultMaterialLocalizations();
    Color resolve(Color c) => CupertinoDynamicColor.resolve(c, context);
    final label = resolve(GlassColors.label);
    final blue = resolve(GlassSystemColors.blue);
    final first = widget.firstDayOfWeek ?? l10n.firstDayOfWeekIndex;
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    // DateTime.weekday: Monday 1 ... Sunday 7; the index: Sunday 0.
    final lead = (DateTime(_month.year, _month.month).weekday % 7 - first) % 7;
    final today = _day(DateTime.now());
    final selected = _day(widget.selected);
    // Weekday names from the localisations: the medium date of a known
    // week, up to its comma ("Sun, Oct 4" -> "SUN").
    final weekdays = [
      for (var i = 0; i < 7; i++)
        l10n
            .formatMediumDate(DateTime(2026, 10, 4 + (first + i) % 7))
            .split(',')
            .first
            .toUpperCase(),
    ];
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox(),
      for (var d = 1; d <= daysInMonth; d++)
        _dayCell(
          DateTime(_month.year, _month.month, d),
          isSelected: _isEnd(DateTime(_month.year, _month.month, d), selected),
          inRange: _inRange(DateTime(_month.year, _month.month, d)),
          isToday: DateTime(_month.year, _month.month, d) == today,
          label: label,
          blue: blue,
        ),
    ];
    return SizedBox(
      width: DatePickerMetrics.calendarWidth,
      child: Padding(
        padding: const EdgeInsets.all(DatePickerMetrics.calendarPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          l10n.formatMonthYear(_month),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: IOSText.style(
                            DatePickerMetrics.headerFontSize,
                            weight: FontWeight.w600,
                            color: label,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(CupertinoIcons.chevron_right, size: 15, color: blue),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _arrow(
                  CupertinoIcons.chevron_left,
                  -1,
                  label,
                  l10n.previousMonthTooltip,
                ),
                const SizedBox(width: 16),
                _arrow(
                  CupertinoIcons.chevron_right,
                  1,
                  label,
                  l10n.nextMonthTooltip,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.showWeekNumbers)
                  const SizedBox(
                    width: DatePickerWheelMetrics.weekNumberWidth,
                    child: Center(child: Text('')),
                  ),
                for (final w in weekdays)
                  Expanded(
                    child: Center(
                      child: Text(
                        w,
                        maxLines: 1,
                        style: IOSText.style(
                          DatePickerMetrics.weekdayFontSize,
                          weight: FontWeight.w600,
                          color: resolve(GlassColors.tertiaryLabel),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (var r = 0; r * 7 < cells.length; r++)
              SizedBox(
                height: DatePickerMetrics.row,
                child: _rangeBand(
                  r * 7 - lead + 1,
                  daysInMonth,
                  blue,
                  Row(
                    children: [
                      if (widget.showWeekNumbers)
                        _weekNumber(
                          r * 7 - lead + 1,
                          resolve(GlassColors.tertiaryLabel),
                        ),
                      for (var c = 0; c < 7; c++)
                        Expanded(
                          child: r * 7 + c < cells.length
                              ? cells[r * 7 + c]
                              : const SizedBox(),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Puts the lighter capsule behind a week row's in-range days: from
  /// the first such day's circle to the last's, so it ends under the
  /// endpoints' circles and wraps at the row's edges. [start] is the day
  /// of the month in the row's first cell, as in [_weekNumber].
  Widget _rangeBand(int start, int daysInMonth, Color blue, Widget row) {
    int? from, to;
    for (var c = 0; c < 7; c++) {
      final d = start + c;
      if (d < 1 || d > daysInMonth) continue;
      if (_inRange(DateTime(_month.year, _month.month, d))) {
        from ??= c;
        to = c;
      }
    }
    if (from == null || to == null || from == to) return row;
    final lead = widget.showWeekNumbers
        ? DatePickerWheelMetrics.weekNumberWidth
        : 0.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final column = (constraints.maxWidth - lead) / 7;
        const inset = DatePickerMetrics.selection / 2;
        return Stack(
          children: [
            PositionedDirectional(
              start: lead + column * (from! + 0.5) - inset,
              width: column * (to! - from) + DatePickerMetrics.selection,
              top: (constraints.maxHeight - DatePickerMetrics.selection) / 2,
              height: DatePickerMetrics.selection,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: blue.withValues(alpha: DatePickerMetrics.rangeAlpha),
                ),
              ),
            ),
            Positioned.fill(child: row),
          ],
        );
      },
    );
  }

  Widget _arrow(IconData icon, int by, Color colour, String label) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _page(by),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 20, color: colour),
      ),
    ),
  );

  Widget _dayCell(
    DateTime day, {
    required bool isSelected,
    required bool isToday,
    bool inRange = false,
    required Color label,
    required Color blue,
  }) {
    final enabled = _selectable(day);
    final colour = isSelected
        ? GlassColors.white
        : !enabled
        ? CupertinoDynamicColor.resolve(GlassColors.tertiaryLabel, context)
        : isToday
        ? blue
        : label;
    return Semantics(
      button: true,
      selected: isSelected || inRange,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => _tap(day) : null,
        child: Center(
          child: Container(
            width: DatePickerMetrics.selection,
            height: DatePickerMetrics.selection,
            alignment: Alignment.center,
            decoration: isSelected
                ? ShapeDecoration(shape: const CircleBorder(), color: blue)
                : null,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${day.day}',
                style: IOSText.style(
                  DatePickerMetrics.dayFontSize,
                  weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: colour,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
