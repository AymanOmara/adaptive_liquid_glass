import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        DefaultMaterialLocalizations,
        MaterialLocalizations,
        TextButton,
        showDatePicker;

import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_system_colors.dart';
import '../core/ios_text.dart';
import '../popover/show_glass_popover.dart';
import 'date_picker_metrics.dart';
import 'glass_calendar.dart';

/// iOS 26's compact date picker, like SwiftUI's `DatePicker` with
/// `.datePickerStyle(.compact)` for a date: the date in a grey capsule,
/// opening a glass calendar popover.
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
/// The date reads in the app's locale ([format] overrides it); while the
/// calendar is open it is blue. Picking a day closes the calendar. On the
/// Material path it is a text button opening [showDatePicker].
class GlassDatePicker extends StatefulWidget {
  /// Creates a date picker.
  const GlassDatePicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    this.format,
    this.mode,
  });

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

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassDatePicker> createState() => _GlassDatePickerState();
}

class _GlassDatePickerState extends State<GlassDatePicker> {
  bool _open = false;

  MaterialLocalizations get _l10n =>
      Localizations.of<MaterialLocalizations>(context, MaterialLocalizations) ??
      const DefaultMaterialLocalizations();

  String get _text =>
      widget.format?.call(widget.value) ??
      '${_l10n.formatShortMonthDay(widget.value)}, '
          '${_l10n.formatYear(widget.value)}';

  Future<void> _show(BuildContext anchor) async {
    setState(() => _open = true);
    final picked = await showGlassPopover<DateTime>(
      context: anchor,
      mode: widget.mode,
      builder: (context) => GlassCalendar(
        selected: widget.value,
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
        onSelected: (d) => Navigator.of(context).pop(d),
      ),
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (picked != null) widget.onChanged?.call(picked);
  }

  Future<void> _material() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.value,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    if (picked != null) widget.onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? TextButton(
            onPressed: widget.onChanged == null ? null : _material,
            child: Text(_text),
          )
        : _glass(),
  );

  Widget _glass() {
    final enabled = widget.onChanged != null;
    final colour = CupertinoDynamicColor.resolve(
      !enabled
          ? CupertinoColors.tertiaryLabel
          : _open
          ? GlassSystemColors.blue
          : CupertinoColors.label,
      context,
    );
    return Builder(
      builder: (anchor) => Semantics(
        button: true,
        enabled: enabled,
        value: _text,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => _show(anchor) : null,
          child: Container(
            height: DatePickerMetrics.height,
            padding: const EdgeInsets.symmetric(
              horizontal: DatePickerMetrics.padding,
            ),
            // No alignment: the capsule hugs the date.
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
                _text,
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
