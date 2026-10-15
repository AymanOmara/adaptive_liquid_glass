import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show DateUtils, MaterialLocalizations, showDatePicker;

import '../button/glass_button.dart';
import '../button/glass_button_metrics_scope.dart';
import '../button/glass_button_shape.dart';
import '../button/glass_button_style.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_render_mode.dart';
import '../core/ios_text.dart';
import '../core/liquid_glass_theme.dart';
import '../core/render_mode_resolver.dart';
import '../platform/glass_platform.dart';
import '../sheet/show_glass_sheet.dart';
import '../toolbar/toolbar_metrics.dart';
import 'date_picker_metrics.dart';
import 'glass_calendar.dart';
import 'glass_date_picker_mode.dart';
import 'glass_date_picker_style.dart';
import 'glass_date_wheel.dart';

/// Asks for a date and completes with it, or with null when the picker
/// is dismissed: the glass counterpart of Material's [showDatePicker].
///
/// ```dart
/// final date = await showGlassDatePicker(
///   context,
///   initialDate: DateTime.now(),
///   firstDate: DateTime(2020),
///   lastDate: DateTime(2030),
/// );
/// ```
///
/// On the glass path it is an iOS 26 sheet sized to its content, like a
/// SwiftUI `DatePicker` presented with `.sheet`: an xmark close button
/// leading the header, [helpText] as its title, and below them the
/// [GlassCalendar] ([GlassDatePickerStyle.graphical], the default; also
/// [GlassDatePickerStyle.compact], which has no capsule to show here) or
/// the [GlassDateWheel] ([GlassDatePickerStyle.wheel]). Picking a day in
/// the calendar completes at once, as the compact picker's calendar
/// closes on a pick; the wheels settle on every turn, so they add a
/// prominent checkmark (Done) that completes with their value. The close
/// button, a tap outside or a drag down complete with null.
///
/// [firstDayOfWeek] (0 for Sunday to 6 for Saturday, as
/// `MaterialLocalizations.firstDayOfWeekIndex` counts; null follows the
/// locale) and [showWeekNumbers] shape the calendar. [locale] overrides
/// the app's locale for the picker; [helpText] titles it. [cancelText]
/// and [confirmText] are what assistive tech reads for the close button
/// ("Close" by default) and the checkmark ("Done").
///
/// On the Material path it is [showDatePicker] with the same dates,
/// labels and [locale], whatever the [style]. Material's calendar has
/// no first-day setting, so there [firstDayOfWeek] does not apply and the
/// locale decides. The date completes without a time on both paths.
Future<DateTime?> showGlassDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  GlassDatePickerStyle style = GlassDatePickerStyle.graphical,
  int? firstDayOfWeek,
  bool showWeekNumbers = false,
  String? helpText,
  String? cancelText,
  String? confirmText,
  Locale? locale,
  GlassRenderMode? mode,
}) async {
  assert(!lastDate.isBefore(firstDate), 'lastDate must not precede firstDate');
  assert(
    !DateUtils.dateOnly(initialDate).isBefore(DateUtils.dateOnly(firstDate)) &&
        !DateUtils.dateOnly(initialDate).isAfter(DateUtils.dateOnly(lastDate)),
    'initialDate must lie between firstDate and lastDate',
  );
  assert(
    firstDayOfWeek == null || (firstDayOfWeek >= 0 && firstDayOfWeek < 7),
    'firstDayOfWeek is 0 (Sunday) to 6 (Saturday)',
  );
  final effective = resolveGlassMode(
    requested: mode ?? LiquidGlassTheme.of(context).defaultMode,
    environment: GlassPlatform.instance.environment.value,
    highContrast: MediaQuery.highContrastOf(context),
    supportLiquidGlassOnAndroid: LiquidGlassTheme.of(
      context,
    ).supportLiquidGlassOnAndroid,
  );
  if (effective == EffectiveGlassMode.material) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
      cancelText: cancelText,
      confirmText: confirmText,
      locale: locale,
    );
  }
  final picked = await showGlassSheet<DateTime>(
    context: context,
    mode: mode,
    builder: (context) {
      final sheet = _DatePickerSheet(
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        wheel: style == GlassDatePickerStyle.wheel,
        firstDayOfWeek: firstDayOfWeek,
        showWeekNumbers: showWeekNumbers,
        helpText: helpText,
        cancelText: cancelText,
        confirmText: confirmText,
        mode: mode,
      );
      return locale == null
          ? sheet
          : Localizations.override(
              context: context,
              locale: locale,
              child: sheet,
            );
    },
  );
  return picked == null ? null : DateUtils.dateOnly(picked);
}

/// The glass date picker sheet's content: the header and the calendar or
/// wheels.
class _DatePickerSheet extends StatefulWidget {
  const _DatePickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.wheel,
    required this.firstDayOfWeek,
    required this.showWeekNumbers,
    required this.helpText,
    required this.cancelText,
    required this.confirmText,
    required this.mode,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool wheel;
  final int? firstDayOfWeek;
  final bool showWeekNumbers;
  final String? helpText;
  final String? cancelText;
  final String? confirmText;
  final GlassRenderMode? mode;

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late DateTime _value = widget.initialDate;

  MaterialLocalizations? get _l10n =>
      Localizations.of<MaterialLocalizations>(context, MaterialLocalizations);

  Widget _button({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    GlassButtonStyle style = GlassButtonStyle.glass,
  }) => GlassButtonMetricsScope(
    metrics: ToolbarMetrics.single,
    child: GlassButton.icon(
      onPressed: onPressed,
      icon: icon,
      style: style,
      shape: GlassButtonShape.circle,
      mode: widget.mode,
      semanticLabel: label,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final close = _button(
      icon: CupertinoIcons.xmark,
      label: widget.cancelText ?? _l10n?.closeButtonLabel ?? 'Close',
      onPressed: () => Navigator.of(context).pop(),
    );
    // Without a Done button an empty circle's width keeps the title
    // centred.
    final done = widget.wheel
        ? _button(
            icon: CupertinoIcons.checkmark,
            label: widget.confirmText ?? 'Done',
            style: GlassButtonStyle.glassProminent,
            onPressed: () => Navigator.of(context).pop(_value),
          )
        : const SizedBox(width: ToolbarMetrics.height);
    final title = widget.helpText;
    return Padding(
      padding: const EdgeInsetsDirectional.all(DatePickerMetrics.sheetPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              close,
              Expanded(
                child: title == null
                    ? const SizedBox()
                    : Semantics(
                        header: true,
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: IOSText.style(
                            DatePickerMetrics.headerFontSize,
                            weight: FontWeight.w600,
                            color: CupertinoDynamicColor.resolve(
                              GlassColors.label,
                              context,
                            ),
                          ),
                        ),
                      ),
              ),
              done,
            ],
          ),
          Center(
            child: widget.wheel
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: DatePickerMetrics.sheetPadding,
                    ),
                    child: GlassDateWheel(
                      value: _value,
                      firstDate: widget.firstDate,
                      lastDate: widget.lastDate,
                      pickerMode: GlassDatePickerMode.date,
                      mode: widget.mode,
                      onChanged: (d) => setState(() => _value = d),
                    ),
                  )
                : GlassCalendar(
                    selected: widget.initialDate,
                    firstDate: widget.firstDate,
                    lastDate: widget.lastDate,
                    firstDayOfWeek: widget.firstDayOfWeek,
                    showWeekNumbers: widget.showWeekNumbers,
                    onSelected: (d) => Navigator.of(context).pop(d),
                  ),
          ),
        ],
      ),
    );
  }
}
