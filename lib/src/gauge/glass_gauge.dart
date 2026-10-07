import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show CircularProgressIndicator, LinearProgressIndicator, Theme;

import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_system_colors.dart';
import '../core/ios_text.dart';
import 'gauge_arc_painter.dart';
import 'gauge_linear_painter.dart';
import 'gauge_metrics.dart';
import 'gauge_ring_painter.dart';
import 'glass_gauge_style.dart';

/// iOS 26's gauge, like SwiftUI's `Gauge`: a capsule track filled to
/// the value, or a circular ring with the value marked or filled in.
///
/// ```dart
/// GlassGauge(
///   value: 0.62,
///   label: const Text('Battery'),
///   currentValueLabel: const Text('62%'),
///   minimumValueLabel: const Text('0'),
///   maximumValueLabel: const Text('100'),
/// )
/// GlassGauge(
///   value: 21, min: 0, max: 40,
///   style: GlassGaugeStyle.accessoryCircular,
///   currentValueLabel: const Text('21°'),
///   tint: GlassSystemColors.orange,
/// )
/// ```
///
/// The value does not animate; SwiftUI's gauges do not either. On the
/// Material path it is a Material 3 [LinearProgressIndicator] or
/// [CircularProgressIndicator] with the labels around it.
class GlassGauge extends StatelessWidget {
  /// Creates a gauge.
  const GlassGauge({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 1,
    this.style = GlassGaugeStyle.linearCapacity,
    this.label,
    this.currentValueLabel,
    this.minimumValueLabel,
    this.maximumValueLabel,
    this.tint,
    this.semanticLabel,
    this.mode,
  }) : assert(min < max, 'min must be less than max');

  /// The measured value, clamped into [min] and [max].
  final double value;

  /// The least value.
  final double min;

  /// The greatest value.
  final double max;

  /// Which form the gauge draws.
  final GlassGaugeStyle style;

  /// The gauge's title: above the linear track, in the accessory
  /// ring's bottom gap when there are no min/max labels, and read to
  /// assistive tech only in the capacity ring.
  final Widget? label;

  /// The value, below the linear track or centred in a ring.
  final Widget? currentValueLabel;

  /// The [min], at the track's start or under the accessory ring's
  /// start end.
  final Widget? minimumValueLabel;

  /// The [max], at the track's end or under the accessory ring's end.
  final Widget? maximumValueLabel;

  /// The fill's colour; defaults to iOS's blue on the linear gauge and
  /// the label colour on the rings, like SwiftUI.
  final Color? tint;

  /// What assistive tech reads; defaults to [label]'s text.
  final String? semanticLabel;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// The value's share of the range, 0 to 1.
  double get fraction => ((value - min) / (max - min)).clamp(0.0, 1.0);

  String? get _semanticsLabel =>
      semanticLabel ?? (label is Text ? (label as Text).data : null);

  String get _semanticsValue => '${(fraction * 100).round()}%';

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? _material(context)
        : _glass(context),
  );

  /// The fill's colour: the tint, or SwiftUI's defaults (the accent for
  /// the linear gauge, the label colour for the accessory rings).
  Color _tint(BuildContext context) => CupertinoDynamicColor.resolve(
    tint ??
        (style == GlassGaugeStyle.linearCapacity
            ? GlassSystemColors.blue
            : CupertinoColors.label),
    context,
  );

  Widget _glass(BuildContext context) => Semantics(
    label: _semanticsLabel,
    value: _semanticsValue,
    readOnly: true,
    child: ExcludeSemantics(
      child: switch (style) {
        GlassGaugeStyle.linearCapacity => _linear(context),
        GlassGaugeStyle.accessoryCircular => _accessoryCircular(context),
        GlassGaugeStyle.accessoryCircularCapacity => _capacityCircular(context),
      },
    ),
  );

  /// The label colour, as SwiftUI draws every gauge text.
  Color _labelColor(BuildContext context) =>
      CupertinoDynamicColor.resolve(CupertinoColors.label, context);

  Widget _linear(BuildContext context) {
    final title = label;
    final current = currentValueLabel;
    final minimum = minimumValueLabel;
    final maximum = maximumValueLabel;
    // SwiftUI centres the label and the value over and under the track.
    return DefaultTextStyle.merge(
      style: IOSText.style(GaugeMetrics.labelSize, color: _labelColor(context)),
      textAlign: TextAlign.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Center(child: title),
            const SizedBox(height: GaugeMetrics.linearLabelGap),
          ],
          Row(
            children: [
              if (minimum != null) ...[
                minimum,
                const SizedBox(width: GaugeMetrics.minMaxGap),
              ],
              Expanded(
                child: SizedBox(
                  height: GaugeMetrics.linearTrackHeight,
                  child: CustomPaint(
                    painter: GaugeLinearPainter(
                      fraction: fraction,
                      color: _tint(context),
                      track: CupertinoDynamicColor.resolve(
                        CupertinoColors.tertiarySystemFill,
                        context,
                      ),
                      rtl: Directionality.of(context) == TextDirection.rtl,
                    ),
                  ),
                ),
              ),
              if (maximum != null) ...[
                const SizedBox(width: GaugeMetrics.minMaxGap),
                maximum,
              ],
            ],
          ),
          if (current != null) ...[
            const SizedBox(height: GaugeMetrics.linearValueGap),
            Center(child: current),
          ],
        ],
      ),
    );
  }

  Widget _accessoryCircular(BuildContext context) {
    final minimum = minimumValueLabel;
    final maximum = maximumValueLabel;
    final title = label;
    final current = currentValueLabel;
    // The min and max centre as a pair under the gap; with neither, the
    // label takes the gap itself.
    final Widget? ends = minimum != null || maximum != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?minimum,
              if (minimum != null && maximum != null)
                const SizedBox(width: GaugeMetrics.circularEndLabelGap),
              ?maximum,
            ],
          )
        : title;
    return SizedBox.square(
      dimension: GaugeMetrics.circularDiameter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: GaugeArcPainter(
                fraction: fraction,
                color: _tint(context),
                stroke: GaugeMetrics.circularStroke,
                rtl: Directionality.of(context) == TextDirection.rtl,
              ),
            ),
          ),
          if (current != null)
            Positioned.fill(
              bottom: GaugeMetrics.circularValueLift * 2,
              child: Center(child: _valueLabel(context, current)),
            ),
          if (ends != null)
            PositionedDirectional(
              bottom: GaugeMetrics.circularEndLabelBottom,
              start: 0,
              end: 0,
              child: Center(child: _endLabel(context, ends)),
            ),
        ],
      ),
    );
  }

  Widget _capacityCircular(BuildContext context) {
    final tint = _tint(context);
    final current = currentValueLabel;
    return SizedBox.square(
      dimension: GaugeMetrics.circularDiameter,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: GaugeRingPainter(
                fraction: fraction,
                color: tint,
                track: tint.withValues(
                  alpha: tint.a * GaugeMetrics.circularTrackOpacity,
                ),
                stroke: GaugeMetrics.circularStroke,
                rtl: Directionality.of(context) == TextDirection.rtl,
              ),
            ),
          ),
          if (current != null)
            Positioned.fill(
              child: Center(child: _valueLabel(context, current)),
            ),
        ],
      ),
    );
  }

  Widget _valueLabel(BuildContext context, Widget child) =>
      DefaultTextStyle.merge(
        style: IOSText.style(
          GaugeMetrics.circularValueSize,
          weight: GaugeMetrics.circularValueWeight,
          color: _labelColor(context),
        ),
        maxLines: 1,
        child: child,
      );

  Widget _endLabel(BuildContext context, Widget child) =>
      DefaultTextStyle.merge(
        style: IOSText.style(
          GaugeMetrics.circularEndLabelSize,
          color: _labelColor(context),
        ),
        maxLines: 1,
        child: child,
      );

  Widget _material(BuildContext context) {
    final theme = Theme.of(context);
    final colour = tint ?? theme.colorScheme.primary;
    final text = theme.textTheme;
    final title = label;
    final current = currentValueLabel;
    final minimum = minimumValueLabel;
    final maximum = maximumValueLabel;
    if (style == GlassGaugeStyle.linearCapacity) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DefaultTextStyle.merge(
                style: text.bodyLarge,
                child: title,
              ),
            ),
            const SizedBox(height: GaugeMetrics.linearLabelGap),
          ],
          Row(
            children: [
              if (minimum != null) ...[
                DefaultTextStyle.merge(style: text.bodySmall, child: minimum),
                const SizedBox(width: GaugeMetrics.minMaxGap),
              ],
              Expanded(
                child: LinearProgressIndicator(
                  value: fraction,
                  color: colour,
                  borderRadius: BorderRadius.circular(
                    GaugeMetrics.materialTrackRadius,
                  ),
                  semanticsLabel: _semanticsLabel,
                  semanticsValue: _semanticsValue,
                ),
              ),
              if (maximum != null) ...[
                const SizedBox(width: GaugeMetrics.minMaxGap),
                DefaultTextStyle.merge(style: text.bodySmall, child: maximum),
              ],
            ],
          ),
          if (current != null) ...[
            const SizedBox(height: GaugeMetrics.linearValueGap),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DefaultTextStyle.merge(
                style: text.bodyMedium,
                child: current,
              ),
            ),
          ],
        ],
      );
    }
    return SizedBox.square(
      dimension: GaugeMetrics.circularDiameter,
      child: Stack(
        children: [
          Positioned.fill(
            child: CircularProgressIndicator(
              value: fraction,
              strokeWidth: GaugeMetrics.circularStroke,
              color: colour,
              backgroundColor: colour.withValues(
                alpha: GaugeMetrics.circularTrackOpacity,
              ),
              semanticsLabel: _semanticsLabel,
              semanticsValue: _semanticsValue,
            ),
          ),
          if (current != null)
            Positioned.fill(
              child: Center(
                child: DefaultTextStyle.merge(
                  style: text.bodyMedium,
                  child: current,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
