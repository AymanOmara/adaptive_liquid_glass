import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../foreground/glass_foreground.dart';
import '../foreground/glass_label_style.dart';
import 'glass_label_layout.dart';
import 'label_metrics.dart';

/// SwiftUI's `Label(_:systemImage:)`: an icon at the start and a title
/// after it, coloured like a vibrant label on glass.
///
/// ```dart
/// GlassLabel.text(text: 'Favourites', icon: CupertinoIcons.heart)
/// ```
///
/// On glass the colour comes from [GlassForeground] (through
/// [GlassLabelStyle]), so the label reads over whatever is behind the
/// glass. A colour the surrounding text style already sets (the app's
/// theme, a prominent button's white) is kept, and a colour the app sets
/// on the `Text` or `Icon` itself still wins. [layout] picks the parts
/// shown; an icon-only label is still named by its title for assistive
/// tech. The Material path uses Material 3's icon size and gap.
class GlassLabel extends StatelessWidget {
  /// Creates a label from widgets.
  const GlassLabel({
    super.key,
    required this.title,
    required this.icon,
    this.layout = GlassLabelLayout.titleAndIcon,
    this.color,
    this.iconSize,
    this.semanticLabel,
    this.mode,
  });

  /// Creates a label from a string and an icon.
  GlassLabel.text({
    super.key,
    required String text,
    required IconData icon,
    this.layout = GlassLabelLayout.titleAndIcon,
    this.color,
    this.iconSize,
    this.semanticLabel,
    this.mode,
  }) : title = Text(text),
       icon = Icon(icon);

  /// The title, after the icon.
  final Widget title;

  /// The icon, at the start.
  final Widget icon;

  /// Which parts show; see [GlassLabelLayout].
  final GlassLabelLayout layout;

  /// The colour for the title and icon; defaults to the surrounding text
  /// colour, else the vibrant label colour for the glass.
  final Color? color;

  /// The icon's size before text scaling; defaults to
  /// [LabelMetrics.iconSize] ([LabelMetrics.materialIconSize] on the
  /// Material path).
  final double? iconSize;

  /// What assistive tech reads; defaults to the visible title (its text
  /// when it is a [Text], also for an icon-only label).
  final String? semanticLabel;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) =>
        _build(context, effective == EffectiveGlassMode.material),
  );

  Widget _build(BuildContext context, bool material) {
    final size = MediaQuery.textScalerOf(context).scale(
      iconSize ??
          (material ? LabelMetrics.materialIconSize : LabelMetrics.iconSize),
    );
    final gap = material ? LabelMetrics.materialIconGap : LabelMetrics.iconGap;
    final showIcon = layout != GlassLabelLayout.titleOnly;
    final showTitle = layout != GlassLabelLayout.iconOnly;

    Widget content = IconTheme.merge(
      data: IconThemeData(size: size),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) icon,
          if (showIcon && showTitle) SizedBox(width: gap),
          if (showTitle) Flexible(child: title),
        ],
      ),
    );

    // The colour: explicit, else the ambient text colour (the app's theme,
    // a prominent button's white), else the vibrant label.
    final ambient = DefaultTextStyle.of(context).style.color;
    final Color? fill =
        color ?? (ambient != null ? null : _vibrant(context, material));
    if (fill != null) content = GlassLabelStyle(color: fill, child: content);

    // One node. An explicit label replaces the title; an icon-only label
    // is still named by its title's text.
    final label = semanticLabel ?? (showTitle ? null : _titleText);
    return MergeSemantics(
      child: Semantics(
        label: label,
        child: ExcludeSemantics(excluding: label != null, child: content),
      ),
    );
  }

  String? get _titleText {
    final t = title;
    return t is Text ? t.data : null;
  }

  Color _vibrant(BuildContext context, bool material) => material
      ? Theme.of(context).colorScheme.onSurface
      : GlassForeground.labelColorOf(context);
}
