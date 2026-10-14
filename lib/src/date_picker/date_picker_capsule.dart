part of 'glass_date_picker.dart';

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
            // The capsule grows with Dynamic Type (never below its height).
            height:
                DatePickerMetrics.height *
                IOSText.growth(
                  MediaQuery.textScalerOf(context),
                  DatePickerMetrics.fontSize,
                ),
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
                overflow: TextOverflow.ellipsis,
                style: IOSText.style(DatePickerMetrics.fontSize, color: colour),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
