import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Card, Theme;

import '../core/effective_glass_mode.dart';
import '../core/glass.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../core/ios_text.dart';
import '../liquid_glass.dart';
import 'group_box_metrics.dart';

/// iOS 26's group box, like SwiftUI's `GroupBox`: an optional bold label
/// above the content, both on a rounded platter.
///
/// ```dart
/// GlassGroupBox(
///   label: const Text('Storage'),
///   labelIcon: const Icon(CupertinoIcons.archivebox),
///   child: const Text('Your storage is almost full.'),
/// )
/// ```
///
/// The platter is iOS's secondarySystemBackground; a group box inside
/// another takes the next level (tertiarySystemBackground), as SwiftUI
/// nests them. Pass [glass] for a Liquid Glass platter over imagery. On
/// the Material path it is a filled Material [Card].
class GlassGroupBox extends StatelessWidget {
  /// Creates a group box.
  const GlassGroupBox({
    super.key,
    required this.child,
    this.label,
    this.labelIcon,
    this.glass,
    this.backgroundColor,
    this.padding,
    this.mode,
  });

  /// The content below the label.
  final Widget child;

  /// The bold title above the content.
  final Widget? label;

  /// An icon before [label], as SwiftUI's `Label`.
  final Widget? labelIcon;

  /// The platter's glass; null draws iOS's opaque grouped colour.
  final Glass? glass;

  /// The platter's colour in place of iOS's (the card's colour on the
  /// Material path). Ignored when [glass] is given.
  final Color? backgroundColor;

  /// The inset around the label and content.
  final EdgeInsetsGeometry? padding;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? _material(context)
        : _glass(context),
  );

  Widget _labelRow(TextStyle style, Color iconColor, double iconSize) =>
      DefaultTextStyle.merge(
        style: style,
        child: labelIcon == null
            ? label!
            : Row(
                children: [
                  IconTheme.merge(
                    data: IconThemeData(color: iconColor, size: iconSize),
                    child: labelIcon!,
                  ),
                  const SizedBox(width: GroupBoxMetrics.labelIconGap),
                  Flexible(child: label!),
                ],
              ),
      );

  double get _labelGap => child is GlassGroupBox
      ? GroupBoxMetrics.nestedLabelGap
      : GroupBoxMetrics.labelGap;

  Widget _glass(BuildContext context) {
    final depth = _GroupBoxDepth.of(context);
    final label = CupertinoDynamicColor.resolve(GlassColors.label, context);
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (this.label != null) ...[
          _labelRow(
            IOSText.style(
              GroupBoxMetrics.labelSize,
              weight: GroupBoxMetrics.labelWeight,
              color: label,
            ),
            CupertinoDynamicColor.resolve(GlassColors.listIcon, context),
            GroupBoxMetrics.labelIconSize,
          ),
          SizedBox(height: _labelGap),
        ],
        DefaultTextStyle.merge(
          style: IOSText.style(GroupBoxMetrics.contentSize, color: label),
          child: child,
        ),
      ],
    );
    final content = _GroupBoxDepth(
      depth: depth + 1,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(GroupBoxMetrics.padding),
        child: body,
      ),
    );
    if (glass != null) {
      return LiquidGlass(
        glass: glass,
        mode: mode,
        shape: const GlassShape.rect(GroupBoxMetrics.cornerRadius),
        child: content,
      );
    }
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: CupertinoDynamicColor.resolve(
          backgroundColor ??
              (depth.isEven
                  ? GlassColors.groupBoxBackground
                  : GlassColors.groupBoxNestedBackground),
          context,
        ),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(GroupBoxMetrics.cornerRadius),
        ),
      ),
      child: content,
    );
  }

  Widget _material(BuildContext context) {
    final theme = Theme.of(context);
    return Card.filled(
      color: backgroundColor,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(GroupBoxMetrics.padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (label != null) ...[
              _labelRow(
                theme.textTheme.titleMedium ?? const TextStyle(),
                theme.colorScheme.primary,
                24,
              ),
              const SizedBox(height: GroupBoxMetrics.labelGap),
            ],
            DefaultTextStyle.merge(
              style: theme.textTheme.bodyMedium,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// How many group boxes enclose this point, so nested boxes alternate.
class _GroupBoxDepth extends InheritedWidget {
  const _GroupBoxDepth({required this.depth, required super.child});

  final int depth;

  static int of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GroupBoxDepth>()?.depth ?? 0;

  @override
  bool updateShouldNotify(_GroupBoxDepth old) => old.depth != depth;
}
