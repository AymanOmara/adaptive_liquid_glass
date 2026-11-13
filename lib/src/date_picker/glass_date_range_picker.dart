part of 'glass_date_picker.dart';

/// A date picker for a range of days, the inline counterpart of
/// [showGlassDateRangePicker]: the range in a grey capsule opening the
/// range sheet ([GlassDatePickerStyle.compact], the default) or the range
/// calendar inline ([GlassDatePickerStyle.graphical]), as iOS 26 draws a
/// graphical `DatePicker` or `MultiDatePicker` picking consecutive days.
///
/// ```dart
/// GlassDateRangePicker(
///   value: trip,
///   firstDate: DateTime(2020),
///   lastDate: DateTime(2030),
///   onChanged: (r) => setState(() => trip = r),
/// )
/// ```
///
/// Inline, the first tap picks the start and the second the end (the same
/// day gives a one-day range); a tap before the start, or after a complete
/// range, starts again. [onChanged] receives only complete ranges, with
/// the days alone; while just the start is picked the calendar shows it
/// and [value] is kept. [GlassDatePickerStyle.wheel] has no range form
/// and is not allowed.
///
/// On the Material path both styles are a button opening
/// `showDateRangePicker`: Material has no inline range calendar.
class GlassDateRangePicker extends StatefulWidget {
  /// Creates a date range picker.
  const GlassDateRangePicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    this.format,
    this.style = GlassDatePickerStyle.compact,
    this.firstDayOfWeek,
    this.mode,
  }) : assert(
         style != GlassDatePickerStyle.wheel,
         'a range has no wheel style',
       );

  /// The selected range; null before one is picked.
  final DateTimeRange? value;

  /// Called with each complete range; null disables the picker.
  final ValueChanged<DateTimeRange>? onChanged;

  /// The earliest date.
  final DateTime firstDate;

  /// The latest date.
  final DateTime lastDate;

  /// Formats one end in the capsule. Defaults to the short month and day
  /// ("Oct 6"), the year after the end ("Oct 6 – Oct 9, 2026").
  final String Function(DateTime date)? format;

  /// How the picker is laid out: [GlassDatePickerStyle.compact] or
  /// [GlassDatePickerStyle.graphical].
  final GlassDatePickerStyle style;

  /// The weekday leading the calendar's rows, 0 (Sunday) to 6
  /// (Saturday); null follows the locale. See
  /// [GlassCalendar.firstDayOfWeek].
  final int? firstDayOfWeek;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassDateRangePicker> createState() => _GlassDateRangePickerState();
}

class _GlassDateRangePickerState extends State<GlassDateRangePicker> {
  bool _open = false;

  /// The start the inline calendar shows while its end is not picked.
  DateTime? _pendingStart;

  MaterialLocalizations get _l10n =>
      Localizations.of<MaterialLocalizations>(context, MaterialLocalizations) ??
      const DefaultMaterialLocalizations();

  bool get _enabled => widget.onChanged != null;

  String _end(DateTime d) =>
      widget.format?.call(d) ?? _l10n.formatShortMonthDay(d);

  String get _text {
    final r = widget.value;
    if (r == null) return _l10n.dateRangePickerHelpText;
    final text = '${_end(r.start)} – ${_end(r.end)}';
    return widget.format == null ? '$text, ${_l10n.formatYear(r.end)}' : text;
  }

  @override
  void didUpdateWidget(GlassDateRangePicker old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) _pendingStart = null;
  }

  Future<void> _show(BuildContext anchor) async {
    setState(() => _open = true);
    final picked = await showGlassDateRangePicker(
      context: context,
      initialRange: widget.value,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      firstDayOfWeek: widget.firstDayOfWeek,
      mode: widget.mode,
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (picked != null) widget.onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? TextButton(
            onPressed: _enabled ? () => _show(context) : null,
            child: Text(_text),
          )
        : switch (widget.style) {
            GlassDatePickerStyle.graphical => _calendar(),
            _ => _Capsule(
              text: _text,
              enabled: _enabled,
              open: _open,
              onTap: _enabled ? _show : null,
            ),
          },
  );

  Widget _calendar() {
    final pending = _pendingStart;
    return IgnorePointer(
      ignoring: !_enabled,
      child: GlassCalendar.range(
        rangeStart: pending ?? widget.value?.start,
        rangeEnd: pending == null ? widget.value?.end : null,
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
        firstDayOfWeek: widget.firstDayOfWeek,
        onRangeChanged: (start, end) {
          if (end == null) {
            setState(() => _pendingStart = start);
            return;
          }
          setState(() => _pendingStart = null);
          widget.onChanged?.call(
            DateTimeRange(
              start: DateUtils.dateOnly(start),
              end: DateUtils.dateOnly(end),
            ),
          );
        },
      ),
    );
  }
}
