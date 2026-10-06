import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show DateUtils, DefaultMaterialLocalizations, MaterialLocalizations;

import '../core/glass_system_colors.dart';
import '../core/ios_text.dart';
import 'date_picker_metrics.dart';

/// A month calendar as iOS 26's compact date picker shows it: the month,
/// paging arrows, weekday initials and the days, the selected one on a
/// blue circle.
class GlassCalendar extends StatefulWidget {
  /// Creates a calendar showing [selected]'s month.
  const GlassCalendar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.firstDate,
    required this.lastDate,
  });

  /// The selected day.
  final DateTime selected;

  /// Called with the tapped day.
  final ValueChanged<DateTime> onSelected;

  /// The earliest selectable day.
  final DateTime firstDate;

  /// The latest selectable day.
  final DateTime lastDate;

  @override
  State<GlassCalendar> createState() => _GlassCalendarState();
}

class _GlassCalendarState extends State<GlassCalendar> {
  late DateTime _month = DateTime(widget.selected.year, widget.selected.month);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _selectable(DateTime d) =>
      !d.isBefore(_day(widget.firstDate)) && !d.isAfter(_day(widget.lastDate));

  void _page(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  @override
  Widget build(BuildContext context) {
    final l10n =
        Localizations.of<MaterialLocalizations>(
          context,
          MaterialLocalizations,
        ) ??
        const DefaultMaterialLocalizations();
    Color resolve(Color c) => CupertinoDynamicColor.resolve(c, context);
    final label = resolve(CupertinoColors.label);
    final blue = resolve(GlassSystemColors.blue);
    final first = l10n.firstDayOfWeekIndex;
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
          isSelected: DateTime(_month.year, _month.month, d) == selected,
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
                for (final w in weekdays)
                  Expanded(
                    child: Center(
                      child: Text(
                        w,
                        maxLines: 1,
                        style: IOSText.style(
                          DatePickerMetrics.weekdayFontSize,
                          weight: FontWeight.w600,
                          color: resolve(CupertinoColors.tertiaryLabel),
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
                child: Row(
                  children: [
                    for (var c = 0; c < 7; c++)
                      Expanded(
                        child: r * 7 + c < cells.length
                            ? cells[r * 7 + c]
                            : const SizedBox(),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
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
    required Color label,
    required Color blue,
  }) {
    final enabled = _selectable(day);
    final colour = isSelected
        ? CupertinoColors.white
        : !enabled
        ? CupertinoDynamicColor.resolve(CupertinoColors.tertiaryLabel, context)
        : isToday
        ? blue
        : label;
    return Semantics(
      button: true,
      selected: isSelected,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => widget.onSelected(day) : null,
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
