import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Card, Divider, Theme;

import '../core/effective_glass_mode.dart';
import '../core/glass.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../core/ios_text.dart';
import '../liquid_glass.dart';
import 'glass_list_tile.dart';
import 'list_metrics.dart';
import 'list_section_scope.dart';

/// iOS 26's inset-grouped list, like Settings: rows on a rounded platter
/// with hairline separators and optional header and footer.
///
/// ```dart
/// GlassListSection(
///   header: const Text('General'),
///   children: [
///     GlassListTile(
///       leading: const Icon(CupertinoIcons.wifi),
///       title: const Text('Wi-Fi'),
///       trailing: GlassToggle(value: wifi, onChanged: setWifi),
///     ),
///     GlassListTile(
///       title: const Text('About'),
///       value: 'iOS 26.4',
///       chevron: true,
///       onTap: openAbout,
///     ),
///     GlassListTile(title: const Text('Storage'), chevron: true),
///   ],
/// )
/// ```
///
/// iOS 26 Settings draws opaque cells (secondarySystemGroupedBackground) on
/// systemGroupedBackground, which is the default here too; pass
/// `glass: Glass.regular` for a Liquid Glass platter over imagery. On the
/// Material path it is a Material 3 filled [Card] of ListTiles.
class GlassListSection extends StatelessWidget {
  /// Creates a list section.
  const GlassListSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.glass,
    this.margin = const EdgeInsetsDirectional.symmetric(
      horizontal: ListMetrics.margin,
    ),
    this.mode,
  });

  /// The rows, usually [GlassListTile]s.
  final List<Widget> children;

  /// Small text above the platter.
  final Widget? header;

  /// Small text below the platter.
  final Widget? footer;

  /// The platter's glass; null draws iOS's opaque grouped cell (the
  /// default, as iOS 26 Settings).
  final Glass? glass;

  /// The platter's inset from the screen's sides.
  final EdgeInsetsGeometry margin;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? _material(context)
        : _glass(context),
  );

  /// The children with [separator] inserted after each but the last.
  List<Widget> _separated(Widget Function(Widget above) separator) => [
    for (var i = 0; i < children.length; i++) ...[
      children[i],
      if (i < children.length - 1) separator(children[i]),
    ],
  ];

  Widget _glass(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(ListMetrics.cornerRadius),
      child: ListSectionScope(
        mode: mode,
        glass: glass != null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _separated(
            (above) => Padding(
              padding: EdgeInsetsDirectional.only(
                start: above is GlassListTile && above.leading != null
                    ? ListMetrics.textStart
                    : ListMetrics.horizontalPadding,
              ),
              child: SizedBox(
                height: ListMetrics.separatorThickness,
                child: ColoredBox(
                  color: CupertinoDynamicColor.resolve(
                    CupertinoColors.separator,
                    context,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final platter = glass == null
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.secondarySystemGroupedBackground,
                context,
              ),
              borderRadius: BorderRadius.circular(ListMetrics.cornerRadius),
            ),
            child: content,
          )
        : LiquidGlass(
            glass: glass,
            mode: mode,
            shape: const GlassShape.rect(ListMetrics.cornerRadius),
            child: content,
          );
    final caption = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: ListMetrics.horizontalPadding,
                end: ListMetrics.horizontalPadding,
                bottom: ListMetrics.headerGap,
              ),
              child: DefaultTextStyle.merge(
                style: IOSText.style(ListMetrics.headerSize, color: caption),
                child: header!,
              ),
            ),
          platter,
          if (footer != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: ListMetrics.horizontalPadding,
                end: ListMetrics.horizontalPadding,
                top: ListMetrics.headerGap,
              ),
              child: DefaultTextStyle.merge(
                style: IOSText.style(ListMetrics.footerSize, color: caption),
                child: footer!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _material(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: ListMetrics.materialInset,
                end: ListMetrics.materialInset,
                bottom: ListMetrics.materialGap,
              ),
              child: DefaultTextStyle.merge(
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
                child: header!,
              ),
            ),
          Card.filled(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ListSectionScope(
              mode: mode,
              glass: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _separated(
                  (above) => Divider(
                    height: 1,
                    indent: above is GlassListTile && above.leading != null
                        ? ListMetrics.materialLeadingInset
                        : ListMetrics.materialInset,
                  ),
                ),
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: ListMetrics.materialInset,
                end: ListMetrics.materialInset,
                top: ListMetrics.materialGap,
              ),
              child: DefaultTextStyle.merge(
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                child: footer!,
              ),
            ),
        ],
      ),
    );
  }
}
