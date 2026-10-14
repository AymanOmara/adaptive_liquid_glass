import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        DateUtils,
        DefaultMaterialLocalizations,
        Material,
        MaterialLocalizations,
        Theme;

import '../core/cupertino_l10n.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../liquid_glass.dart';
import '../picker/glass_picker_item.dart';
import '../wheel_picker/glass_wheel_picker.dart';
import '../wheel_picker/wheel_picker_metrics.dart';
import 'date_picker_metrics.dart';
import 'glass_date_picker_mode.dart';

/// iOS's wheel date picker, like SwiftUI's `DatePicker` with
/// `.datePickerStyle(.wheel)`: the value's parts as wheel columns on one
/// glass surface, the chosen row of each under a shared clear-glass band.
///
/// ```dart
/// GlassDateWheel(
///   value: date,
///   firstDate: DateTime(2020),
///   lastDate: DateTime(2030),
///   onChanged: (d) => setState(() => date = d),
/// )
/// ```
///
/// [pickerMode] picks the columns: the day, month and year in
/// [GlassDatePickerMode.date]'s localised order; the hour, minute and
/// (12-hour locales) AM/PM in [GlassDatePickerMode.time]; both in
/// [GlassDatePickerMode.dateAndTime]. Null [onChanged] disables every
/// column. On the Material path the surface is a Material 3 one and the
/// band a primary-container capsule.
class GlassDateWheel extends StatefulWidget {
  /// Creates a wheel date picker.
  const GlassDateWheel({
    super.key,
    required this.value,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    this.pickerMode = GlassDatePickerMode.date,
    this.minuteInterval = 1,
    this.use24HourFormat,
    this.mode,
  }) : assert(
         minuteInterval > 0 && 60 % minuteInterval == 0,
         'minuteInterval must divide 60',
       );

  /// The selected value.
  final DateTime value;

  /// Called as a column settles; null disables the wheel.
  final ValueChanged<DateTime>? onChanged;

  /// The earliest date.
  final DateTime firstDate;

  /// The latest date.
  final DateTime lastDate;

  /// Which columns are shown; see [GlassDatePickerMode].
  final GlassDatePickerMode pickerMode;

  /// The minute column's step.
  final int minuteInterval;

  /// Overrides `MediaQuery.alwaysUse24HourFormat`.
  final bool? use24HourFormat;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassDateWheel> createState() => _GlassDateWheelState();
}

class _GlassDateWheelState extends State<GlassDateWheel> {
  bool get _enabled => widget.onChanged != null;

  MaterialLocalizations get _materialL10n =>
      Localizations.of<MaterialLocalizations>(context, MaterialLocalizations) ??
      const DefaultMaterialLocalizations();

  bool get _use24 =>
      widget.use24HourFormat ?? MediaQuery.alwaysUse24HourFormatOf(context);

  /// The value with [day], keeping its time.
  void _pickDay(int day) {
    final v = widget.value;
    widget.onChanged?.call(
      DateTime(v.year, v.month, day, v.hour, v.minute, v.second),
    );
  }

  /// The value with [month], its day clamped to the month's length.
  void _pickMonth(int month) {
    final v = widget.value;
    final last = DateUtils.getDaysInMonth(v.year, month);
    widget.onChanged?.call(
      DateTime(
        v.year,
        month,
        v.day > last ? last : v.day,
        v.hour,
        v.minute,
        v.second,
      ),
    );
  }

  /// The value with [year], its day clamped to the month's length.
  void _pickYear(int year) {
    final v = widget.value;
    final last = DateUtils.getDaysInMonth(year, v.month);
    widget.onChanged?.call(
      DateTime(
        year,
        v.month,
        v.day > last ? last : v.day,
        v.hour,
        v.minute,
        v.second,
      ),
    );
  }

  /// The value with hour [h] — a 12-hour clock's 1..12 in [use12]
  /// locales, read in the value's half of the day — keeping its date.
  void _pickHour(int h, {required bool use12}) {
    final v = widget.value;
    final hour = !use12
        ? h
        : v.hour < 12
        ? (h == 12 ? 0 : h)
        : (h == 12 ? 12 : h + 12);
    widget.onChanged?.call(
      DateTime(v.year, v.month, v.day, hour, v.minute, v.second),
    );
  }

  /// The value with minute [minute], keeping its date.
  void _pickMinute(int minute) {
    final v = widget.value;
    widget.onChanged?.call(
      DateTime(v.year, v.month, v.day, v.hour, minute, v.second),
    );
  }

  /// The value moved to the other half of the day ([period]: 0 AM,
  /// 1 PM), keeping its date.
  void _pickPeriod(int period) {
    final v = widget.value;
    final hour = period == 0 ? v.hour % 12 : v.hour % 12 + 12;
    widget.onChanged?.call(
      DateTime(v.year, v.month, v.day, hour, v.minute, v.second),
    );
  }

  /// [d]'s day in UTC, so differences count whole days across a
  /// daylight-saving change.
  static DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// The day [index] days past [GlassDateWheel.firstDate].
  DateTime _dayAt(int index) => DateTime(
    widget.firstDate.year,
    widget.firstDate.month,
    widget.firstDate.day + index,
  );

  /// The number of days from [GlassDateWheel.firstDate] to
  /// [GlassDateWheel.lastDate].
  int get _dayCount =>
      _day(widget.lastDate).difference(_day(widget.firstDate)).inDays;

  /// The value moved to the day [index] days past
  /// [GlassDateWheel.firstDate], keeping its time.
  void _pickDayIndex(int index) {
    final v = widget.value;
    final d = _dayAt(index);
    widget.onChanged?.call(
      DateTime(d.year, d.month, d.day, v.hour, v.minute, v.second),
    );
  }

  Widget _column({
    required double width,
    required List<GlassPickerItem<int>> items,
    required int selected,
    required ValueChanged<int>? onChanged,
    String? semanticLabel,
    AlignmentGeometry alignment = AlignmentDirectional.center,
    EdgeInsetsGeometry? padding,
  }) => SizedBox(
    width: width,
    child: GlassWheelPicker<int>(
      surface: false,
      mode: widget.mode,
      items: items,
      selected: selected,
      onChanged: onChanged,
      semanticLabel: semanticLabel,
      alignment: alignment,
      rowPadding:
          padding ??
          const EdgeInsetsDirectional.symmetric(
            horizontal: WheelPickerMetrics.rowPadding,
          ),
    ),
  );

  /// Lays [columns] out across the surface as UIDatePicker does: each is
  /// `(endAligned, line, build)`, its label ending (end-aligned) or
  /// starting at `line` from the surface's leading edge; the columns meet
  /// [DatePickerWheelMetrics.timeColumnGap] past an end line or before the
  /// next start line, and the last takes the rest of the surface.
  List<Widget> _placed(
    List<
      (
        bool,
        double,
        Widget Function(
          double width,
          AlignmentGeometry alignment,
          EdgeInsetsGeometry padding,
        ),
      )
    >
    columns,
  ) {
    const gap = DatePickerWheelMetrics.timeColumnGap;
    final out = <Widget>[];
    var left = 0.0;
    for (var i = 0; i < columns.length; i++) {
      final (endAligned, line, build) = columns[i];
      final last = i == columns.length - 1;
      final right = last
          ? WheelPickerMetrics.width
          : endAligned
          ? line + gap
          : columns[i + 1].$2 - gap;
      out.add(
        endAligned
            ? build(
                right - left,
                AlignmentDirectional.centerEnd,
                EdgeInsetsDirectional.only(end: right - line),
              )
            : build(
                right - left,
                AlignmentDirectional.centerStart,
                EdgeInsetsDirectional.only(start: line - left),
              ),
      );
      left = right;
    }
    return out;
  }

  List<Widget> _dateColumns(CupertinoLocalizations l10n) {
    final v = widget.value;
    final days = DateUtils.getDaysInMonth(v.year, v.month);
    final day = _column(
      width: DatePickerWheelMetrics.dayWidth,
      items: [
        for (var d = 1; d <= days; d++)
          GlassPickerItem(value: d, label: l10n.datePickerDayOfMonth(d)),
      ],
      selected: v.day,
      onChanged: _enabled ? _pickDay : null,
    );
    final month = _column(
      width: DatePickerWheelMetrics.monthWidth,
      items: [
        for (var m = 1; m <= 12; m++)
          GlassPickerItem(value: m, label: l10n.datePickerMonth(m)),
      ],
      selected: v.month,
      onChanged: _enabled ? _pickMonth : null,
    );
    final year = _column(
      width: DatePickerWheelMetrics.yearWidth,
      items: [
        for (var y = widget.firstDate.year; y <= widget.lastDate.year; y++)
          GlassPickerItem(value: y, label: l10n.datePickerYear(y)),
      ],
      selected: v.year,
      onChanged: _enabled ? _pickYear : null,
    );
    return switch (l10n.datePickerDateOrder) {
      DatePickerDateOrder.dmy => [day, month, year],
      DatePickerDateOrder.mdy => [month, day, year],
      DatePickerDateOrder.ymd => [year, month, day],
      DatePickerDateOrder.ydm => [year, day, month],
    };
  }

  /// The hour, minute and (12-hour) AM/PM columns, each as
  /// `(endAligned, line, build)` for [_placed]: [hourEnd] is where the
  /// hours end, [minuteStart] and [periodStart] where the minutes and
  /// AM/PM start.
  List<
    (
      bool,
      double,
      Widget Function(double, AlignmentGeometry, EdgeInsetsGeometry),
    )
  >
  _timeColumns(
    CupertinoLocalizations l10n, {
    required double hourEnd,
    required double minuteStart,
    required double periodStart,
  }) {
    final v = widget.value;
    final use12 = !_use24;
    return [
      (
        true,
        hourEnd,
        (width, alignment, padding) => _column(
          width: width,
          alignment: alignment,
          padding: padding,
          items: [
            for (var h = use12 ? 1 : 0; h <= (use12 ? 12 : 23); h++)
              GlassPickerItem(value: h, label: l10n.datePickerHour(h)),
          ],
          selected: use12 ? (v.hour % 12 == 0 ? 12 : v.hour % 12) : v.hour,
          onChanged: _enabled ? (h) => _pickHour(h, use12: use12) : null,
          semanticLabel: _materialL10n.timePickerHourLabel,
        ),
      ),
      (
        false,
        minuteStart,
        (width, alignment, padding) => _column(
          width: width,
          alignment: alignment,
          padding: padding,
          items: [
            for (var m = 0; m < 60; m += widget.minuteInterval)
              GlassPickerItem(value: m, label: l10n.datePickerMinute(m)),
          ],
          selected: v.minute - v.minute % widget.minuteInterval,
          onChanged: _enabled ? _pickMinute : null,
          semanticLabel: _materialL10n.timePickerMinuteLabel,
        ),
      ),
      if (use12)
        (
          false,
          periodStart,
          (width, alignment, padding) => _column(
            width: width,
            alignment: alignment,
            padding: padding,
            items: [
              GlassPickerItem(value: 0, label: l10n.anteMeridiemAbbreviation),
              GlassPickerItem(value: 1, label: l10n.postMeridiemAbbreviation),
            ],
            selected: v.hour < 12 ? 0 : 1,
            onChanged: _enabled ? _pickPeriod : null,
          ),
        ),
    ];
  }

  List<Widget> _columns(CupertinoLocalizations l10n) =>
      switch (widget.pickerMode) {
        GlassDatePickerMode.date => _dateColumns(l10n),
        GlassDatePickerMode.time => _placed(
          _use24
              ? _timeColumns(
                  l10n,
                  hourEnd: DatePickerWheelMetrics.time24HourEnd,
                  minuteStart: DatePickerWheelMetrics.time24MinuteStart,
                  periodStart: 0,
                )
              : _timeColumns(
                  l10n,
                  hourEnd: DatePickerWheelMetrics.time12HourEnd,
                  minuteStart: DatePickerWheelMetrics.time12MinuteStart,
                  periodStart: DatePickerWheelMetrics.time12PeriodStart,
                ),
        ),
        GlassDatePickerMode.dateAndTime => _placed([
          // Every day of the range, one row per day, by its offset from
          // [firstDate].
          (
            true,
            DatePickerWheelMetrics.dateTimeDateEnd,
            (width, alignment, padding) => _column(
              width: width,
              alignment: alignment,
              padding: padding,
              items: [
                for (var i = 0; i <= _dayCount; i++)
                  GlassPickerItem(
                    value: i,
                    label: l10n.datePickerMediumDate(_dayAt(i)),
                  ),
              ],
              selected: _day(
                widget.value,
              ).difference(_day(widget.firstDate)).inDays,
              onChanged: _enabled ? _pickDayIndex : null,
            ),
          ),
          ..._timeColumns(
            l10n,
            hourEnd: DatePickerWheelMetrics.dateTimeHourEnd,
            minuteStart: DatePickerWheelMetrics.dateTimeMinuteStart,
            periodStart: DatePickerWheelMetrics.dateTimePeriodStart,
          ),
        ]),
      };

  @override
  Widget build(BuildContext context) {
    final columns = _columns(cupertinoL10n(context));
    // Every time style keeps UIDatePicker's 320-pt surface (measured).
    final width = widget.pickerMode == GlassDatePickerMode.date
        ? DatePickerWheelMetrics.dayWidth +
              DatePickerWheelMetrics.monthWidth +
              DatePickerWheelMetrics.yearWidth
        : WheelPickerMetrics.width;
    // The rows keep their size at any text size, as UIDatePicker's.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: WheelPickerMetrics.maxTextScale,
      child: GlassModeBuilder(
        mode: widget.mode,
        builder: (context, effective) => Semantics(
          container: true,
          child: SizedBox(
            height: WheelPickerMetrics.height,
            width: width,
            child: effective == EffectiveGlassMode.material
                ? _material(context, columns)
                : _glass(columns),
          ),
        ),
      ),
    );
  }

  /// The selection band across the centre, under the columns.
  Widget _band(Widget band) => Align(
    child: Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: WheelPickerMetrics.bandInset,
      ),
      child: SizedBox(
        height: DatePickerWheelMetrics.bandHeight,
        width: double.infinity,
        child: IgnorePointer(child: ExcludeSemantics(child: band)),
      ),
    ),
  );

  Widget _glass(List<Widget> columns) => LiquidGlass(
    shape: const GlassShape.rect(WheelPickerMetrics.surfaceRadius),
    mode: widget.mode,
    child: Stack(
      fit: StackFit.expand,
      children: [
        _band(
          LiquidGlass(
            glass: Glass.clear,
            shape: const GlassShape.rect(WheelPickerMetrics.bandRadius),
            mode: widget.mode,
            child: const SizedBox.expand(),
          ),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: columns),
      ],
    ),
  );

  Widget _material(BuildContext context, List<Widget> columns) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: const BorderRadius.all(
        Radius.circular(WheelPickerMetrics.surfaceRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _band(
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: const BorderRadius.all(
                  Radius.circular(WheelPickerMetrics.bandRadius),
                ),
              ),
            ),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: columns),
        ],
      ),
    );
  }
}
