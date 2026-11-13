import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider, Material, Theme;

import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/ios_text.dart';
import '../disclosure/disclosure_separator_scope.dart';
import '../disclosure/glass_disclosure_group.dart';
import 'list_leading.dart';
import 'list_metrics.dart';
import 'list_section_scope.dart';
import 'plain_list_metrics.dart';

/// iOS 26's plain list, like SwiftUI's `List` with `.listStyle(.plain)`
/// (Mail's mailbox list): full-width rows on the page background, a
/// hairline under every row, and section headers that stick to the top
/// while their section scrolls under them.
///
/// ```dart
/// GlassPlainList(
///   sections: [
///     GlassPlainListSection(
///       header: const Text('Mailboxes'),
///       children: [
///         for (final box in boxes)
///           GlassSwipeActions(
///             key: ValueKey(box),
///             trailing: [
///               GlassSwipeAction(
///                 icon: CupertinoIcons.trash,
///                 label: 'Delete',
///                 color: GlassSystemColors.red,
///                 destructive: true,
///                 onPressed: () => delete(box),
///               ),
///             ],
///             child: GlassListTile(title: Text(box), onTap: () => open(box)),
///           ),
///       ],
///     ),
///     GlassPlainListSection(
///       header: const Text('More'),
///       children: [
///         GlassListTile(
///           leading: const Icon(CupertinoIcons.star),
///           title: const Text('Favourites'),
///         ),
///       ],
///     ),
///   ],
/// )
/// ```
///
/// Rows are usually [GlassListTile]s, each optionally in a
/// `GlassSwipeActions`; the hairline under a row starts under its title
/// (56 pt in after a leading, else 16 pt) and stops 16 pt before the end,
/// as SwiftUI's (`PlainListMetrics`). Headers pin below the top safe
/// area (a navigation bar's bottom, under one) while the rows scroll
/// beneath them; [stickyHeaders] turns that off. On the Material path
/// it is a list of ListTiles with dividers and Material subheaders.
class GlassPlainList extends StatelessWidget {
  /// Creates a plain list.
  const GlassPlainList({
    super.key,
    required this.sections,
    this.controller,
    this.padding,
    this.backgroundColor,
    this.separatorColor,
    this.stickyHeaders = true,
    this.physics,
    this.primary,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.mode,
  });

  /// The list's sections, usually [GlassPlainListSection]s; any sliver
  /// works.
  final List<Widget> sections;

  /// The list's scroll controller.
  final ScrollController? controller;

  /// Space around the sections; the view's safe area is added to it. The
  /// headers stick below the top safe area plus this top inset.
  final EdgeInsetsGeometry? padding;

  /// The page colour in place of iOS's systemBackground (the Material
  /// theme's surface on the Material path); pinned headers take it too.
  final Color? backgroundColor;

  /// The hairlines between rows (the Material dividers) in place of iOS's
  /// plain-list separator colour.
  final Color? separatorColor;

  /// Whether section headers stick to the top while their section
  /// scrolls under them, as SwiftUI's do.
  final bool stickyHeaders;

  /// The scroll physics.
  final ScrollPhysics? physics;

  /// Whether this is the primary scroll view (see [ScrollView.primary]).
  final bool? primary;

  /// Whether dragging the list dismisses the keyboard.
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// The rendering path; see [GlassRenderMode]. Sections and rows below
  /// that set none take it.
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) {
      final material = effective == EffectiveGlassMode.material;
      final background =
          backgroundColor ??
          (material
              ? Theme.of(context).colorScheme.surface
              : CupertinoDynamicColor.resolve(
                  GlassColors.plainListBackground,
                  context,
                ));
      final media = MediaQuery.of(context);
      final insets = (padding ?? EdgeInsets.zero).resolve(
        Directionality.of(context),
      );
      final bottom = media.viewInsets.bottom > media.padding.bottom
          ? media.viewInsets.bottom
          : media.padding.bottom;
      final scope = PlainListScope(
        background: background,
        separatorColor: separatorColor,
        sticky: stickyHeaders,
        mode: mode,
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          child: CustomScrollView(
            controller: controller,
            primary: primary,
            physics: physics,
            keyboardDismissBehavior: keyboardDismissBehavior,
            slivers: [
              // A clear pinned band over the top safe area: the headers
              // pin below it (they stack under pinned slivers above)
              // while the rows scroll on under it.
              PinnedHeaderSliver(
                child: SizedBox(height: media.padding.top + insets.top),
              ),
              SliverPadding(
                padding: EdgeInsets.only(
                  left: insets.left + media.padding.left,
                  right: insets.right + media.padding.right,
                  bottom: insets.bottom + bottom,
                ),
                sliver: SliverMainAxisGroup(slivers: sections),
              ),
            ],
          ),
        ),
      );
      // ListTiles paint their ink on the nearest Material.
      return material
          ? Material(color: background, child: scope)
          : ColoredBox(color: background, child: scope);
    },
  );
}

/// One section of a [GlassPlainList]: an optional sticky [header] above
/// full-width rows, each with a hairline below it. It is a sliver, so it
/// also works in a `CustomScrollView` of your own.
class GlassPlainListSection extends StatelessWidget {
  /// Creates a plain-list section.
  const GlassPlainListSection({
    super.key,
    required this.children,
    this.header,
    this.separatorColor,
    this.mode,
  });

  /// The rows, usually [GlassListTile]s, each optionally in a
  /// `GlassSwipeActions`.
  final List<Widget> children;

  /// The section's header (sentence case, as SwiftUI's).
  final Widget? header;

  /// The hairlines in place of the list's colour.
  final Color? separatorColor;

  /// The rendering path; see [GlassRenderMode]. Null takes the list's.
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) {
    final scope = PlainListScope.maybeOf(context);
    final mode = this.mode ?? scope?.mode;
    return GlassModeBuilder(
      mode: mode,
      builder: (context, effective) {
        final material = effective == EffectiveGlassMode.material;
        final separator = separatorColor ?? scope?.separatorColor;
        final rows = ListSectionScope(
          mode: mode,
          glass: false,
          separatorColor:
              separator ?? (material ? null : GlassColors.plainListSeparator),
          child: SliverList(
            delegate: SliverChildListDelegate([
              for (var i = 0; i < children.length; i++)
                material
                    ? _materialRow(context, i, separator)
                    : _glassRow(context, children[i], separator),
            ]),
          ),
        );
        if (header == null) return rows;
        final headerBox = material
            ? _materialHeader(context, scope)
            : _glassHeader(context, scope);
        return SliverMainAxisGroup(
          slivers: [
            if (scope?.sticky ?? true)
              PinnedHeaderSliver(child: headerBox)
            else
              SliverToBoxAdapter(child: headerBox),
            rows,
          ],
        );
      },
    );
  }

  Widget _glassRow(BuildContext context, Widget row, Color? separator) {
    // The group's last visible row varies, so it draws its own hairline.
    if (row is GlassDisclosureGroup) {
      return DisclosureSeparatorScope(child: row);
    }
    final color = CupertinoDynamicColor.resolve(
      separator ?? GlassColors.plainListSeparator,
      context,
    );
    return Stack(
      children: [
        row,
        // The hairline overlays the row's bottom edge, adding no height.
        PositionedDirectional(
          start: hasLeading(row)
              ? ListMetrics.textStart
              : PlainListMetrics.separatorStart,
          end: PlainListMetrics.separatorEnd,
          bottom: 0,
          height: ListMetrics.separatorThickness,
          child: ColoredBox(color: color),
        ),
      ],
    );
  }

  Widget _glassHeader(BuildContext context, PlainListScope? scope) =>
      ColoredBox(
        color:
            scope?.background ??
            CupertinoDynamicColor.resolve(
              GlassColors.plainListBackground,
              context,
            ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: ListMetrics.horizontalPadding,
            end: ListMetrics.horizontalPadding,
            top: PlainListMetrics.headerTopPadding,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: PlainListMetrics.headerHeight,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 1,
              child: Semantics(
                header: true,
                child: DefaultTextStyle.merge(
                  style: IOSText.style(
                    ListMetrics.headerSize,
                    weight: ListMetrics.headerWeight,
                    color: CupertinoDynamicColor.resolve(
                      GlassColors.secondaryLabel,
                      context,
                    ),
                  ),
                  child: header!,
                ),
              ),
            ),
          ),
        ),
      );

  Widget _materialRow(BuildContext context, int i, Color? separator) {
    final row = children[i];
    if (i == children.length - 1) return row;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        Divider(
          height: 1,
          color: separator,
          indent: hasLeading(row)
              ? ListMetrics.materialLeadingInset
              : ListMetrics.materialInset,
        ),
      ],
    );
  }

  Widget _materialHeader(BuildContext context, PlainListScope? scope) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: scope?.background ?? theme.colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: PlainListMetrics.materialHeaderHeight,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ListMetrics.materialInset,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: Semantics(
              header: true,
              child: DefaultTextStyle.merge(
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
                child: header!,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Internal. A plain list's settings for the sections below it.
class PlainListScope extends InheritedWidget {
  /// Creates the scope.
  const PlainListScope({
    super.key,
    required this.background,
    required this.separatorColor,
    required this.sticky,
    required this.mode,
    required super.child,
  });

  /// The list's page colour, behind pinned headers.
  final Color background;

  /// The list's hairline colour; null for the style's default.
  final Color? separatorColor;

  /// Whether headers stick.
  final bool sticky;

  /// The rendering path sections below take by default.
  final GlassRenderMode? mode;

  /// The nearest scope, if any.
  static PlainListScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlainListScope>();

  @override
  bool updateShouldNotify(PlainListScope old) =>
      old.background != background ||
      old.separatorColor != separatorColor ||
      old.sticky != sticky ||
      old.mode != mode;
}
