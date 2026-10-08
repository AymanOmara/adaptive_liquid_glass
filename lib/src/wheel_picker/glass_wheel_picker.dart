import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, Theme;
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/effective_glass_mode.dart';
import '../core/glass.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../core/ios_text.dart';
import '../liquid_glass.dart';
import '../picker/glass_picker_item.dart';
import 'wheel_picker_metrics.dart';

/// iOS 26's wheel picker, like SwiftUI's `Picker` with
/// `.pickerStyle(.wheel)`: a drum of choices on a glass surface, the
/// current one under a clear-glass band across the centre.
///
/// ```dart
/// GlassWheelPicker<int>(
///   items: [for (var i = 1; i <= 12; i++) GlassPickerItem(value: i, label: '$i')],
///   selected: hour,
///   onChanged: (h) => setState(() => hour = h),
/// )
/// ```
///
/// Each row passed clicks (`HapticFeedback.selectionClick`). Null
/// [onChanged] disables it. Changing [selected] from outside jumps the
/// wheel there without animation. On the Material path it is a
/// `ListWheelScrollView` on a Material 3 surface with the centre row
/// highlighted.
class GlassWheelPicker<T> extends StatefulWidget {
  /// Creates a wheel picker.
  const GlassWheelPicker({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.itemExtent = WheelPickerMetrics.itemExtent,
    this.height = WheelPickerMetrics.height,
    this.surface = true,
    this.mode,
    this.semanticLabel,
  }) : assert(itemExtent > 0, 'itemExtent must be positive'),
       assert(height > 0, 'height must be positive');

  /// The choices, top to bottom.
  final List<GlassPickerItem<T>> items;

  /// The current choice's value.
  final T selected;

  /// Called with the chosen value as each row passes the centre; null
  /// disables the picker.
  final ValueChanged<T>? onChanged;

  /// A row's height (iOS's default: 32 pt).
  final double itemExtent;

  /// The wheel's height (iOS's default: 216 pt).
  final double height;

  /// Whether the wheel draws its own glass (or Material) surface and
  /// selection band. False draws the drum alone, for a parent composing
  /// several columns on one surface, as `GlassDatePicker`'s wheel style
  /// does.
  final bool surface;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// What assistive tech reads for the picker (say, "Hour"); the current
  /// choice is always its value.
  final String? semanticLabel;

  @override
  State<GlassWheelPicker<T>> createState() => _GlassWheelPickerState<T>();
}

class _GlassWheelPickerState<T> extends State<GlassWheelPicker<T>> {
  late final FixedExtentScrollController _controller;

  /// The row the wheel last reported, so a parent echoing [onChanged]
  /// back as [GlassWheelPicker.selected] does not jump a settling wheel.
  late int _reported;

  bool get _enabled => widget.onChanged != null;

  int get _index {
    final i = widget.items.indexWhere((e) => e.value == widget.selected);
    return i < 0 ? 0 : i;
  }

  String _labelAt(int i) =>
      i < 0 || i >= widget.items.length ? '' : widget.items[i].label;

  @override
  void initState() {
    super.initState();
    _reported = _index;
    _controller = FixedExtentScrollController(initialItem: _reported);
  }

  @override
  void didUpdateWidget(GlassWheelPicker<T> old) {
    super.didUpdateWidget(old);
    final index = _index;
    if (index == _reported) return;
    _reported = index;
    if (_controller.hasClients) _controller.jumpToItem(index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(int i) {
    if (i == _reported) return;
    _reported = i;
    HapticFeedback.selectionClick();
    widget.onChanged?.call(widget.items[i].value);
  }

  void _step(int direction) {
    final i = (_reported + direction).clamp(0, widget.items.length - 1);
    if (i == _reported || !_controller.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToItem(i);
    } else {
      _controller.animateToItem(
        i,
        duration: WheelPickerMetrics.stepDuration,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, effective) => _semantics(
      _sized(
        effective == EffectiveGlassMode.material
            ? _material(context)
            : _glass(context),
      ),
    ),
  );

  /// iOS's default width unless the parent constrains it (a tight width
  /// stretches it). A surfaceless wheel never sets one: the parent
  /// composing the columns does.
  Widget _sized(Widget child) => widget.surface
      ? SizedBox(
          width: WheelPickerMetrics.width,
          height: widget.height,
          child: child,
        )
      : SizedBox(height: widget.height, child: child);

  Widget _semantics(Widget child) {
    final last = widget.items.length - 1;
    return Semantics(
      container: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      value: _labelAt(_reported),
      increasedValue: _enabled && _reported < last
          ? _labelAt(_reported + 1)
          : null,
      decreasedValue: _enabled && _reported > 0
          ? _labelAt(_reported - 1)
          : null,
      onIncrease: _enabled && _reported < last ? () => _step(1) : null,
      onDecrease: _enabled && _reported > 0 ? () => _step(-1) : null,
      excludeSemantics: true,
      child: child,
    );
  }

  Widget _wheel(TextStyle style) => IgnorePointer(
    ignoring: !_enabled,
    child: ListWheelScrollView.useDelegate(
      controller: _controller,
      itemExtent: widget.itemExtent,
      physics: const FixedExtentScrollPhysics(),
      diameterRatio: WheelPickerMetrics.diameterRatio,
      squeeze: WheelPickerMetrics.squeeze,
      perspective: WheelPickerMetrics.perspective,
      overAndUnderCenterOpacity: WheelPickerMetrics.offCenterOpacity,
      onSelectedItemChanged: _changed,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: widget.items.length,
        builder: (context, i) => Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: WheelPickerMetrics.rowPadding,
          ),
          child: Center(
            child: Text(
              widget.items[i].label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ),
      ),
    ),
  );

  /// The selection band across the centre, under the rows.
  Widget _band(Widget band) => Align(
    child: Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: WheelPickerMetrics.bandInset,
      ),
      child: SizedBox(
        height: widget.itemExtent,
        width: double.infinity,
        child: IgnorePointer(child: ExcludeSemantics(child: band)),
      ),
    ),
  );

  Widget _glass(BuildContext context) {
    final colour = CupertinoDynamicColor.resolve(
      _enabled ? GlassColors.label : GlassColors.tertiaryLabel,
      context,
    );
    final wheel = _wheel(
      IOSText.style(WheelPickerMetrics.fontSize, color: colour),
    );
    if (!widget.surface) return wheel;
    return LiquidGlass(
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
          wheel,
        ],
      ),
    );
  }

  Widget _material(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colour = _enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.38);
    final style = (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
      color: colour,
    );
    final wheel = _wheel(style);
    if (!widget.surface) return wheel;
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
          wheel,
        ],
      ),
    );
  }
}
