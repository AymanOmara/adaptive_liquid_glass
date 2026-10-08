import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        CalendarDatePicker,
        DefaultMaterialLocalizations,
        MaterialLocalizations,
        TextButton,
        TimeOfDay,
        showDatePicker,
        showTimePicker;

import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_system_colors.dart';
import '../core/ios_text.dart';
import '../popover/popover_metrics.dart';
import '../popover/show_glass_popover.dart';
import 'date_picker_metrics.dart';
import 'glass_calendar.dart';
import 'glass_date_picker_mode.dart';
import 'glass_date_picker_style.dart';
import 'glass_date_wheel.dart';

/// iOS 26's date picker, like SwiftUI's `DatePicker`: the value in a
/// grey capsule opening a popover ([GlassDatePickerStyle.compact], the
/// default), the calendar inline ([GlassDatePickerStyle.graphical]) or
/// wheel columns on one glass surface ([GlassDatePickerStyle.wheel]).
///
/// ```dart
/// GlassDatePicker(
///   value: date,
///   firstDate: DateTime(2020),
///   lastDate: DateTime(2030),
///   onChanged: (d) => setState(() => date = d),
/// )
/// ```
///
/// [pickerMode] picks what is edited: the date
/// ([GlassDatePickerMode.date], the default), the time
/// ([GlassDatePickerMode.time]) or both
/// ([GlassDatePickerMode.dateAndTime]). The value reads in the app's
/// locale ([format] overrides the date capsule); while a popover is open
/// its capsule is blue. Picking a day closes the calendar; the time
/// wheel changes apply live, like iOS. On the Material path it uses
/// [showDatePicker], [showTimePicker] and [CalendarDatePicker].
class GlassDatePicker extends StatefulWidget {
  /// Creates a date picker.
  const GlassDatePicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    this.format,
    this.style = GlassDatePickerStyle.compact,
    this.pickerMode = GlassDatePickerMode.date,
    this.minuteInterval = 1,
    this.showWeekNumbers = false,
    this.use24HourFormat,
    this.mode,
  }) : assert(
         minuteInterval > 0 && 60 % minuteInterval == 0,
         'minuteInterval must divide 60',
       );

  /// The selected date.
  final DateTime value;

  /// Called with the picked date; null disables the picker.
  final ValueChanged<DateTime>? onChanged;

  /// The earliest date.
  final DateTime firstDate;

  /// The latest date.
  final DateTime lastDate;

  /// Formats the date in the capsule. Defaults to the short month and day
  /// with the year ("Oct 6, 2026").
  final String Function(DateTime date)? format;

  /// How the picker is laid out; see [GlassDatePickerStyle].
  final GlassDatePickerStyle style;

  /// Which parts of [value] are edited; see [GlassDatePickerMode].
  final GlassDatePickerMode pickerMode;

  /// The minute step of the time wheel (must divide 60).
  final int minuteInterval;

  /// Whether the graphical calendar leads each row with its ISO week
  /// number.
  final bool showWeekNumbers;

  /// Whether the time reads and is picked in 24-hour form. Defaults to
  /// `MediaQuery.alwaysUse24HourFormat`.
  final bool? use24HourFormat;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassDatePicker> createState() => _GlassDatePickerState();
}

class _GlassDatePickerState extends State<GlassDatePicker> {
  bool _dateOpen = false;
  bool _timeOpen = false;

  MaterialLocalizations get _l10n =>
      Localizations.of<MaterialLocalizations>(context, MaterialLocalizations) ??
      const DefaultMaterialLocalizations();

  bool get _enabled => widget.onChanged != null;

  bool get _use24 =>
      widget.use24HourFormat ?? MediaQuery.alwaysUse24HourFormatOf(context);

  String get _text =>
      widget.format?.call(widget.value) ??
      '${_l10n.formatShortMonthDay(widget.value)}, '
          '${_l10n.formatYear(widget.value)}';

  String get _timeText => _l10n.formatTimeOfDay(
    TimeOfDay.fromDateTime(widget.value),
    alwaysUse24HourFormat: _use24,
  );

  Future<void> _showDate(BuildContext anchor) async {
    setState(() => _dateOpen = true);
    final picked = await showGlassPopover<DateTime>(
      context: anchor,
      overlap: PopoverMetrics.calendarOverlap,
      mode: widget.mode,
      builder: (context) => GlassCalendar(
        selected: widget.value,
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
        showWeekNumbers: widget.showWeekNumbers,
        onSelected: (d) => Navigator.of(context).pop(d),
      ),
    );
    if (!mounted) return;
    setState(() => _dateOpen = false);
    if (picked != null) {
      final v = widget.value;
      widget.onChanged?.call(
        DateTime(picked.year, picked.month, picked.day, v.hour, v.minute),
      );
    }
  }

  Future<void> _showTime(BuildContext anchor) async {
    setState(() => _timeOpen = true);
    // The popover's builder would freeze the value at open time; track
    // the latest one so the wheel follows its own changes.
    var latest = widget.value;
    await showGlassPopover<void>(
      context: anchor,
      overlap: PopoverMetrics.calendarOverlap,
      mode: widget.mode,
      builder: (context) => StatefulBuilder(
        builder: (context, setLatest) => Padding(
          padding: const EdgeInsetsDirectional.all(
            DatePickerWheelMetrics.popoverPadding,
          ),
          child: GlassDateWheel(
            pickerMode: GlassDatePickerMode.time,
            value: latest,
            firstDate: widget.firstDate,
            lastDate: widget.lastDate,
            minuteInterval: widget.minuteInterval,
            use24HourFormat: widget.use24HourFormat,
            mode: widget.mode,
            onChanged: (d) {
              latest = d;
              setLatest(() {});
              widget.onChanged?.call(d);
            },
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _timeOpen = false);
  }

  Future<void> _materialDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.value,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    if (picked == null) return;
    final v = widget.value;
    widget.onChanged?.call(
      DateTime(picked.year, picked.month, picked.day, v.hour, v.minute),
    );
  }

  Future<void> _materialTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(widget.value),
    );
    if (picked == null) return;
    final v = widget.value;
    widget.onChanged?.call(
      DateTime(v.year, v.month, v.day, picked.hour, picked.minute),
    );
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, effective) =>
        effective == EffectiveGlassMode.material ? _material() : _glass(),
  );

  Widget _glass() => switch (widget.style) {
    GlassDatePickerStyle.compact => _compact(),
    GlassDatePickerStyle.graphical => _graphical(),
    GlassDatePickerStyle.wheel => _wheel(),
  };

  Widget _compact() => switch (widget.pickerMode) {
    GlassDatePickerMode.date => _dateCapsule(),
    GlassDatePickerMode.time => _timeCapsule(),
    GlassDatePickerMode.dateAndTime => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dateCapsule(),
        const SizedBox(width: DatePickerWheelMetrics.capsuleGap),
        _timeCapsule(),
      ],
    ),
  };

  Widget _graphical() => switch (widget.pickerMode) {
    GlassDatePickerMode.date => _calendar(),
    GlassDatePickerMode.time => _timeCapsule(),
    GlassDatePickerMode.dateAndTime => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _calendar(),
        const SizedBox(height: DatePickerWheelMetrics.timeRowGap),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [_timeCapsule()],
        ),
      ],
    ),
  };

  Widget _wheel() => GlassDateWheel(
    value: widget.value,
    onChanged: widget.onChanged,
    firstDate: widget.firstDate,
    lastDate: widget.lastDate,
    pickerMode: widget.pickerMode,
    minuteInterval: widget.minuteInterval,
    use24HourFormat: widget.use24HourFormat,
    mode: widget.mode,
  );

  Widget _dateCapsule() => _Capsule(
    text: _text,
    enabled: _enabled,
    open: _dateOpen,
    onTap: _enabled ? _showDate : null,
  );

  Widget _timeCapsule() => _Capsule(
    text: _timeText,
    enabled: _enabled,
    open: _timeOpen,
    onTap: _enabled ? _showTime : null,
  );

  Widget _calendar() => IgnorePointer(
    ignoring: !_enabled,
    child: GlassCalendar(
      selected: widget.value,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      showWeekNumbers: widget.showWeekNumbers,
      onSelected: (d) {
        final v = widget.value;
        widget.onChanged?.call(
          DateTime(d.year, d.month, d.day, v.hour, v.minute),
        );
      },
    ),
  );

  Widget _material() => switch (widget.style) {
    GlassDatePickerStyle.compact => switch (widget.pickerMode) {
      GlassDatePickerMode.date => _materialDateButton(),
      GlassDatePickerMode.time => _materialTimeButton(),
      GlassDatePickerMode.dateAndTime => Row(
        mainAxisSize: MainAxisSize.min,
        children: [_materialDateButton(), _materialTimeButton()],
      ),
    },
    GlassDatePickerStyle.graphical => switch (widget.pickerMode) {
      GlassDatePickerMode.date => _materialCalendar(),
      GlassDatePickerMode.time => _materialTimeButton(),
      GlassDatePickerMode.dateAndTime => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _materialCalendar(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_materialTimeButton()],
          ),
        ],
      ),
    },
    GlassDatePickerStyle.wheel => _wheel(),
  };

  Widget _materialDateButton() => TextButton(
    onPressed: _enabled ? _materialDate : null,
    child: Text(_text),
  );

  Widget _materialTimeButton() => TextButton(
    onPressed: _enabled ? _materialTime : null,
    child: Text(_timeText),
  );

  Widget _materialCalendar() => IgnorePointer(
    ignoring: !_enabled,
    child: CalendarDatePicker(
      initialDate: widget.value,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      onDateChanged: (d) {
        final v = widget.value;
        widget.onChanged?.call(
          DateTime(d.year, d.month, d.day, v.hour, v.minute),
        );
      },
    ),
  );
}

/// The value in a grey capsule, blue while its popover is open, after
/// iOS 26's compact date picker.
class _Capsule extends StatelessWidget {
  /// Creates a capsule reading [text].
  const _Capsule({
    required this.text,
    required this.enabled,
    required this.open,
    this.onTap,
  });

  /// The capsule's label.
  final String text;

  /// Whether the picker accepts changes.
  final bool enabled;

  /// Whether the capsule's popover is open (the label turns blue).
  final bool open;

  /// Opens the popover with the anchor's context; null when disabled.
  final void Function(BuildContext anchor)? onTap;

  @override
  Widget build(BuildContext context) {
    final colour = CupertinoDynamicColor.resolve(
      !enabled
          ? GlassColors.tertiaryLabel
          : open
          ? GlassSystemColors.blue
          : GlassColors.label,
      context,
    );
    return Builder(
      builder: (anchor) => Semantics(
        button: true,
        enabled: enabled,
        value: text,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap == null ? null : () => onTap!(anchor),
          child: Container(
            height: DatePickerMetrics.height,
            padding: const EdgeInsets.symmetric(
              horizontal: DatePickerMetrics.padding,
            ),
            // No alignment: the capsule hugs the value.
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: CupertinoDynamicColor.resolve(
                GlassColors.stepperFill,
                context,
              ),
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                text,
                maxLines: 1,
                style: IOSText.style(DatePickerMetrics.fontSize, color: colour),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
